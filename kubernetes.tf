provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Create a namespace
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.kube_namespace
  }
}

# deploy a container
resource "kubernetes_deployment" "app_deployment" {
  metadata {
    name      = "demo"
    namespace = kubernetes_namespace.namespace.metadata.0.name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "demo"
      }
    }
    template {
      metadata {
        labels = {
          app = "demo"
        }
      }
      spec {
      
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100

              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["demo"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }
      
        container {
          image = join(":", [data.aws_ecr_repository.app.repository_url, var.image_version])
          name  = "demo"
          env {         
            name = "JAVA_OPTS"
            value = " -Xmx256m -Xms256m"
          }
          env {
            name  = "SPRING_SECURITY_OAUTH2_CLIENT_PROVIDER_OIDC_ISSUER_URI"
            value = okta_auth_server.default.issuer
          }
          env {
            name  = "SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_OIDC_CLIENT_ID"
            value = okta_app_oauth.app_oauth.client_id
          }
          env {
            name  = "SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_OIDC_CLIENT_SECRET"
            value = okta_app_oauth.app_oauth.client_secret
          }
          resources {
            limits = {
              cpu    = "1"
              memory = "1Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
          port {
            name = "http"
            container_port = var.container_port
          }
          readiness_probe {
            http_get {
              path = "/management/health"
              port = "http"
            }
            initial_delay_seconds = 20
            period_seconds = 15
            failure_threshold = 6
          }
          liveness_probe {
            http_get {
              path = "/management/health"
              port = "http"
            }
            initial_delay_seconds = 120
          }
        }
      }
    }
  }
}

# setup a service / loadbalancer
resource "kubernetes_service" "service" {
  metadata {
    name      = "app-service"
    namespace = kubernetes_namespace.namespace.metadata.0.name
    labels = {
      app = "demo"
    }
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = data.aws_acm_certificate.acm_cert.arn
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
      "external-dns.alpha.kubernetes.io/hostname" = local.app_host_name
    }
  }
  spec {
    selector = {
      app = kubernetes_deployment.app_deployment.spec.0.template.0.metadata.0.labels.app
    }
    type = "LoadBalancer"
    port {
      name        = "http"
      port        = 443
      target_port = var.container_port
    }
  }
}
