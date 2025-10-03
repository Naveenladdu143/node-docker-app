# Node.js ECS Deployment with Docker, Terraform, and CI/CD

This project demonstrates deploying a containerized Node.js application on **AWS ECS** using **Terraform**, with additional Linux hardening and CI/CD via GitHub Actions.

---

## 1. EC2 Setup (for initial testing)

### 1.1 Launch an EC2 instance

* Sign in → **Services → EC2 → Launch instances**
* **AMI**: Amazon Linux 2 (x86_64)
* **Instance type**: `t2.medium`
* **Network**: Use default VPC and public subnet
* **Public IP**: Enable
* **Storage**: 8 GB (default)
* **Security Group**:

  * Allow SSH (22) from your IP
  * Allow HTTP (80) or app port (3000)
* **Key Pair**: Create/download `.pem`

### 1.2 Connect via SSH

```bash
ssh -i ~/Downloads/node-app.pem ec2-user@<PUBLIC_IP>
```

### 1.3 Install dependencies

```bash
# Update packages
sudo yum update -y

# Install Git
yum install -y git
git --version

# Install Docker
sudo amazon-linux-extras install docker -y
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
docker --version
```

---

## 2. Node.js App & Dockerization

### 2.1 Create Node app

**app.js**

```js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => { res.send('Hello from Node.js Dockerized App 🚀'); });
app.get('/health', (req, res) => { res.json({status: 'ok'}); });

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
```

**package.json**

```json
{
  "name": "node-docker-app",
  "version": "1.0.0",
  "main": "app.js",
  "scripts": { "start": "node app.js" },
  "dependencies": { "express": "^4.18.2" }
}
```

### 2.2 Docker setup

**.dockerignore**

```
node_modules
npm-debug.log
Dockerfile
.dockerignore
.git
.gitignore
.env
```

**Dockerfile**

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

FROM node:20-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/app.js ./
USER appuser
EXPOSE 3000
CMD ["node", "app.js"]
```

### 2.3 Build & push image

```bash
docker build -t node-app:latest .
docker run -itd -p 3000:3000 node-app:latest

# Push to DockerHub
docker login
docker tag node-app naveenladdu123/node-app:latest
docker push naveenladdu123/node-app:latest
```

---

## 3. Terraform Infrastructure

### Project Layout

```
terraform/
├── backend-bootstrap/
├── modules/
│   ├── network/
│   ├── alb/
│   ├── ecs/
│   ├── iam/
├── envs/
│   └── dev/
│       ├── terraform.tfvars
│       └── provider.tf
└── main.tf
```

### 3.1 Remote backend (S3 + DynamoDB)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-2131"
    key            = "ecs-demo/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-1"
}
```

---

### 3.2 Network Module

Creates **VPC, subnets, IGW, route tables, and SGs**.

`outputs.tf`

```hcl
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "alb_sg_id" { value = aws_security_group.alb_sg.id }
```

Usage in root `main.tf`:

```hcl
module "network" {
  source              = "./modules/network"
  name                = "my-ecs-demo"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs= ["10.0.101.0/24", "10.0.102.0/24"]
  azs                 = ["eu-west-1a","eu-west-1b"]
  alb_allow_ports     = [80,443]
}
```

---

### 3.3 ALB Module

* Application Load Balancer
* Target Group for ECS
* HTTP/HTTPS Listeners

Example `terraform.tfvars`:

```hcl
name          = "my-ecs-demo"
vpc_id        = "vpc-0044de06c0da8a416"
public_subnets= ["subnet-09cc924f5ac633a2a", "subnet-0a9933648cdf88b00"]
alb_sg_id     = "sg-0b1297784280f495a"
```

---

### 3.4 ECS Module

Creates **Cluster, Task Definition, Service, CloudWatch logs**.

`terraform.tfvars`

```hcl
name             = "my-ecs-demo"
container_name   = "node-app"
container_image  = "naveenladdu123/node-app:latest"
container_port   = 3000
cpu              = "256"
memory           = "512"
execution_role_arn = "arn:aws:iam::351889159534:role/ecsTaskExecutionRole"
task_role_arn     = "arn:aws:iam::351889159534:role/ecsTaskRole"
private_subnets   = ["subnet-0ea54719ae4a04d97","subnet-00be3f1a7ae2021bb"]
ecs_sg_id        = "sg-0b1297784280f495a"
target_group_arn = "arn:aws:elasticloadbalancing:eu-west-1:351889159534:targetgroup/my-ecs-demo-tg-ip/12c6f88b75ce6318"
desired_count    = 2
aws_region       = "eu-west-1"
```

---

### 3.5 IAM Role Module

Creates **IAM role** for ECS Task Execution.

```hcl
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "exec_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

---

## 4. Linux Hardening

### 4.1 Disk usage script

`scripts/check_disk_usage.sh`

```bash
#!/usr/bin/env bash
THRESHOLD=${1:-80}

df -hP --exclude-type=tmpfs --exclude-type=devtmpfs | tail -n +2 | while read -r fs size used avail usep mount; do
  p=$(echo "$usep" | tr -d '%')
  if [ "$p" -ge "$THRESHOLD" ]; then
    echo "ALERT: $mount is ${usep} used"
  fi
done
```

### 4.2 SSH Hardening

Edit `/etc/ssh/sshd_config`:

```
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
```

Restart service:

```bash
sudo systemctl restart sshd
```

### 4.3 Firewall (UFW example)

```bash
sudo yum install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp from <YOUR_IP>/32
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## 5. CI/CD with GitHub Actions

**.github/workflows/ci.yml**

```yaml
name: CI/CD Node App

on:
  push:
    branches:
      - main

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Lint Dockerfile
        uses: hadolint/hadolint-action@v2
        with:
          dockerfile: ./app/Dockerfile

      - name: Build Docker image
        run: docker build -t node-app:latest .

      - name: Trivy Security Scan
        uses: aquasecurity/trivy-action@v2
        with:
          image-ref: naveenladdu123/node-app:latest

      - name: DockerHub Login
        env:
          DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
          DOCKERHUB_TOKEN: ${{ secrets.DOCKERHUB_TOKEN }}
        run: echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin

      - name: Push Docker image
        run: docker push naveenladdu123/node-app:latest
```

---

* Node.js app dockerized and tested locally
* Docker image pushed to DockerHub
* Infrastructure provisioned with Terraform (VPC, ALB, ECS, IAM)
* ECS Fargate service runs the app with ALB
* Linux hardening and monitoring scripts added
* CI/CD pipeline builds, scans, and pushes images automatically
