variable "account_id" {
  description = "AWS account ID"
  default     = "088153174681"
}

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "eks_elb_domain" {
  description = "Domain for EKS ELB"
  default     = "k8s-ingressn-ingressn-2a442cba42-0262477c32493f9a.elb.us-east-1.amazonaws.com"
}

variable "eks_elb_zone_id" {
  description = "Zone ID for EKS ELB"
  default     = "Z26RNL4JYFTOTI"
}

variable "route53_apex" {
  description = "Domain for Route 53 hosted zone"
  default     = "viewspotstudio.com"
}

variable "route53_subdomain" {
  description = "Subdomain name for Route 53 hosted zone"
  default     = "mvp-dev"
}

variable "common_origin_tag" {
  description = "AWS Tag value for key Origin"
  default     = "Terraform Cloud"
}

variable "common_owner_tag" {
  description = "AWS Tag value for key Owner"
  default     = "steve.strom"
}

variable "common_purpose_tag" {
  description = "AWS Tag value for key Purpose"
  default     = "Getting friendly with EKS"
}

variable "common_stack_tag" {
  description = "AWS Tag value for key Stack"
  default     = "Dev"
}
