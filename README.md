# Airflow Tutorial: Daily ETL & Forecasting Pipeline

A production-grade Apache Airflow 3.0 orchestration platform deployed on AWS ECS Fargate, featuring an automated daily ETL pipeline that aggregates sales data and generates time-series forecasts using Prophet.

## 🎯 Project Overview

This project demonstrates enterprise-level data pipeline orchestration with:
- **Distributed Airflow infrastructure** on AWS ECS (API Server, Scheduler, DAG Processor, Triggerer)
- **Automated ETL workflow** that ingests sales data, validates quality, and persists to PostgreSQL
- **Time-series forecasting** using Facebook's Prophet model with 99.9% data aggregation optimization
- **Infrastructure-as-code** via Terraform for reproducible AWS deployments
- **Production-ready** with CloudWatch logging, S3 remote logging, and High Availability design

## 🏗️ Architecture

### Pipeline Flow

The `daily_etl_pipeline` DAG orchestrates the following workflow:

```
start_pipeline
    ↓
check_last_date (branching)
    ↓
├─→ upload_csv_to_postgres (load 913k rows from train.csv)
│       ↓
├─→ download_table_from_postgres (fetch records from RDS)
    ↓
validate_demand_dataframe (schema validation)
    ↓
train_prophet_model (aggregate to ~1k daily totals, train model)
    ↓
forecast (generate predictions)
    ↓
upload_forecasting_to_postgres (persist results)
    ↓
join_paths
```

### Infrastructure Architecture

```
AWS VPC (10.0.0.0/16)
├── Public Subnets (ALB, NAT Gateway)
├── Private Subnets
│   ├── ECS Fargate cluster (4 services)
│   │   ├── airflow-apiserver (2 vCPU, 8 GB RAM)
│   │   ├── airflow-scheduler (2 vCPU, 8 GB RAM)
│   │   ├── airflow-dag-processor (1 vCPU, 2 GB RAM)
│   │   └── airflow-triggerer (1 vCPU, 2 GB RAM)
│   ├── RDS PostgreSQL (airflow_data + airflow metadata DB)
│   ├── S3 (model artifacts, remote logging)
│   └── CloudWatch Logs (/ecs/airflow-3-dev)
└── Application Load Balancer (port 80 → ECS port 8080)
```

## 🚀 Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **Orchestration** | Apache Airflow 3.0.0 | Workflow orchestration & scheduling |
| **Compute** | AWS ECS Fargate | Containerized workload execution |
| **Database** | PostgreSQL 15+ | Metadata DB (airflow_db) & data repository (airflow_data) |
| **Storage** | AWS S3 | Model artifacts & remote logging |
| **IaC** | Terraform 5.0+ | Infrastructure provisioning |
| **ML Framework** | Prophet 1.2.1 | Time-series forecasting |
| **Language** | Python 3.13+ | DAG definition & task logic |
| **Containerization** | Docker | Airflow image with dependencies |
| **CI/CD** | GitHub Actions | Build & deployment automation |

### Key Dependencies

```
apache-airflow-providers-amazon      # AWS integration
boto3                                # AWS SDK
prophet                              # Time-series forecasting
pandas                               # Data manipulation
sqlalchemy                           # ORM for database operations
psycopg2                             # PostgreSQL adapter
pydantic                             # Data validation
```

## 📋 Prerequisites

- **AWS Account** with appropriate IAM permissions (ECS, RDS, S3, ECR)
- **Docker & Docker Compose** (for local development)
- **Terraform 5.0+** (for infrastructure deployment)
- **Python 3.13+** with `pip` or `uv` package manager
- **GitHub Personal Access Token** (for Terraform GitHub provider)
- **AWS CLI v2** configured with credentials

## 🏃 Getting Started

### Option 1: Local Development (Docker Compose)

1. **Clone repository**
   ```bash
   git clone <repo-url>
   cd airflow-tutorial
   ```

