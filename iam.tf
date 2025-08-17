resource "aws_iam_policy" "worker-policy" {
  name        = "${var.resource_prefix}-worker-policy"
  description = "EKS worker policy for the ELB Ingress"

  policy = file("iam-policies/eks-worker-policy.json")

  tags = {
    Origin         = var.common_origin_tag
    ResourcePrefix = var.resource_prefix
    Owner          = var.common_owner_tag
    Purpose        = var.common_purpose_tag
    Stack          = var.common_stack_tag
  }
}
