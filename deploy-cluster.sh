#!/bin/bash

set -e

wait_for_keypress() {
  local timeout="${1:-3}"
  local prompt="${2:-}"

  if [[ -z "$prompt" ]]; then
    if (( timeout > 0 )); then
      prompt="Press any key to continue or wait ${timeout}s..."
    else
      prompt="Press any key to continue..."
    fi
  fi

  echo -n "$prompt"
  if (( timeout > 0 )); then
    read -n 1 -s -r -t "$timeout" || true
    echo
  else
    read -n 1 -s -r
    echo
  fi
  echo
}

################################### Step 1 ###################################
echo "### Step 1: Initialize the Base Infrastructure"
echo "1. Update the ./terraform.tf to name the S3 bucket and key for your Terraform state"
echo "2. Update the ./variables.tf to use your desired resource_prefix, and AWS account_id and region"
wait_for_keypress

echo "3. Run terraform init in the repo root directory"
terraform init
wait_for_keypress

echo "4. Run terraform plan && terraform apply in the repo root and accept the proposed changes if they make sense to you"
terraform plan
wait_for_keypress
terraform apply
wait_for_keypress

echo "5. Open the AWS web console and verify your EKS cluster is up and looking good"
wait_for_keypress

echo "6. Configure your kubectl command-line tool to use the new EKS cluster and keeping the credentials in ./.kubeconfig:"
export KUBECONFIG="$(pwd)/.kubeconfig"
export AWS_PROFILE=terraform-mvp
export AWS_REGION=us-east-1
export CLUSTER_NAME=mvp-dev-cluster
aws --profile=$AWS_PROFILE eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
wait_for_keypress

echo "7. Verify your local configuration with kubectl cluster-info"
kubectl cluster-info
wait_for_keypress

echo "8. Install the [Metrics Server](https://github.com/kubernetes-sigs/metrics-server):"
kubectl apply -f k8s-infra/metrics-server.yaml
wait_for_keypress

################################### Step 2 ###################################
echo "### Step 2: Configure the AWS Elastic Block Storage for EKS"
echo "Configure persistent storage using EBS for EKS by following"
echo "the [Amazon EBS CSI Driver User Guide](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html), summarized below."
echo "Modify the ./k8s-infra/aws-ebs-csi-driver-service-account.yaml manifest by"
echo "replacing "arn:aws:iam::088153174681:role/mb-eks-ebs-csi-driver-role" with your own role ARN:"
echo $(terraform output -raw ebs_csi_driver_service_account_iam_role_arn)
wait_for_keypress

echo "Apply the Kubernetes service account configuration for ebs-csi-controller-sa and the storage class manifest:"
kubectl apply -f k8s-infra/aws-ebs-csi-driver-service-account.yaml
kubectl apply -f k8s-infra/aws-ebs-storageclass.yaml
wait_for_keypress

echo "Follow the steps in [./k8s-examples/ebs-storage/README.md](./k8s-examples/ebs-storage/README.md) to"
echo "verify that EBS persistent volumes and storage claims can be utilized in your cluster."
wait_for_keypress

####################### ./k8s-examples/ebs-storage/README.md ########################
echo "# Deploying the Pod with EBS PersistentVolumeClaim to AWS EKS"
echo "## How to Deploy and Verify, Step by Step"
echo "*Prerequisites:* Have the EKS cluster set up with AWS Elastic Block Storage per the instructions in"
echo "the [root README.md](../../README.md)."
wait_for_keypress

echo "Change directory to ./k8s-examples/ebs-storage/ and apply the Pod and PersistentVolumeClaim config:"
kubectl apply -f ./k8s-examples/ebs-storage/pod-with-pvc.yml
wait_for_keypress

echo "Get the EBS CSI controller pod names:"
kubectl get pods -n kube-system | grep ebs-csi-controller
echo "Check the logs from the two pods from the previous command:"
kubectl logs deployment/ebs-csi-controller -n kube-system -c csi-provisioner --tail 10
echo "Confirm that a persistent volume was created with status of Bound to a PersistentVolumeClaim:"
kubectl get pv
echo "View details about the PersistentVolumeClaim that was created:"
kubectl get pvc
echo "View the sample app pod's status until the STATUS becomes Running."
kubectl get pods -o wide
wait_for_keypress 10

