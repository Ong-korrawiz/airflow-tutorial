resource "aws_vpc_endpoint" "logs" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type = "Interface"
  
  # Must be the subnets where your ECS task is running
  subnet_ids          = module.vpc.private_subnets 
  private_dns_enabled = true

  security_group_ids = [aws_security_group.ecs_service_sg.id]
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  # This name MUST match what is in your container definition's logConfiguration
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7 # Free tier friendly: deletes old logs after a week
}