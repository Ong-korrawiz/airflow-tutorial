#!/bin/bash

# stop.sh
echo "======================================"
echo "    Stopping Airflow Cluster"
echo "======================================"

if [ "$1" == "local" ]; then
    echo "Stopping Local Docker Compose environment..."
    docker compose down
elif [ "$1" == "aws" ]; then
    echo "Destroying AWS ECS Cluster via Terraform..."
    cd airflow-infra || exit 1
    
    echo "WARNING: This will destroy all deployed AWS resources."
    read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        terraform destroy
    else
        echo "Aborted."
    fi
else
    echo "Usage: ./stop.sh [local|aws]"
    echo ""
    echo "  local : Stop and remove the local docker compose environment"
    echo "  aws   : Tear down your AWS ECS infrastructure via Terraform"
    exit 1
fi
