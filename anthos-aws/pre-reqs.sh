#!/usr/bin/env bash

sudo apt-get install jq

curl "https://releases.hashicorp.com/terraform/1.0.10/terraform_1.0.10_linux_amd64.zip" -o "terraform.zip"
unzip terraform.zip
sudo mv terraform /usr/local/bin

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

gsutil cp gs://gke-multi-cloud-release/aws/aws-1.9.1-gke.0/bin/linux/amd64/anthos-gke .
chmod 755 anthos-gke
sudo mv anthos-gke /usr/local/bin

# By default Google Cloud Shell includes kubectl.
# If you need to install kubectl, follow directions here https://kubernetes.io/docs/tasks/tools/install-kubectl/
kubectl version --client -o yaml | grep gitVersion

