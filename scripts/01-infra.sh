#!/bin/bash
set -e
cd "$(dirname "$0")/.."
source scripts/00-env.sh
[ -z "$ACCOUNT_ID" ] && { echo "ERROR: credenciales AWS invalidas/expiradas"; exit 1; }
[ -z "$LABROLE_ARN" ] && { echo "ERROR: no se encontro LabRole"; exit 1; }

if [ -z "$VPC_ID" ]; then
  echo "--- Creando VPC ---"
  VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/20 --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" --query "Vpc.VpcId" --output text)
  aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames "{\"Value\":true}"
  aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support "{\"Value\":true}"
else
  echo "--- VPC ya existe: $VPC_ID ---"
fi

sub() {
  local NAME=$1 CIDR=$2 AZ=$3
  local ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$NAME" --query "Subnets[0].SubnetId" --output text 2>/dev/null)
  if [ "$ID" = "None" ] || [ -z "$ID" ]; then
    ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$CIDR" --availability-zone "$AZ" --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$NAME}]" --query "Subnet.SubnetId" --output text)
  fi
  echo "$ID"
}
echo "--- Subredes ---"
PUB_1A=$(sub "${PROJECT_NAME}-sub-pub-1a" 10.0.0.0/24 us-east-1a)
PUB_1B=$(sub "${PROJECT_NAME}-sub-pub-1b" 10.0.1.0/24 us-east-1b)
APP_1A=$(sub "${PROJECT_NAME}-sub-priv-app-1a" 10.0.2.0/24 us-east-1a)
APP_1B=$(sub "${PROJECT_NAME}-sub-priv-app-1b" 10.0.3.0/24 us-east-1b)
DATA_1A=$(sub "${PROJECT_NAME}-sub-priv-data-1a" 10.0.4.0/24 us-east-1a)
DATA_1B=$(sub "${PROJECT_NAME}-sub-priv-data-1b" 10.0.5.0/24 us-east-1b)
aws ec2 modify-subnet-attribute --subnet-id "$PUB_1A" --map-public-ip-on-launch >/dev/null
aws ec2 modify-subnet-attribute --subnet-id "$PUB_1B" --map-public-ip-on-launch >/dev/null
aws ec2 create-tags --resources "$PUB_1A" "$PUB_1B" --tags Key=kubernetes.io/role/elb,Value=1 >/dev/null
aws ec2 create-tags --resources "$APP_1A" "$APP_1B" --tags Key=kubernetes.io/role/internal-elb,Value=1 >/dev/null

IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null)
if [ "$IGW_ID" = "None" ] || [ -z "$IGW_ID" ]; then
  echo "--- Creando IGW ---"
  IGW_ID=$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)
  aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
fi

PUB_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PROJECT_NAME}-rt-pub" --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)
if [ "$PUB_RT" = "None" ] || [ -z "$PUB_RT" ]; then
  echo "--- Creando route table publica ---"
  PUB_RT=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-rt-pub}]" --query "RouteTable.RouteTableId" --output text)
  aws ec2 create-route --route-table-id "$PUB_RT" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
  aws ec2 associate-route-table --route-table-id "$PUB_RT" --subnet-id "$PUB_1A" >/dev/null
  aws ec2 associate-route-table --route-table-id "$PUB_RT" --subnet-id "$PUB_1B" >/dev/null
fi

NAT_ID=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null)
if [ "$NAT_ID" = "None" ] || [ -z "$NAT_ID" ]; then
  echo "--- Creando NAT Gateway ---"
  EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)
  NAT_ID=$(aws ec2 create-nat-gateway --subnet-id "$PUB_1A" --allocation-id "$EIP_ALLOC" --query "NatGateway.NatGatewayId" --output text)
  echo "esperando NAT..."
  aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_ID"
fi

