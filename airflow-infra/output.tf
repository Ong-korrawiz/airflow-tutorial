output "private_subnets" {
  description = "List of private subnet IDs for ECS tasks"
  value       = module.vpc.private_subnets
}

output "ecs_task_security_group_id" {
  description = "Security Group ID for the Airflow ECS tasks"
  value       = aws_security_group.ecs_service_sg.id
}

output "db_instance_endpoint" {
  value = aws_db_instance.airflow_db.endpoint
}