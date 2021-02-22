provider "aws" {
  region = var.aws_region
}

# Look up ECR Repo based on name
data "aws_ecr_repository" "app" {
  name = var.aws_ecr_name
}

# Look up ACM Cert by name
data "aws_acm_certificate" "acm_cert" {
  domain   = local.app_host_name
}

#Look up DNS zone by name
data "aws_route53_zone" "dns_zone" {
  name = var.aws_dns_zone
}

# Read information about the load balancer using the AWS provider.
data "aws_elb" "loadbalencer" {
  name = local.lb_name
}

# Update DNS CNAME for service
resource "aws_route53_record" "dns_cname" {
  zone_id = data.aws_route53_zone.dns_zone.zone_id
  name    = var.app_cname
  type    = "CNAME"
  ttl     = 5
  records = [kubernetes_service.service.status.0.load_balancer.0.ingress.0.hostname]
}

# Create a local variable for the load balancer name and host name
locals {
  lb_name = split("-", split(".", kubernetes_service.service.status.0.load_balancer.0.ingress.0.hostname).0).0
  app_host_name = join(".", [var.app_cname, var.aws_dns_zone])
}

output "load_balancer_name" {
  value = local.lb_name
}