echo "Confirm that the data is written to the volume:"
kubectl exec ebs-app -- sh -c "cat data/out.txt"
wait_for_keypress

echo "Delete the pod and then create it again:"
kubectl delete pods/ebs-app --now
kubectl apply -f ./k8s-examples/ebs-storage/pod-with-pvc.yml
wait_for_keypress 30

echo "Verify that the old data is still attached and appended to:"
kubectl exec ebs-app -- sh -c "cat data/out.txt"
wait_for_keypress

################################### Step 3 ###################################
echo "### Step 3: Configure the AWS Elastic File System Storage for EKS"
echo "Configure persistent storage using EFS for EKS by following"
echo "the [Amazon EFS CSI Driver User Guide](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html), summarized below."
echo "Modify the ./k8s-infra/aws-efs-csi-driver-service-account.yaml manifest by"
echo "replacing "arn:aws:iam::088153174681:role/mb-eks-efs-csi-driver-role" with your own role ARN:"
echo $(terraform output -raw efs_csi_driver_service_account_iam_role_arn)
wait_for_keypress

echo "Apply the Kubernetes service account configuration for efs-csi-controller-sa:"
kubectl apply -f k8s-infra/aws-efs-csi-driver-service-account.yaml
wait_for_keypress

echo "Install the Amazon EFS driver using [Helm V3](https://docs.aws.amazon.com/eks/latest/userguide/helm.html) or later,"
echo "replacing us-east-1 with your region:"
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
helm repo update
helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
    --namespace kube-system \
    --set image.repository=602401143452.dkr.ecr.$AWS_REGION.amazonaws.com/eks/aws-efs-csi-driver \
    --set controller.serviceAccount.create=false \
    --set controller.serviceAccount.name=efs-csi-controller-sa
wait_for_keypress

echo "Identify the EFS filesystem ID:"
echo $(terraform output -raw efs_fs_id)
echo "Modify the ./k8s-infra/aws-efs-storageclass.yaml manifest by replacing "fs-033a36bdf9a4002c5" with"
echo "the filesystem ID from your environment and apply:"
wait_for_keypress 10
kubectl apply -f k8s-infra/aws-efs-storageclass.yaml
wait_for_keypress

echo "Follow the steps in [./k8s-examples/efs-storage/README.md](./k8s-examples/efs-storage/README.md) to"
echo "verify that EFS persistent volumes and storage claims can be utilized in your cluster."
wait_for_keypress

####################### ./k8s-examples/efs-storage/README.md ########################
echo "# Deploying the Pod with EFS PersistentVolumeClaim to AWS EKS"
echo "## How to Deploy and Verify, Step by Step"
echo "*Prerequisites:* Have the EKS cluster set up with AWS Elastic File System Storage per the instructions in"
echo "the [root README.md](../../README.md)."
wait_for_keypress

echo "Change directory to ./k8s-examples/efs-storage/ and apply the Pod and PersistentVolumeClaim config:"
kubectl apply -f ./k8s-examples/efs-storage/pod-with-pvc.yml
wait_for_keypress

echo "Get the EFS CSI controller pod names:"
kubectl get pods -n kube-system | grep efs-csi-controller
echo "Check the logs from the two pods from the previous command:"
kubectl logs deployment/efs-csi-controller -n kube-system -c csi-provisioner --tail 10
echo "Confirm that a persistent volume was created with status of Bound to a PersistentVolumeClaim:"
kubectl get pv
echo "View details about the PersistentVolumeClaim that was created:"
kubectl get pvc
echo "View the sample app pod's status until the STATUS becomes Running."
kubectl get pods -o wide
wait_for_keypress 10

echo "Confirm that the data is written to the volume:"
kubectl exec efs-app -- sh -c "cat data/out"
wait_for_keypress

echo "Delete the pod and then create it again:"
kubectl delete pods/efs-app --now
kubectl apply -f ./k8s-examples/efs-storage/pod-with-pvc.yml
wait_for_keypress 30

echo "Verify that the old data is still attached and appended to:"
kubectl exec efs-app -- sh -c "cat data/out"
wait_for_keypress
