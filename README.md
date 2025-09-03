
# Terraform Cloud AWS EKS Setup

## What will This Do?

This Terraform project will set up a EKS cluster in your AWS account, then provision
a [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) for the Kubernetes
cluster and setup DNS names for it, then install a few add-ons to make RDS available and make S3/EFS/EBS storage
available. Finally, it will instruct you how to create a couple of deployments exposed to the world via
the [Nginx Ingress Controller](https://aws.amazon.com/premiumsupport/knowledge-center/eks-access-kubernetes-services/).


## What are the Pre-Requisites?

You must have access to an AWS account and be authorized to administer many resources. You must also have
the AWS and Terraform CLIs installed and configured on your workstation.

The setup instruction presumes that you have a profile named `terraform-mvp` in your AWS CLI configuration with your secrets
(`~/.aws/config` and `~/.aws/credentials`) that provides access to the Sennco AWS account. If not, login to the AWS
console, https://088153174681.signin.aws.amazon.com/console, create a "Command Line Interface (CLI)" type AWS Access Key
and store it safely. (Verify it works by running `aws sts get-caller-identity --profile terraform-mvp` and
`aws s3 ls s3://sennco-mvp-terraform-eks --profile terraform-mvp`.)


## Getting Started

### Step 1: Initialize the Base Infrastructure

1. Update the `./terraform.tf` to name the S3 bucket and key for your Terraform state
2. Update the `./variables.tf` to use your desired `resource_prefix`, and AWS `account_id` and `region`
3. Run `terraform init` in the repo root directory
4. Run `terraform plan && terraform apply` in the repo root and accept the proposed changes if they make sense to you
5. Open the AWS web console and verify your EKS cluster is up and looking good
6. Configure your `kubectl` command-line tool to use the new EKS cluster and keeping the credentials in `./.kubeconfig`:

       export KUBECONFIG="$(pwd)/.kubeconfig"
       export AWS_PROFILE=terraform-mvp
       export AWS_REGION=us-east-1
       export AWS_ACCOUNT_ID=602401143452
       export CLUSTER_NAME=mvp-dev-cluster
       aws --profile=$AWS_PROFILE eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

7. Verify your local configuration with `kubectl cluster-info`
8. Install the [Metrics Server](https://github.com/kubernetes-sigs/metrics-server):

       kubectl apply -f k8s-infra/metrics-server.yaml


### Step 2: Configure the AWS Elastic Block Storage for EKS

Configure persistent storage using EBS for EKS by following
the [Amazon EBS CSI Driver User Guide](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html), summarized below.

Modify the `./k8s-infra/aws-ebs-csi-driver-service-account.yaml` manifest by
replacing `"arn:aws:iam::088153174681:role/mvp-dev-ebs-csi-driver-role"` with your own role ARN:

    echo $(terraform output -raw ebs_csi_driver_service_account_iam_role_arn)

Apply the Kubernetes service account configuration for `ebs-csi-controller-sa` and the storage class manifest:

    kubectl apply -f k8s-infra/aws-ebs-csi-driver-service-account.yaml
    kubectl apply -f k8s-infra/aws-ebs-storageclass.yaml

Follow the steps in [./k8s-examples/ebs-storage/README.md](./k8s-examples/ebs-storage/README.md) to
verify that EBS persistent volumes and storage claims can be utilized in your cluster.


### Step 3: Configure the AWS Elastic File System Storage for EKS

Configure persistent storage using EFS for EKS by following
the [Amazon EFS CSI Driver User Guide](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html), summarized below.

Modify the `./k8s-infra/aws-efs-csi-driver-service-account.yaml` manifest by
replacing `"arn:aws:iam::088153174681:role/mvp-dev-efs-csi-driver-role"` with your own role ARN:

    echo $(terraform output -raw efs_csi_driver_service_account_iam_role_arn)

Apply the Kubernetes service account configuration for `efs-csi-controller-sa`:

    kubectl apply -f k8s-infra/aws-efs-csi-driver-service-account.yaml

Install the Amazon EFS driver using [Helm V3](https://docs.aws.amazon.com/eks/latest/userguide/helm.html) or later,
replacing `us-east-1` with your region:

    helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
    helm repo update
    helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
      --namespace kube-system \
      --set image.repository=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/eks/aws-efs-csi-driver \
      --set controller.serviceAccount.create=false \
      --set controller.serviceAccount.name=efs-csi-controller-sa

Identify the EFS filesystem ID:

    echo $(terraform output -raw efs_fs_id)

Modify the `./k8s-infra/aws-efs-storageclass.yaml` manifest by replacing `"fs-033a36bdf9a4002c5"` with
the filesystem ID from your environment and apply:

    kubectl apply -f k8s-infra/aws-efs-storageclass.yaml

Follow the steps in [./k8s-examples/efs-storage/README.md](./k8s-examples/efs-storage/README.md) to
verify that EFS persistent volumes and storage claims can be utilized in your cluster.


### Step 4: Configure Internet Network Ingress

#### Step 4a: Configure the AWS Load Balancer Controller Add-On

Deploy the AWS Load Balancer Controller by following
the [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html),
summarized below.

Modify the `./k8s-infra/aws-load-balancer-controller-service-account.yaml` manifest by
replacing `"arn:aws:iam::088153174681:role/mvp-dev-load-balancer-controller-role"` with your own role ARN:

    echo $(terraform output -raw aws_load_balancer_service_account_iam_role_arn)

Apply the Kubernetes service account configuration for `aws-load-balancer-controller`:

    kubectl apply -f k8s-infra/aws-load-balancer-controller-service-account.yaml

Install the AWS Load Balancer Controller using [Helm V3](https://docs.aws.amazon.com/eks/latest/userguide/helm.html) or
later by applying the Kubernetes manifest:

    # Ensure output matches expectation
    export CLUSTER_NAME=$(terraform output -raw cluster_name) && echo $CLUSTER_NAME

    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=$CLUSTER_NAME \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller

Verify that the controller is installed:

    kubectl get deployment -n kube-system aws-load-balancer-controller

Example success output:

    kubectl get deployment -n kube-system aws-load-balancer-controller
    "NAME                           READY   UP-TO-DATE   AVAILABLE   AGE"
    "aws-load-balancer-controller   2/2     2            2           22h"


#### Step 4b: Configure the Nginx Ingress Controller for Kubernetes and Verify

Deploy the Nginx Ingress Controller, "Option 1", by following the AWS
[External Access to Kubernetes](https://aws.amazon.com/premiumsupport/knowledge-center/eks-access-kubernetes-services/)
services guide, summarized in the following sections.

    kubectl apply -f k8s-infra/deploy-nginx-controller-with-ssl-v1.12.1.yaml

Verify that the AWS Load Balancer Controller is running:

    kubectl get all -n kube-system --selector app.kubernetes.io/instance=aws-load-balancer-controller

Verify that the Nginx Ingress Controller is running:

    kubectl get all -n ingress-nginx --selector app.kubernetes.io/instance=ingress-nginx

Verify that your Kubernetes cluster have ingress classes `alb` and `nginx`:

    kubectl get ingressclass


#### Step 4c: Configure DNS with Route53 and Verify

Get the AWS Load Balancer Endpoint created by the Nginx Ingress Controller:

    kubectl describe -n ingress-nginx service ingress-nginx-controller | grep Ingress | cut -d':' -f2 | xargs

Example:

    "k8s-ingressn-ingressn-d7a33e1924-2dcfed4179033b4a.elb.us-east-1.amazonaws.com"

Find the matching load balancer in the AWS Web Console under
[EC2 > Load Balancers](https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LoadBalancers) and
copy the _Hosted Zone ID_ from the details' view, a string that looks something like `"Z1UDT6IFJ4EJM"`.

Open the [Route 53 > Hosted Zones](https://us-east-1.console.aws.amazon.com/route53/v2/hostedzones#) view in the AWS Web
Console and copy the _Hosted Zone ID_ from your apex domain hosted zone, something like `"Z1TY55FUWSMGVV"`.

Modify the `./dns/variables.tf` config file by replacing the default value for `eks_elb_domain` and `eks_elb_zone_id`
with the Load Balancer Endpoint and Load Balancer Hosted Zone ID, and replacing `route53_apex_zone_id` with the
Apex Domain Hosted Zone ID.

Change directory to `./dns` and apply the Terraform configuration:

    cd dns/
    terraform init
    terraform plan
    terraform apply

Verify that `nslookup` returns 2 records for `mvp-dev.viewspotstudio.com`:

    nslookup mvp-dev.viewspotstudio.com

Verify that `curl` receives a Nginx 404 response:

    curl -v http://mvp-dev.viewspotstudio.com


#### Step 4d: Install Cert-Manager and Configure Certificate Issuer in EKS

Install Cert-Manager using Helm:

    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm install cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --set crds.enabled=true \
      --set config.featureGates.ACMEHTTP01IngressPathTypeExact=false

Modify the `./k8s-infra/letsencrypt-issuer.yaml` config file by adding your own email address and
then apply your certificate issuer manifest:

    kubectl apply -f k8s-infra/letsencrypt-issuers.yaml


#### Step 4e: Verify Internet Network Ingress with DNS and SSL

Follow the setup steps in [./k8s-examples/hello-kubernetes/README.md](./k8s-examples/hello-kubernetes/README.md) to
deploy the `hello-kubernetes` services and verify that it becomes accessible via the DNS pretty-names with SSL.


### Step 5: Configure the ACK Service Controller for RDS

Install the ACK controller following the
[Install ACK Service Controller for RDS](https://aws-controllers-k8s.github.io/community/docs/tutorials/rds-example/)
guide, summarized below.

Identify your own IAM role ARN for the `ack-rds-controller` service account:

    echo $(terraform output -raw ack_rds_controller_service_account_iam_role_arn)

Install the `rds-chart` controller, replacing `"arn:aws:iam::088153174681:role/mvp-dev-ack-rds-controller-role"` with
your own role ARN and `"us-east-1"` with your own region:

    export ACK_RDS_CONTROLLER_IAM_ROLE_ARN=arn:aws:iam::088153174681:role/mvp-dev-ack-rds-controller-role
    export AWS_REGION=us-east-1
    helm install --create-namespace -n ack-system \
      oci://public.ecr.aws/aws-controllers-k8s/rds-chart \
      --version=v0.0.27 \
      --generate-name \
      --set=aws.region=$AWS_REGION \
      --set=serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ACK_RDS_CONTROLLER_IAM_ROLE_ARN"

Follow the setup steps in [./k8s-examples/vs-location/README.md](./k8s-examples/vs-location/README.md) to
deploy a feature complete Node application with persistent storage in a Postgres database on RDS.


### Step 6: Configure the ACK Service Controller for S3

Install the ACK controller for S3 following the
[Install an ACK Service Controller](https://aws-controllers-k8s.github.io/community/docs/user-docs/install/)
guide, summarized below.

Identify your own IAM role ARN for the `ack-rds-controller` service account:

    echo $(terraform output -raw ack_s3_controller_service_account_iam_role_arn)

Install the `rds-chart` controller, replacing `"arn:aws:iam::088153174681:role/mvp-dev-ack-s3-controller-role"` with
your own role ARN and `"us-east-1"` with your own region:

    export ACK_S3_CONTROLLER_IAM_ROLE_ARN=arn:aws:iam::088153174681:role/mvp-dev-ack-s3-controller-role
    export AWS_REGION=us-east-1
    helm install --create-namespace -n ack-system \
      oci://public.ecr.aws/aws-controllers-k8s/s3-chart \
      --version=v0.1.8 \
      --generate-name \
      --set=aws.region=$AWS_REGION \
      --set=serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ACK_S3_CONTROLLER_IAM_ROLE_ARN"

Follow the setup steps in [./k8s-examples/vs-studio/README.md](./k8s-examples/vs-studio/README.md) to
deploy a feature complete Node application with binary assets on S3.


### Step 7: Configure Access for a DevOps Team

Create the `vs7` namespace and RBAC roles `vs7-developer-global-viewer-role` and `vs7-developer-ns-admin-role`:

    kubectl create ns vs7
    kubectl apply -f k8s-infra/vs7-developer-global-viewer-role.yaml
    kubectl apply -f k8s-infra/vs7-developer-ns-admin-role.yaml

Update your `~/.kube/config-vs7-developer` with credentials for the `vs7-developer-role`:

    export KUBECONFIG=~/.kube/config-vs7-developer
    aws eks update-kubeconfig --profile terraform-mvp --name mvp-dev-cluster --alias mvp-dev-cluster-vs7-developer \
      --region us-east-1 --role-arn arn:aws:iam::088153174681:role/mvp-dev-vs7-developer-role
    # And verify it worked, the command below should output something about cluster name "mvp-dev-cluster"
    kubectl cluster-info dump | grep cluster-name | head -n1

Now the tables are set for low-privileged creation of resources within the `vs7` namespace.
