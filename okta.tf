provider "okta" {
  org_name  = var.okta_org_name
  base_url  = var.okta_base_url
  api_token = var.okta_api_token
}

# Create an OIDC application
resource "okta_app_oauth" "app_oauth" {
  label                      = local.app_host_name
  issuer_mode                = "CUSTOM_URL"
  type                       = "web"
  grant_types                = ["authorization_code"]
  redirect_uris              = [format("https://%s/login/oauth2/code/oidc", local.app_host_name)]
  post_logout_redirect_uris  = [format("https://%s/", local.app_host_name)]
  response_types             = ["code"]
  lifecycle {
     ignore_changes = [groups]
  }
}

# Create a user role group
resource "okta_group" "okta_group_user" {
  name        = "ROLE_USER"
  description = "User Role"
}

# Create a admin role group
resource "okta_group" "okta_group_admin" {
  name        = "ROLE_ADMIN"
  description = "Admin Role"
}

# Add the "ROLE_USER" group to the OIDC app
resource "okta_app_group_assignment" "user-role-to-app" {
  app_id   = okta_app_oauth.app_oauth.id
  group_id = okta_group.okta_group_user.id
}

# get the ID of the 'default' auth server
resource "okta_auth_server" "default" {
  name        = "default"
  audiences   = ["api://default"]
  issuer_mode = "CUSTOM_URL"
}

# Add the 'groups' claim to ID and Access tokens
resource "okta_auth_server_claim" "id_claim_groups" {
  auth_server_id = okta_auth_server.default.id
  name           = "groups"
  claim_type     = "IDENTITY"
  value_type     = "GROUPS"
  group_filter_type = "REGEX"
  value          = ".*"
}
resource "okta_auth_server_claim" "access_claim_groups" {
  auth_server_id = okta_auth_server.default.id
  name           = "groups"
  claim_type     = "RESOURCE"
  value_type     = "GROUPS"
  group_filter_type = "REGEX"
  value          = ".*"
}