PRIV_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PROJECT_NAME}-rt-priv" --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)
if [ "$PRIV_RT" = "None" ] || [ -z "$PRIV_RT" ]; then
  echo "--- Creando route table privada ---"
  PRIV_RT=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-rt-priv}]" --query "RouteTable.RouteTableId" --output text)
  aws ec2 create-route --route-table-id "$PRIV_RT" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_ID" >/dev/null
  for S in "$APP_1A" "$APP_1B" "$DATA_1A" "$DATA_1B"; do aws ec2 associate-route-table --route-table-id "$PRIV_RT" --subnet-id "$S" >/dev/null; done
fi

sg() {
  local NAME=$1 DESC=$2
  local ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
  if [ "$ID" = "None" ] || [ -z "$ID" ]; then
    ID=$(aws ec2 create-security-group --group-name "$NAME" --description "$DESC" --vpc-id "$VPC_ID" --query "GroupId" --output text)
  fi
  echo "$ID"
}
echo "--- Security Groups ---"
SG_ALB=$(sg "SG-ALB" "ALB publico")
SG_RDS=$(sg "SG-RDS" "RDS MySQL")
aws ec2 authorize-security-group-ingress --group-id "$SG_ALB" --protocol tcp --port 80 --cidr 0.0.0.0/0 2>/dev/null || true

RDS_STATUS=$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null)
if [ -z "$RDS_STATUS" ] || [ "$RDS_STATUS" = "None" ]; then
  echo "--- Creando RDS Multi-AZ (toma ~10 min) ---"
  aws rds create-db-subnet-group --db-subnet-group-name "${PROJECT_NAME}-db-subnet-group" --db-subnet-group-description "EscolarOnline" --subnet-ids "$DATA_1A" "$DATA_1B" >/dev/null 2>&1 || true
  aws rds create-db-instance --db-instance-identifier "$RDS_ID" --db-instance-class db.t4g.micro --engine mysql --engine-version 8.0 \
    --master-username "$DB_USER" --master-user-password "$DB_PASS" --allocated-storage 20 --db-name "$DB_NAME" --multi-az --no-publicly-accessible \
    --vpc-security-group-ids "$SG_RDS" --db-subnet-group-name "${PROJECT_NAME}-db-subnet-group" --storage-encrypted >/dev/null
  echo "esperando RDS..."
  aws rds wait db-instance-available --db-instance-identifier "$RDS_ID"
else
  echo "--- RDS ya existe ($RDS_STATUS) ---"
fi

EKS_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.status" --output text 2>/dev/null)
if [ -z "$EKS_STATUS" ] || [ "$EKS_STATUS" = "None" ]; then
  echo "--- Creando cluster EKS (15-20 min) ---"
  eksctl create cluster --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION" --version 1.29 --without-nodegroup \
    --vpc-private-subnets "$APP_1A,$APP_1B" --vpc-public-subnets "$PUB_1A,$PUB_1B"
else
  echo "--- Cluster EKS ya existe ($EKS_STATUS) ---"
fi

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION" >/dev/null
kubectl config use-context "arn:aws:eks:${AWS_DEFAULT_REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}" >/dev/null

NG_STATUS=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODEGROUP_NAME" --query "nodegroup.status" --output text 2>/dev/null)
if [ -z "$NG_STATUS" ] || [ "$NG_STATUS" = "None" ]; then
  echo "--- Creando node group (5-10 min) ---"
  CLUSTER_SG=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)
  cat > /tmp/nodegroup.yaml <<NGEOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: $CLUSTER_NAME
  region: $AWS_DEFAULT_REGION
vpc:
  id: $VPC_ID
  securityGroup: $CLUSTER_SG
  subnets:
    private:
      us-east-1a: { id: $APP_1A }
      us-east-1b: { id: $APP_1B }
managedNodeGroups:
  - name: $NODEGROUP_NAME
    instanceType: t4g.small
    desiredCapacity: 2
    minSize: 2
    maxSize: 4
    privateNetworking: true
    iam:
      instanceRoleARN: $LABROLE_ARN
NGEOF
  eksctl create nodegroup --config-file=/tmp/nodegroup.yaml
else
  echo "--- Node group ya existe ($NG_STATUS) ---"
fi
echo "=== Infra lista. Corre ./scripts/heal.sh y luego ./scripts/02-app.sh ==="
