# Airflow 3.0 Manual Actions

### 1. Networking Validation (Step 1)
- Run `terraform apply` for the VPC and RDS first.
- **Validation:** Check the RDS console. Ensure the Status is "Available".

### 2. Image Preparation (Step 2)
- Build your local Airflow 3 image.
- Tag and push to ECR:
  `docker tag airflow-image:3.0.0 <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/airflow-3-dev:latest`
  `docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/airflow-3-dev:latest`

### 3. Database Initialization (Step 3)
- Run a one-time ECS Task with the command override: `airflow db migrate`.
- **Validation:** View CloudWatch logs to ensure the migration finished without errors.

### 4. Admin Account (Step 4)
- Run a one-time ECS Task with:
  `airflow users create --username admin --password admin --role Admin --email admin@example.com --firstname Admin --lastname User`

### 5. Accessing the UI
- Get the DNS Name from the Load Balancer in the EC2 Console.
- **Validation:** Paste the URL into your browser. You should see the Airflow Login page.