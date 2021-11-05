#!/usr/bin/env bash

# Docs: https://cloud.google.com/anthos/gke/docs/aws/how-to/prerequisites

# Setup Google Project
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_USER=$(gcloud config get-value core/account) # set current user

# Set up AWS
export AWS_REGION=us-east-2
export AWS_USER_ARN=$(aws sts get-caller-identity | jq -r '.Arn')
export VPC_CIDR_BLOCK=10.0.0.0/16
export ZONE_1=us-east-2a
export ZONE_2=us-east-2b
export ZONE_3=us-east-2c
export PRIVATE_CIDR_BLOCK_1=10.0.1.0/24
export PRIVATE_CIDR_BLOCK_2=10.0.2.0/24
export PRIVATE_CIDR_BLOCK_3=10.0.3.0/24
export PUBLIC_CIDR_BLOCK_1=10.0.100.0/24
export PUBLIC_CIDR_BLOCK_2=10.0.101.0/24
export PUBLIC_CIDR_BLOCK_3=10.0.102.0/24
export SSH_CIDR_BLOCK=0.0.0.0/0

# Enable APIs
gcloud services enable anthos.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable gkehub.googleapis.com
gcloud services enable gkeconnect.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable stackdriver.googleapis.com
gcloud services enable storage-api.googleapis.com
gcloud services enable storage-component.googleapis.com
gcloud services enable securetoken.googleapis.com
gcloud services enable sts.googleapis.com

# Create service accounts for Anthos/GKE control plane components 
gcloud iam service-accounts create management-sa
gcloud iam service-accounts create hub-sa
gcloud iam service-accounts create node-sa 

gcloud iam service-accounts keys create management-key.json \
     --iam-account management-sa@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts keys create hub-key.json \
     --iam-account hub-sa@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts keys create node-key.json \
     --iam-account node-sa@$PROJECT_ID.iam.gserviceaccount.com

export MANAGEMENT_KEY_PATH=$(readlink -f management-key.json)
export HUB_KEY_PATH=$(readlink -f hub-key.json)
export NODE_KEY_PATH=$(readlink -f node-key.json)

# if not project owner
#gcloud auth activate-service-account --key-file=node-key.json 

gcloud projects add-iam-policy-binding \
    $PROJECT_ID \
    --member serviceAccount:management-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/gkehub.admin
gcloud projects add-iam-policy-binding \
    $PROJECT_ID \
    --member serviceAccount:management-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/serviceusage.serviceUsageViewer

gcloud projects add-iam-policy-binding \
    $PROJECT_ID \
    --member serviceAccount:hub-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/gkehub.connect

gcloud projects add-iam-policy-binding \
      $PROJECT_ID \
      --member serviceAccount:node-sa@$PROJECT_ID.iam.gserviceaccount.com \
      --role roles/storage.objectViewer

# Setup AWS account

# create two KMS keys
aws kms create-key > aws-kms-key1-meta.json
aws kms create-key > aws-kms-key2-meta.json

# fetch ARN from each key
export KMS_KEY_ARN=$(cat aws-kms-key1-meta.json | jq -r '.[].Arn')
export DATABASE_KMS_KEY_ARN=$(cat aws-kms-key2-meta.json | jq -r '.[].Arn')

# create aliases for keys
aws kms create-alias --alias-name=alias/anthos-key --target-key-id=$KMS_KEY_ARN
aws kms create-alias --alias-name=alias/anthos-db-key --target-key-id=$DATABASE_KMS_KEY_ARN

cat <<EOF > anthos-gke.yaml
 apiVersion: multicloud.cluster.gke.io/v1
 kind: AWSManagementService
 metadata:
   name: management
 spec:
   version: aws-1.9.1-gke.0
   region: $AWS_REGION
   authentication:
     awsIAM:
       adminIdentityARNs:
       - $AWS_USER_ARN
   kmsKeyARN: $KMS_KEY_ARN
   databaseEncryption:
     kmsKeyARN: $DATABASE_KMS_KEY_ARN
   googleCloud:
     projectID: $PROJECT_ID
     serviceAccountKeys:
       managementService: $MANAGEMENT_KEY_PATH
       connectAgent: $HUB_KEY_PATH
       node: $NODE_KEY_PATH
   dedicatedVPC:
     vpcCIDRBlock: $VPC_CIDR_BLOCK
     availabilityZones:
     - $ZONE_1
     - $ZONE_2
     - $ZONE_3
     privateSubnetCIDRBlocks:
     - $PRIVATE_CIDR_BLOCK_1
     - $PRIVATE_CIDR_BLOCK_2
     - $PRIVATE_CIDR_BLOCK_3
     publicSubnetCIDRBlocks:
     - $PUBLIC_CIDR_BLOCK_1
     - $PUBLIC_CIDR_BLOCK_2
     - $PUBLIC_CIDR_BLOCK_3
   # Optional
   bastionHost:
     allowedSSHCIDRBlocks:
     - $SSH_CIDR_BLOCK
EOF
