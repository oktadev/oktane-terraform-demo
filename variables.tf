variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "aws_ecr_name" {
  description = "Container Repository Name"
  type        = string
  default     = "munchbox-www"
}

variable "image_version" {
  description = "Version of container image"
  type        = string
  default     = "latest"
}

variable "kube_namespace" {
  description = "k8s namespace"
  type        = string
  default     = "munchbox-www"
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

# I'm not sure why this hostname is broken into two parts
variable "okta_org_name" {
  description = "Okta Org Name"
  type        = string
  default     = "accounts"
}
variable "okta_base_url" {
  description = "Okta Base Url"
  type        = string
  default     = "munchbox.menu"
}

variable "okta_api_token" {
  description = "Okta API token"
  type        = string
  sensitive   = true
}

variable "aws_dns_zone" {
  description = "AWS Route 53 Zone name"
  type        = string
  default     = "munchbox.menu"
}

variable "app_cname" {
  description = "CNAME relative to the aws_dns_zone var"
  type        = string
  default     = "www"
}
