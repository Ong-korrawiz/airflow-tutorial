#!/bin/bash

# start.sh
echo "======================================"
echo "    Starting Airflow Cluster"
echo "======================================"

if [ "$1" == "local" ]; then
    echo "Starting Local Docker Compose environment..."
    docker compose up -d
    echo ""
    echo "Airflow should be available soon at: http://localhost:8080"
elif [ "$1" == "aws" ]; then
    echo "Deploying AWS ECS Cluster via Terraform..."
    cd airflow-infra || exit 1
    terraform init
    terraform apply -auto-approve
else
    echo "Usage: ./start.sh [local|aws]"
    echo ""
    echo "  local : Start Airflow using docker compose (for local development)"
    echo "  aws   : Spin up your AWS ECS infrastructure via Terraform"
    exit 1
fi
