#!/usr/bin/env bash

# Docs: https://cloud.google.com/anthos/gke/docs/aws/how-to/prerequisites

sudo apt-get install jq

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_USER=$(gcloud config get-value core/account) # set current user

# confirm aws CLI working
aws --version

# create two KMS keys
aws kms create-key > aws-kms-key-meta.json
aws kms create-key > aws-kms-key2-meta.json

# fetch ARN from each key
export KMS_ARN1=$(cat aws-kms-key-meta.json | jq '.[].Arn')
export KMS_ARN2=$(cat aws-kms-key2-meta.json | jq '.[].Arn')
echo "Key 1 Arn: ${KMS_ARN1}"
echo "Key 2 Arn: ${KMS_ARN2}"

# create aliases for keys
aws kms create-alias \                                                                  
    --alias-name=alias/gke-key \
    --target-key-id=$KMS_ARN1
aws kms create-alias \                                                                  
    --alias-name=alias/gke-key2 \
    --target-key-id=$KMS_ARN2

# enable gcloud apis
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable gkehub.googleapis.com
gcloud services enable gkeconnect.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable stackdriver.googleapis.com
gcloud services enable storage-api.googleapis.com
gcloud services enable storage-component.googleapis.com

# create service accounts
gcloud iam service-accounts create management-sa
gcloud iam service-accounts create hub-sa
gcloud iam service-accounts create node-sa

# download keys
gcloud iam service-accounts keys create management-key.json \
     --iam-account management-sa@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts keys create hub-key.json \
     --iam-account hub-sa@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts keys create node-key.json \
     --iam-account node-sa@$PROJECT_ID.iam.gserviceaccount.com

# management sa
gcloud projects add-iam-policy-binding \
    $PROJECT_ID \
    --member serviceAccount:management-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/gkehub.admin
gcloud projects add-iam-policy-binding \
    $PROJECT_ID \
    --member serviceAccount:management-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/serviceusage.serviceUsageViewer

# hub sa
gcloud projects add-iam-policy-binding \
    $PROJECT_ID \
    --member serviceAccount:hub-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/gkehub.connect

# node sa
gcloud projects add-iam-policy-binding \
    $PROJECT_ID \
    --member serviceAccount:node-sa@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/storageAdmin # objectViewer didn't work for mgmt install (need create TF state bucket)

#####################################################################################
# download anthos-gke CLI 
# NOTE: your service account MUST BE ADDED (MANUALLY BY GOOGLE) TO APPROVE LIST FIRST
#####################################################################################

# gcloud auth activate-service-account --key-file=node-key.json # if not project owner

# mac
gsutil cp gs://gke-multi-cloud-release/aws/aws-1.4.2-gke.1/bin/darwin/amd64/anthos-gke .

# linux
# gsutil cp gs://gke-multi-cloud-release/aws/aws-1.4.2-gke.1/bin/linux/amd64/anthos-gke .

chmod 755 anthos-gke
sudo mv anthos-gke /usr/local/bin

# gcloud config set account $PROJECT_USER # reset auth permission

# test the CLI is working
anthos-gke version