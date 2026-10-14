#!/bin/bash
set -e
cd "$(dirname "$0")/.."
source scripts/00-env.sh
echo "VPC: ${VPC_ID:-none} | RDS: $(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo none) | EKS: $(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.status' --output text 2>/dev/null || echo none)"
if [ -n "$VPC_ID" ]; then
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION" >/dev/null
  kubectl config use-context "arn:aws:eks:${AWS_DEFAULT_REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}" >/dev/null
  echo "--- Nodos ---"; kubectl get nodes 2>/dev/null
  echo "--- Pods ---"; kubectl get pods -n "$PROJECT_NAME" 2>/dev/null
  echo "--- Ingress ---"; kubectl get ingress -n "$PROJECT_NAME" 2>/dev/null
  echo "--- HPA ---"; kubectl get hpa -n "$PROJECT_NAME" 2>/dev/null
fi
