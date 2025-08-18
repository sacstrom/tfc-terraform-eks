output "elb_fqdn" {
  description = "FQDN for K8s Elastic Load Balancer"
  value       = aws_route53_record.subdomain_elb_alias.fqdn
}
