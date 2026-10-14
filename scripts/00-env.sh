#!/bin/bash
set -a
AWS_DEFAULT_REGION="us-east-1"
PROJECT_NAME="escolaronline"
VPC_NAME="${PROJECT_NAME}-vpc"
CLUSTER_NAME="${PROJECT_NAME}-cluster"
NODEGROUP_NAME="${PROJECT_NAME}-nodes"
RDS_ID="${PROJECT_NAME}-db"
DB_NAME="escolar_online"
DB_USER="alumno"
DB_PASS="alumno123"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${VPC_NAME}" --query "Vpcs[0].VpcId" --output text 2>/dev/null)
[ "$VPC_ID" = "None" ] && VPC_ID=""
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query "DBInstances[0].Endpoint.Address" --output text 2>/dev/null)
[ "$RDS_ENDPOINT" = "None" ] && RDS_ENDPOINT=""
LABROLE_ARN=$(aws iam get-role --role-name LabRole --query Role.Arn --output text 2>/dev/null)
set +a
echo "ACCOUNT_ID=$ACCOUNT_ID | VPC_ID=${VPC_ID:-none} | RDS_ENDPOINT=${RDS_ENDPOINT:-none}"