2. **Set up environment**
   ```bash
   cp .env.example .env  # Configure your credentials
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Start local Airflow stack**
   ```bash
   make start-local
   ```
   
   This starts:
   - Airflow UI: http://localhost:8080
   - PostgreSQL: localhost:5432
   - Redis: localhost:6379

4. **Login to Airflow**
   ```
   Username: airflow
   Password: airflow
   ```

### Option 2: Deploy to AWS

1. **Configure Terraform variables**
   ```bash
   cd airflow-infra
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your AWS details
   ```

2. **Deploy infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Access Airflow UI**
   ```bash
   # Get the ALB URL from Terraform outputs
   terraform output airflow_url
   ```
   
   Login with credentials from `terraform.tfvars`:
   ```
   Username: <airflow_admin_username>
   Password: <airflow_admin_password>
   ```

## 📁 Project Structure

```
airflow-tutorial/
├── dags/                          # DAG definitions
│   └── our_first_dag.py          # Daily ETL pipeline (daily_etl_pipeline)
├── src/                           # Task implementations
│   ├── settings.py                # Configuration & environment variables
│   ├── data/
│   │   ├── uploader.py           # PostgreSQL write operations
│   │   └── downloader.py         # PostgreSQL read operations
│   ├── model/
│   │   ├── __init__.py           # Prophet training & forecasting
│   │   └── (forecast logic)
│   ├── s3/
│   │   ├── uploader.py           # S3 model artifact persistence
│   │   └── downloader.py         # S3 model retrieval
│   └── configs/                   # Configuration classes
├── airflow-infra/                 # Terraform infrastructure code
│   ├── provider.tf                # AWS & GitHub providers
│   ├── vpc.tf                     # VPC, subnets, route tables
│   ├── ecs.tf                     # ECS cluster, task definitions, services
│   ├── rds.tf                     # PostgreSQL RDS instance
│   ├── s3.tf                      # S3 buckets
│   ├── iam.tf                     # IAM roles & policies
│   ├── service_discovery.tf       # CloudMap service discovery
│   ├── github.tf                  # GitHub Actions secrets
│   ├── variables.tf               # Input variables
│   ├── terraform.tfvars           # Variable values (sensitive — not in git)
│   └── output.tf                  # Terraform outputs
├── docker-compose.yaml            # Local development stack
├── Dockerfile                     # Airflow image definition
├── requirements.txt               # Python dependencies
├── .env                           # Environment variables (not in git)
├── .gitignore                     # Git exclusions
└── README.md                      # This file
```

## ⚙️ Configuration

### Environment Variables

Create `.env` file with the following (required for local development):

```bash
# Local Airflow
AIRFLOW_UID=1000
DB_URL=postgresql://airflow_db_user:password@localhost:5432/airflow_data
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow_db_user:password@localhost:5432/airflow
AIRFLOW__CORE__SQL_ALCHEMY_SCHEMA=airflow
AIRFLOW__API_AUTH__JWT_SECRET=your-secret-key

# AWS Credentials
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1

# S3 Configuration
S3_ACCESS_KEY_ID=AKIA...
S3_SECRET_ACCESS_KEY=...
S3_BUCKET_NAME=ong-forecasting-pipeline
S3_BUCKET_REGION=us-west-2

# GitHub Token (for Terraform)
GITHUB_TOKEN=ghp_...
```

### Terraform Variables (terraform.tfvars)

```hcl
# AWS Configuration
aws_region              = "us-east-1"
github_token           = "ghp_..."
github_username        = "your-github-username"
repo_name              = "airflow-tutorial"

# Airflow Configuration
airflow_image                        = "<account-id>.dkr.ecr.us-east-1.amazonaws.com/airflow-tutorial"
airflow_admin_username              = "admin"
airflow_admin_password              = "secure-password"
airflow_database_sql_alchemy_conn   = "postgresql+psycopg2://..."
airflow_role                        = "Admin"
airflow_user_email                  = "admin@example.com"

# Database Configuration
private_db_username  = "airflow_db_user"
private_db_password  = "secure-password"
private_db_dbname    = "airflow_data"

# Security Keys
fernet_key  = "<base64-encoded-fernet-key>"
jwt_secret  = "secure-jwt-secret"

