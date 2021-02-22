terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    okta = {
      source = "oktadeveloper/okta"
      version = "~> 3.6"
    }
  }
}

output "application_url" {
  value = format("https://%s/", local.app_host_name)
}