DevOps Practice Project – Dist Directory

This repository contains the production-ready build files (dist folder) for DevOps practice and deployment exercises.

It is intentionally structured to help learners focus on CI/CD pipelines, hosting, containerization, and infrastructure setup rather than application development.

📁 What This Repository Contains

dist/ – Compiled and production-ready static files

HTML

CSS

JavaScript

Assets (images, fonts, etc.)

These files are ready to deploy to:

Web servers (Nginx / Apache)

Cloud platforms (AWS S3, Azure Blob, GCP Storage)

Containerized environments (Docker + Nginx)

Kubernetes clusters

CI/CD pipeline demonstrations

🎯 Purpose of This Repository

This repository is designed for:

DevOps beginners

CI/CD practice

Deployment pipeline testing

Docker & Kubernetes deployment exercises

Web server configuration practice

Reverse proxy and load balancer setup

The goal is to simulate real-world deployment scenarios using already built application files.

❓ Why is there NO package.json?

You may notice that this repository does not include:

package.json

node_modules

Source code (src/)

Build tools configuration

✅ Reason:

This repository only contains the final production build output (dist), not the development source code.

In a typical project:

Developers write source code.

The project is built using tools like:

Node.js

Webpack

Vite

React (or other frameworks)

A dist/ folder is generated.

Only the production build is deployed to servers.

This repository represents step 4 only.

Since this is already the compiled output:

No dependencies are required

No build process is required

No package.json is needed

# AWS EKS Deployment

## Project links

- Repository: https://github.com/arasantam786-wq/trend-devops-deployment
- Original application: https://github.com/Vennilavanguvi/Trend
- DockerHub image: desing96/trend-app
- AWS region: us-east-1
- EKS cluster: trend-eks
- Application namespace: trend

Application URL:

http://k8s-trend-trendapp-a6e5ad13bf-7ec04fa605105766.elb.us-east-1.amazonaws.com:3000

Network Load Balancer ARN:

```text
arn:aws:elasticloadbalancing:us-east-1:060651979375:loadbalancer/net/k8s-trend-trendapp-a6e5ad13bf/7ec04fa605105766
```

These addresses identify this deployment and will change if infrastructure is recreated.

## Architecture

GitHub push → GitHub webhook → Jenkins → Docker build and checks
→ DockerHub push → kubectl deployment → AWS EKS → public NLB.

Prometheus collects Kubernetes metrics. Grafana displays CPU and
memory usage for application pods.

The supplied application contains compiled assets in dist/.
The pipeline packages these assets into an Nginx image; it does
not compile React source code.

## Requirements

- AWS account and an authorized IAM role.
- Ubuntu workstation with Git, Docker, Terraform, AWS CLI,
  kubectl, and Helm.
- GitHub repository and DockerHub account.
- EC2 SSH key stored privately.
- Appropriate AWS permissions and available service quotas.

AWS infrastructure incurs charges while it exists.

## Infrastructure setup

Clone the deployment repository:

```bash
git clone https://github.com/arasantam786-wq/trend-devops-deployment.git
cd trend-devops-deployment
```

Review the Terraform files and configure the required variables,
including the existing EC2 key pair and administrator IP range.
Keep private values in an ignored terraform.tfvars file.

From the terraform directory:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

The configuration provisions networking, IAM roles, Jenkins EC2,
EKS, worker nodes, and supporting infrastructure.

Preserve Terraform state securely. Use the existing state when
managing an existing deployment. Never commit state, private keys,
tokens, passwords, or private variable files.

Configure cluster access:

```bash
aws eks update-kubeconfig --region us-east-1 --name trend-eks
kubectl get nodes
kubectl apply -f k8s/namespace.yaml
```

Cluster access requires an authorized EKS access entry.

## Docker build and local test

Run from the repository root on a machine with Docker:

```bash
docker build -t trend-app:local .
docker run --rm trend-app:local nginx -t
docker run --rm -d --name trend-local -p 3000:3000 trend-app:local
curl -I http://localhost:3000
docker stop trend-local
```

Nginx serves the supplied dist/ files on port 3000.

## AWS Load Balancer Controller

The internet-facing NLB requires the AWS Load Balancer Controller.

