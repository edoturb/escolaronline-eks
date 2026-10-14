#!/bin/bash
set -e
cd "$(dirname "$0")/.."
source scripts/00-env.sh
echo "Va a borrar: cluster EKS, RDS, NAT Gateway, y (con --full) la VPC completa y los repos ECR."
read -p "Escribe 'borrar' para confirmar: " C
[ "$C" != "borrar" ] && { echo "Cancelado."; exit 0; }
kubectl delete -f k8s/ --ignore-not-found 2>/dev/null || true
eksctl delete cluster --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION" || true
aws rds delete-db-instance --db-instance-identifier "$RDS_ID" --skip-final-snapshot 2>/dev/null || true
NAT_ID=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null)
[ -n "$NAT_ID" ] && [ "$NAT_ID" != "None" ] && aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID"
if [ "$1" = "--full" ]; then
  for REPO in "${PROJECT_NAME}-frontend" "${PROJECT_NAME}-get-products" "${PROJECT_NAME}-create-product" "${PROJECT_NAME}-update-product" "${PROJECT_NAME}-delete-product"; do
    aws ecr delete-repository --repository-name "$REPO" --force 2>/dev/null || true
  done
  sleep 90
  for ALLOC in $(aws ec2 describe-addresses --query "Addresses[?AssociationId==null].AllocationId" --output text); do aws ec2 release-address --allocation-id "$ALLOC" 2>/dev/null || true; done
  IGW=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text)
  [ "$IGW" != "None" ] && aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC_ID" && aws ec2 delete-internet-gateway --internet-gateway-id "$IGW"
  for SUB in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text); do aws ec2 delete-subnet --subnet-id "$SUB"; done
  for RT in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text); do aws ec2 delete-route-table --route-table-id "$RT"; done
  for SG in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=SG-ALB,SG-RDS" --query "SecurityGroups[].GroupId" --output text); do aws ec2 delete-security-group --group-id "$SG" 2>/dev/null || true; done
  aws ec2 delete-vpc --vpc-id "$VPC_ID"
fi
echo "=== Teardown completo ==="
