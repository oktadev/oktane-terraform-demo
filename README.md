# Okta Terraform Demo

Deploys an application that uses Okta to AWS EKS (Elastic Kubernetes Service) with Terraform, using the [Okta Terraform Provider](https://registry.terraform.io/providers/oktadeveloper/okta/latest/docs).

**NOTE:** This example uses a Java / [JHipster](https://jhipster.tech) application, but you could replace the application's container with your own application.

## Prerequisites

You need an [Okta API Token] (https://bit.ly/get-okta-api-token).

Create a `secrets.tfvars` file:
```txt
okta_api_token = "YOUR-API-TOKEN"
```

A Route 53 zone has been created, see below for the list of Terraform Variables.

Install the following:
* Install the v2 version of the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
* Install [`eksctl`](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)
* Install aws2-wrap (to make old versions of the AWS tools work with SSO): `pip3 install aws2-wrap==1.1.6`

## Setup AWS to SSO with Okta (Optional)

**NOTE:** If you are going to setup SSO, it's MUCH easier to set it up BEFORE you create a cluster (otherwise you will need to tweak more permissions in Kubernetes.)

Glancing over a bit for now, see the [AWS docs for more details](https://docs.aws.amazon.com/singlesignon/latest/userguide/okta-idp.html).

In Your Okta org:

(From the "classic console")
Create a new Okta Application:
**Application** -> **Add Application** -> "AWS Single Sign-on"
* Click **Add**
* Click **Done**
* Click on the "Sign On" tab -> "Identity Provider metadata"
* Save this XML file as `metadata.xml`

(you will come back here in a moment)

In your AWS dashboard:
Search navigate to "SSO"

Make sure you can "Enable SSO", if not the dashboard should instruct you on how to enable the feature
* Click "Choose your identity source"
* **identity source** -> **Change**
* External Identity provider
* **IdP SAML metadata** -> **Browse...**
* Choose the `metadata.xml` from the previous step
* Click **Next: Review**
* Accept the prompts and click **Return to settings**
* **Identity source** -> **Provisioning** -> **Enable automatic provisioning** (copy the SCIM endpoint URL and token, you will need this in the next step)
* **Identity source** -> **Authentication** -> **View details** (you will need the ACS and issuer URLs in the next step)
* Click **User portal** -> **Customize** and set a user friendly name

Back in the Okta "Amazon SSO App"
* **Sign On** -> **Settings** -> **Edit**
* Set the **AWS SSO ACS URL** and **AWS SSO issuer URL** with the URLs from the previous step
* **Credentials Details** -> **Application username format** -> set to "Email"
* **Save**
* Switch to the **Provisioning** tab -> **Configure API Integration**
* Check **Enable API integration**
* Set the **Base URL** and **API Token** with the AWS SCIM values from above (**NOTE:** You MUST remove the trailing slast form the URL)
* **Test API Credentials***
* **Save**
* **Provisioning to App** -> **Edit** -> Enable **Create Users**, **Update User Attributes**, and **Deactivate Users**
* **Save**

At this point you have some flexibility, you will need to create Okta groups, add users to those groups, and then configure these as "Push Groups"
These groups will be mapped to AWS IAM Roles.

For example, to grant Admin access:
Create an Okta group `okta-aws-admin`, assign a user to it
Set this group as a "Push Group" in the "Amazon Single Sign-on" application

Make sure everything is working by going to the **Provisioning** tab, and clicking the **Force Sync** button

Back on the Amazon side, go back to the top level SSO dashboard and select **Manage SSO access to your AWS account**
* **Permission sets** tab -> **Create permission set**
* **Use an existing job function policy** -> **AdministratorAccess** -> **Next: Tags** -> **Create**
* Select **Groups*** form the left nav


* Run:
    ```sh
    aws configure sso --profile=sso
    
    # To prompt for login run:
    aws sso login --profile sso
    ```
    
    This will prompt for an SSO url and a region, this was the URL you customized in a previous step, `https://<customized>.awsapps.com/start`
    
* Edit `~/.aws/config` to use `aws2-wrap` for the default profile:
    ```ini
    [default]
    credential_process = aws2-wrap --process --profile sso
    region = us-east-2

    [profile sso]
    sso_start_url = https://your-domain.awsapps.com/start
    sso_region = us-east-2
    sso_account_id = 000000000000
    sso_role_name = your-sso-role-from-setup
    region = us-east-2
    ```
    
    Using `aws2-wrap` in the "default" profile allows older tools that do NOT yet support SSO to continue working.
    
* Create a AWS ECR Repository

    This will be the repository that your application's container gets deployed to.

    ```sh
    aws ecr create-repository --repository-name munchbox-www --profile sso
    ```

    The result will show JSON of the created repo, copy the `repositoryUri` value.

* Configure Docker to use AWS Repository :    
    ```sh
    # Use the URL from the previous step:
    aws ecr get-login-password --profile sso | docker login --username AWS --password-stdin <url-from-previous-step>
    ```
    
* Create Kubernetes Cluster
    ```sh
    eksctl create cluster --name demo-cluster --nodegroup-name t2-small --nodes 2 --node-type t2.small --tags 'Key=event,Value=Oktane21'
    
    # NOTE if you need to scale the cluster later use:
    eksctl scale nodegroup --cluster=demo-cluster --nodes=3 --nodes-max=3 --name=t2-small
    ```
    
    **NOTE:** This takes a while, let it run.
    
* Configure `kubectl` to use EKS
    This should be run automatically as part of the previous step, but if you stopped the process too soon, or you need to access the cluster from a different machine, run:
  
    ```sh
    eksctl utils write-kubeconfig --name=demo-cluster
    
    # NOTE: it's possible to use an `aws eks` command to do this, but it does NOT work with SSO users
    ```

## Build and Deploy Application

More glancing over, you can replace this section with your own app, but this demo is packaged with a JHipster app that can be created by running:

Install [JHipster](https://www.jhipster.tech/installation/#local-installation-with-npm-recommended-for-normal-users), and then run:

```sh
pushd munchbox-app

# create the app based on the jdl file
jhipster jdl app.jdl

# Build the container
./mvnw package -Pprod verify jib:dockerBuild

# Tag the image with your AWS ECR repo
docker image tag munchbox <000000000000.dkr.ecr.us-east-2.amazonaws.com/your-repo>

# Push the image to the repo
docker image push <000000000000.dkr.ecr.us-east-2.amazonaws.com/your-repo>

popd
```

## Deploy Application to EKS with Terraform

Update the `variables.tf`, file you will likely need to update these variables to match your environment.

Run Terraform:

```sh
# Import the default authorization server
terraform import -var-file secrets.tfvars okta_auth_server.default default

# NOTE: If you are importing other manually created resources you must import them first
# For example to import an existing ROLE_ADMIN group use:
# terraform import -var-file secrets.tfvars  okta_group.okta_group_admin "id-of-group"

terraform apply -var-file secrets.tfvars
```

This does many things including:
* Creates a Okta OIDC application
* Configures the 'default' Okta Authorization Server to add a `groups` claim
* Add Okta Groups `USER_ROLE`, `ADMIN_ROLE` (needed for JHIPSTER)
* Creates a k8s deployment and service (and assigns the OIDC config to it via env vars)
* Sets up DNS records for the service's load balancer

**NOTE:** When you create users, you will need to ensure your Users are added to the Okta `USER_ROLE` group.

Once DNS has propagated the new application should be running at the URL shown at the end of the Terraform run's `application_url` output.

Browse there and login💥

## Terraform Variables / Secrets

See `./variables.tf` for the complete list, you will need to set these to match your environment:

| Variable Name  | Default Value  | Description  |
|----------------|----------------|--------------|
| `kube_namespace` | `munchbox-www` | Kubernetes namespace |
| `aws_region` | `us-west-2` | AWS region |
| `aws_dns_zone` | `munchbox.menu` | AWS Route 53 Zone name |
| `app_cname` | `www` | CNAME relative to the aws_dns_zone var |
| `aws_ecr_name` | `munchbox-www` | Container Repository Name, used to lookup the repository URL |
| `image_version` | `latest` | Version of container image, appeded to the repository URL, `<repo_url>:<version>` |
| `container_port` | `8080` | Container port, the port to expose |
| `okta_org_name` | `accounts` | Okta Organization Name, used to create Okta Org URL: `https://<org_name>.<base_url>` |
| `okta_base_url` | `munchbox.menu` | Okta Base Url |
| `okta_api_token` | N/A | Okta API token |