# S3 Credentials
s3_access_key_id      = "AKIA..."
s3_secret_access_key  = "..."
s3_bucket_name        = "ong-forecasting-pipeline"
s3_bucket_region      = "us-west-2"
```

## 🔄 Development Workflow

### 1. Creating New DAGs

Place DAG files in `dags/` directory. Airflow auto-discovers them:

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from src.data import uploader

with DAG(dag_id="my_dag", ...):
    task1 = PythonOperator(python_callable=uploader.my_function)
```

### 2. Creating Tasks

Implement task logic in `src/` modules:

```python
# src/data/my_tasks.py
from airflow.decorators import task

@task
def my_task(input_data):
    # Process data
    return result
```

### 3. Database Operations

Use the provided utilities:

```python
from src.data import uploader, downloader

# Upload DataFrame to PostgreSQL
uploader.upload_csv_to_postgres(df)

# Download table from PostgreSQL
df = downloader.download_table_from_postgres()
```

### 4. S3 Operations

```python
from src.s3 import uploader, downloader

# Upload model to S3
uploader.upload_json(data_dict, "path/to/model.json")

# Download from S3
model = downloader.download_json("path/to/model.json")
```

### 5. Git Workflow

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes, test locally
git add .
git commit -m "feat: description of changes"

# Push and create PR
git push origin feature/my-feature
```

## ✅ Testing

### Unit Tests

```bash
# Run all tests
pytest test/

# Run with coverage
pytest --cov=src test/

# Run specific test
pytest test/test_model.py::test_prophet_training
```

### Integration Tests

```bash
# Test database operations (requires running PostgreSQL)
pytest test/integration/ -v

# Test S3 operations (requires AWS credentials)
pytest test/integration/test_s3.py
```

### Manual Testing in Airflow UI

1. Navigate to http://localhost:8080 (local) or ALB URL (AWS)
2. Toggle `daily_etl_pipeline` to "On"
3. Click the Play button to trigger manually
4. Monitor task execution in real-time
5. View logs via "Log" button on each task

## 🚢 Deployment

### Build & Push Docker Image to ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build & push
make push_to_ecr
```

### Terraform Deployment

```bash
cd airflow-infra

# Initialize (first time only)
terraform init

# Plan changes
terraform plan -var-file="terraform.tfvars"

# Apply changes
terraform apply -var-file="terraform.tfvars"

# View outputs
terraform output
```

### ECS Task Updates

To update ECS tasks with new image:

```bash
# Update task definition (auto-increment revision)
aws ecs register-task-definition --cli-input-json file://task-def.json

# Update service to use new task definition
aws ecs update-service --cluster airflow-3-dev-cluster --service airflow-apiserver --force-new-deployment
```

## 📊 Monitoring & Logging

### CloudWatch Logs

View ECS logs in CloudWatch:

```bash
# List log streams
aws logs describe-log-streams --log-group-name /ecs/airflow-3-dev

# View logs from last hour
aws logs tail /ecs/airflow-3-dev --since 1h
```

### Airflow Health Checks

Health check endpoint:

```bash
curl http://<ALB-DNS>/api/v2/monitor/health
```

Expected response:
```json
{
  "metadatabase": {"status": "ok"},
  "scheduler": {"status": "ok"},
  "triggerer": {"status": "ok"}
}
```

### S3 Remote Logging

Logs are stored in S3:

```
s3://airflow-3-dev-airflow-logs-bucket/airflow-logs/
```

## 🔑 Key Features

### Data Pipeline Optimization

- **99.9% Data Aggregation**: Reduces 913,001 sales records to ~1,000 daily aggregates
- **Automatic Retry Logic**: Failed tasks retry up to 1 time with 1-minute delays
- **Branching Logic**: `check_last_date` determines whether to upload new data

### Time-Series Forecasting

- **Prophet Model**: Facebook's robust time-series library
- **Memory Optimization**: GC cleanup after training to prevent OOM
- **Increased Timeout**: 900-second timeout for compute-intensive training
- **S3 Persistence**: Models stored in `s3://ong-forecasting-pipeline/`

