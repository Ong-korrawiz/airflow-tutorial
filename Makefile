migrate:
	aws ecs run-task \
		--cluster airflow-3-dev-cluster \
		--task-definition arn:aws:ecs:us-east-1:880197157210:task-definition/airflow-task:3 \
		--launch-type FARGATE \
		--region us-east-1\
		--network-configuration "awsvpcConfiguration={subnets=[subnet-08160589ae8679851],securityGroups=[sg-00cf3ad65579d63ff],assignPublicIp=DISABLED}" \
		--overrides '{
			"containerOverrides": [
			{
				"name": "airflow",
				"command": ["bash", "-c", "airflow db migrate && airflow users create --username admin --password admin --role Admin --email admin@example.com --firstname Admin --lastname User"],
				"environment": [
				{"name": "_AIRFLOW_DB_MIGRATE", "value": "true"},
				{"name": "_AIRFLOW_WWW_USER_CREATE", "value": "true"}
				]
			}
			]
		}'