migrate:
	aws ecs run-task \
		--cluster airflow-3-dev-cluster \
		--task-definition arn:aws:ecs:us-east-1:880197157210:task-definition/airflow-task:3 \
		--launch-type FARGATE \
		--region us-east-1 \
		--network-configuration "awsvpcConfiguration={subnets=[subnet-08160589ae8679851],securityGroups=[sg-00cf3ad65579d63ff],assignPublicIp=DISABLED}" \
		--overrides '{ \
			"containerOverrides": [ \
				{ \
					"name": "airflow", \
					"command": ["bash", "-c", "airflow db migrate && airflow users create --username admin --password admin --role Admin --email admin@example.com --firstname Admin --lastname User"], \
					"environment": [ \
						{"name": "_AIRFLOW_DB_MIGRATE", "value": "true"}, \
						{"name": "_AIRFLOW_WWW_USER_CREATE", "value": "true"} \
					] \
				} \
			] \
		}'

push_to_ecr:
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 880197157210.dkr.ecr.us-east-1.amazonaws.com
	docker build -t airflow-tutorial .
	docker tag airflow-tutorial:latest 880197157210.dkr.ecr.us-east-1.amazonaws.com/airflow-tutorial:latest
	docker push 880197157210.dkr.ecr.us-east-1.amazonaws.com/airflow-tutorial:latest

# --- Cluster Management ---

start-local:
	./start.sh local

start-aws:
	./start.sh aws

stop-local:
	./stop.sh local

stop-aws:
	./stop.sh aws

redeploy-aws:
	@echo "Forcing new deployment on all Airflow ECS services..."
	aws ecs update-service --cluster airflow-3-dev-cluster --service airflow-apiserver --force-new-deployment --region us-east-1
	aws ecs update-service --cluster airflow-3-dev-cluster --service airflow-scheduler --force-new-deployment --region us-east-1
	aws ecs update-service --cluster airflow-3-dev-cluster --service airflow-dag-processor --force-new-deployment --region us-east-1
	aws ecs update-service --cluster airflow-3-dev-cluster --service airflow-triggerer --force-new-deployment --region us-east-1
	@echo "Deployment triggered! New tasks will spin up with the latest image."