### Infrastructure & Security

- **Multi-AZ Deployment**: Services span 2 availability zones
- **Network Isolation**: ECS tasks in private subnets, ALB in public subnet
- **VPC Security Groups**: Strict ingress/egress rules
- **IAM Roles**: Least-privilege task execution role
- **Sensitive Secrets**: Stored in `.tfvars` (excluded from git), not hardcoded

## 📝 Coding Standards

### Python

- **PEP 8 compliance**: Style guide enforcement
- **Type hints**: All function signatures include type annotations
- **Docstrings**: Google-style docstrings for modules and functions
- **Error handling**: Explicit exception handling with logging

Example:

```python
def upload_csv_to_postgres(
    df: pd.DataFrame,
    table_name: str = "sales_data"
) -> int:
    """
    Upload DataFrame to PostgreSQL table.
    
    Args:
        df: Input DataFrame to upload
        table_name: Target table name
        
    Returns:
        Number of rows inserted
        
    Raises:
        ValueError: If DataFrame is empty
    """
    if df.empty:
        raise ValueError("DataFrame is empty")
    # Implementation
```

### Terraform

- **Modular structure**: Separate files by concern (vpc.tf, ecs.tf, rds.tf, etc.)
- **Explicit naming**: Clear resource names prefixed with `var.project_name`
- **Sensitive variables**: Marked with `sensitive = true`
- **Comments**: Complex logic annotated with explanations

### DAGs

- **Descriptive task IDs**: Clear, kebab-case names (e.g., `check_last_date`)
- **Documentation**: DAG descriptions and owner information
- **Error handling**: Retries and trigger rules configured
- **Dependency clarity**: Explicit task dependencies (>> operator)

## 🤝 Contributing

1. **Create feature branch**: `git checkout -b feature/your-feature`
2. **Make changes** following coding standards above
3. **Test locally**: Run utilities and unit tests
4. **Commit with clear messages**: 
   ```
   feat: add new forecast model
   fix: correct S3 credential handling
   refactor: optimize data aggregation
   ```
5. **Push and open PR**: Include description and test results
6. **Code review**: Address feedback from peers
7. **Merge**: Maintainer merges to `main`

## 📚 Documentation

- [Airflow 3.0 Docs](https://airflow.apache.org/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Prophet Forecasting Docs](https://facebook.github.io/prophet/)
- [AWS ECS Docs](https://docs.aws.amazon.com/ecs/)

## 🐛 Troubleshooting

### Database Connection Errors

**Error**: "could not translate host name 'postgres_dw'"

**Solution**: Verify `terraform.tfvars` has correct RDS endpoint:
```hcl
airflow_database_sql_alchemy_conn = "postgresql+psycopg2://user:pass@airflow-3-dev-private-db.<region>.rds.amazonaws.com:5432/airflow"
```

### Prophet Model OOM Kill

**Error**: SIGKILL (-9) during `train_prophet_model`

**Solution**:
1. Increase ECS memory: `fargate_memory = "8192"` in variables.tf
2. Data is auto-aggregated to ~1k rows in [src/model/__init__.py](src/model/__init__.py)
3. Ensure GC cleanup is enabled (check for `gc.collect()` calls)

### S3 Upload Fails: InvalidAccessKeyId

**Error**: "InvalidAccessKeyId: minioadmin"

**Solution**: Verify S3 credentials in `.env` or `terraform.tfvars`:
```bash
export S3_ACCESS_KEY_ID="AKIA..."
export S3_SECRET_ACCESS_KEY="..."
export S3_BUCKET_REGION="us-west-2"
```

### Task Cannot Pull Image from ECR

**Error**: CannotPullContainerImage in ECS

**Solution**:
1. Verify image is pushed: `aws ecr describe-images --repository-name airflow-tutorial`
2. Check task execution IAM role has ECR permissions
3. Ensure ECS security group allows HTTPS (port 443)

## 📄 License

[Add your license here - MIT, Apache 2.0, etc.]

---

**Questions?** Open an issue or contact the maintainers.

**Last Updated**: April 13, 2026