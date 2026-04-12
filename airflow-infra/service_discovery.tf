# --- AWS Cloud Map Service Discovery ---
# Creates a private DNS namespace so Airflow services can find each other by name,
# similar to how docker-compose provides automatic DNS resolution between services.

resource "aws_service_discovery_private_dns_namespace" "airflow" {
  name        = "airflow.local"
  description = "Private DNS namespace for Airflow service discovery"
  vpc         = module.vpc.vpc_id
}

# Register the API server so scheduler/dag-processor/triggerer can reach it
# at: api-server.airflow.local
resource "aws_service_discovery_service" "api_server" {
  name = "api-server"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.airflow.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