After applying the Terraform IAM configuration, install the
service account and controller:

```bash
kubectl apply -f addons/load-balancer-service-account.yaml
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --version 1.14.0 \
  --values addons/load-balancer-values.yaml \
  --wait
```

For a different AWS account or recreated cluster, update the
service-account role ARN, cluster name, region, VPC ID, and
OIDC trust configuration.

## Jenkins configuration

Required plugins: Pipeline, Git, GitHub, Docker Pipeline,
Docker, and Kubernetes.

The Jenkins host requires Docker, AWS CLI, and kubectl.
The Jenkins service account needs Docker access, and its EC2 IAM
role needs EKS authentication and deployment permissions in trend.

Create a Jenkins username/password credential:

- ID: dockerhub-credentials
- Username: DockerHub username
- Password: DockerHub access token with push permission

Create a Pipeline job using Pipeline script from SCM:

- SCM: Git
- Repository: this GitHub repository
- Branch: */main
- Script path: Jenkinsfile
- Trigger: GitHub hook trigger for GITScm polling

Configure the GitHub webhook with:

- URL: http://JENKINS_PUBLIC_IP:8080/github-webhook/
- Content type: application/json
- Event: push
- Secret: the same private value configured in Jenkins

Store the webhook secret in Jenkins credentials and configure it
as the GitHub shared secret. Never put the secret in Git.

## Pipeline stages

1. Check out the repository.
2. Build the Docker image.
3. Validate Nginx configuration and confirm index.html exists.
4. Authenticate to DockerHub using Jenkins credentials.
5. Push an image tagged with the commit ID and build number.
6. Apply the Kubernetes service and deployment with that image.
7. Wait for the deployment rollout and display pod/service status.
8. Remove the local build image.

The application uses two replicas, resource requests and limits,
health probes, and rolling updates.

Verified successful build: Jenkins #8.
Image: desing96/trend-app:a9c558ad21d2-8.

## Monitoring setup

Run from the repository root:

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --version "$(cat monitoring/chart-version.txt)" \
  --values monitoring/values.yaml \
  --values monitoring/grafana-resources.yaml \
  --wait --timeout 10m

kubectl get pods -n monitoring
```

Both values files are required. The second file sets Grafana's
memory limit to 1Gi to address the observed OOMKilled restarts.

Grafana remains private. From Windows PowerShell, in the directory
containing the SSH key, run:

```powershell
ssh -i .\trend-key.pem -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -L 3003:127.0.0.1:3003 ubuntu@WORKSTATION_PUBLIC_IP "kubectl port-forward -n monitoring service/monitoring-grafana 3003:80"
```

Replace WORKSTATION_PUBLIC_IP with the current workstation IP.
Keep this command running and open http://127.0.0.1:3003.

Retrieve the initial admin password on the Ubuntu workstation:

```bash
kubectl get secret monitoring-grafana -n monitoring \
  -o jsonpath='{.data.admin-password}' | base64 --decode
echo
```

Keep the password private. Open the dashboard
Kubernetes / Compute Resources / Namespace (Pods), select
namespace trend, and choose Last 15 minutes.

## Verification

```bash
kubectl get nodes
kubectl get pods -n trend -o wide
kubectl get service trend-app -n trend
kubectl rollout status deployment/trend-app -n trend
kubectl get pods -n monitoring
```

Verified results:

- Two EKS nodes Ready.
- Two application pods Running on separate nodes.
- Application service exposed through an NLB on port 3000.
- Jenkins build #8 completed successfully.
- Grafana displayed CPU and memory metrics for both application pods.

## Screenshots

Store submission screenshots in docs/screenshots/:

- jenkins-build-8-success.png
- eks-deployment-status.png
- grafana-trend-monitoring.png
- application.png
- load-balancer.png

Screenshots must exclude passwords, tokens, and private keys.

## Current limitations

This assessment deployment still requires additional hardening
before production use:

- HTTPS for the application and Jenkins.
- Persistent monitoring storage and backups.
- Alertmanager configuration and notification routing.
- A secure remote Terraform state backend with locking.
- Image vulnerability scanning and stronger container hardening.

Monitoring currently uses temporary storage and 24-hour metric
retention. Grafana data is not persistent. Alertmanager is disabled.
