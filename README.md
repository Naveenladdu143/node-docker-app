Console (AWS Management Console) — step by step
2.1 Open EC2 Dashboard

Sign into AWS Console → Services → EC2 → Instances → Launch instances.

2.2 Choose an Amazon Linux 2 AMI

Select Amazon Linux 2 LTS (HVM), x86_64 (or ARM if you want Graviton). This is the default/first option.

2.3 Choose Instance Type

Choose t2.medium for testing (free tier eligible). Then Next: Configure Instance Details.

Configure Instance Details

Network: pick your VPC (default is fine for testing).

Subnet: pick a public subnet (if you want a public IP).

Auto-assign Public IP: Enable (for direct SSH from internet).

Add Storage

Default 8 GB is fine for small apps. Increase if you need more.

2.6 Add Tags

Add Name = my-node-server to easily identify.

2.7 Configure Security Group

Create a new security group or use existing.

Allow inbound SSH (TCP 22) — restrict Source to your IP (best practice).

Allow inbound HTTP (TCP 80) or app port (e.g., TCP 3000) as needed — Source 0.0.0.0/0 if public web access.

Review and Launch.

2.8 Key Pair

create a new key pair (download the .pem file). Store it safely — you’ll need it to SSH.

2.9 Launch & Verify

Click Launch instances. Wait a couple minutes for instance state → running. Note the Public IPv4 or Public DNS.
==============================================================================
Server-setup
Assumptions

1) You have SSH access to the server (example user ec2-user for Amazon Linux,).

2) You have a PEM key for SSH (if using EC2).

3) You want Docker containers (recommended) to run the app; Terraform used for infra automation.

===================================================================================
1) Connect to the server (from your local machine)
   
   ssh -i ~/Downloads/node-app.pem ec2-user@13.61.26.204
===============================================================

2) Update the OS packages
sudo yum update -y
===========================================================================

3) Create or validate a deploy user (optional)

 sudo adduser deploy
sudo usermod -aG wheel,docker deploy   
  
===================================================================================
4) Install Git (to pull repo)

sudo yum install -y git
to check the version below command
git --version

===============================================

5) Install Docker (recommended use: run containers)

Amazon Linux 2

sudo amazon-linux-extras install docker -y
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker 

to check the docker is availabe or not for below command refernce
docker --version

=====================================================================================


1 — Prepare the Node.js app

Create a folder node-docker-app/ and these two files inside it.

app.js file I have been created used below codes as well which is form the google

using below command created the file & pasted the code over the file
vim app.js

const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Hello from Node.js Dockerized App 🚀');
});

app.get('/health', (req, res) => {
  res.json({status: 'ok'});
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});


2 file name package.json i have used below depencies for this application 
created the file using this command & pasted the dependencies in that file  "vim package.json "

{
  "name": "node-docker-app",
  "version": "1.0.0",
  "main": "app.js",
  "scripts": { "start": "node app.js" },
  "dependencies": { "express": "^4.18.2" }
}
============================================================================
step =>2 — Add 

.dockerignore file
using below command & passed the dependecies over there
vim .dockerignore 

Create .dockerignore in the same folder to keep build context small:

node_modules
npm-debug.log
Dockerfile
.dockerignore
.git
.gitignore
.env

3 — Write a multi-stage Dockerfile (production, non-root)

From Dockerfile needs follow the below steps as well
created the Dockerfile using below command
Vim Dockerfile && pasted the parameters

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

===================================================================================================


sudo === extra privilages

create the docker image using below command
sudo docker build -t node-app:latest .

create the docker container using below command && pushed to Docker-repository
sudo docker run -itd -p 3000:3000 node-app:latest 
("itd= iteractive terminal d "Background or Detached" -p (Port mapping: Maps port 3000 on the host to port 3000 on the container.)")

we needs to login to the docker hub with the respective creds((docker login) username,password)

sudo docker tag node-app naveenladdu123/node-app:latest

Image pushed to the DOCKERHUB using below comman

sudo docker push naveenladdu123/node-app:latest

==========================================================================================================================

i have tested the application working or not using the localhost port number&& i am getting response as well
http://16.171.39.201:3000/
==========================================================================================================

1.I have install the vscode in my local 
2.configure the aws creds in vscode
===> below command
aws configre

aws-accesskey:
aws-secrete-key:
region:
format:
+++====+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
1. Project layout (recommended)

Organize your repo so it’s modular and easy to maintain:

terraform/
├─ backend-bootstrap/        
├─ modules/
│  ├─ network/
│  ├─ s3/
│  ├─ iam/
│  ├─ ecr/
│  ├─ alb/
│  └─ ecs/
├─ envs/
│  └─ dev/                   
│     ├─ terraform.tfvars
│     └─ provider.tf
└─ main.tf                   

2. (Optional but recommended) Create remote backend objects first

If you want Terraform state in S3 + locking with DynamoDB you must create the S3 bucket and DynamoDB table before you configure the backend. Do that either:

Manually (Console), or

With a tiny Terraform run that uses a local backend (a backend-bootstrap folder), or

With AWS CLI.

AWS CLI example (create bucket + DynamoDB)
# replace <region> and <bucket-name> and enable versioning if you want
aws s3api create-bucket --bucket my-terraform-state-bucket-<suffix> --region eu-north-1 \
  --create-bucket-configuration LocationConstraint=eu-north-1

aws s3api put-bucket-versioning --bucket my-terraform-state-bucket-<suffix> \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

3. Provider + Backend config (root/provider.tf)

After bucket exists, configure backend in provider.tf:

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
  region = eu-west-1
}


If you created the bucket with a bootstrap run, run terraform init in root; Terraform will initialize the S3 backend and start using it.

terraform plan ===> we can what infrastructure is going to createing the infra
traform format =====> it will make the infra correct alignment
Terraform apply =====> using this command it will create the infra

===================================================================================================================================================

1. Purpose

This network module creates the networking foundation for your environment:

VPC

2 public subnets

2 private subnets

Internet Gateway (IGW)

Public route table + association (for public subnets)

Security Group for Application Load Balancer (ALB)

2. Files in this module

You already have these in modules/network/:

main.tf — resources (VPC, subnets, IGW, route, SG)

variables.tf — module inputs (name, CIDRs, AZs, ALB ports)

(recommended) outputs.tf — module outputs (add this; example below)

(recommended) README.md — this document

Add outputs.tf so other modules can consume IDs:

# modules/network/outputs.tf
output "vpc_id" {
  description = "VPC id"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "List of public subnet ids"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet ids"
  value       = aws_subnet.private[*].id
}

output "alb_sg_id" {
  description = "Security group id for ALB"
  value       = aws_security_group.alb_sg.id
}


6. How to wire this module into your root main.tf

Example root main.tf that calls this module (place at ~/Terraform_ecs/main.tf):

module "network" {
  source = "./modules/network"
  name   = "my-ecs-demo"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
  azs = ["eu-west-1a","eu-west-1b"]
  alb_allow_ports = [80,443]
}


Then other modules (ALB, ECS) will reference the outputs:

vpc_id = module.network.vpc_id
public_subnet_ids = module.network.public_subnet_ids
private_subnet_ids = module.network.private_subnet_ids
alb_sg_id = module.network.alb_sg_id

7. Recommended variables.tf (you already have it)

You provided variables—good. Just ensure azs length >= number of subnets per type (count).

8. Run Terraform — exact command sequence (from repo root)

Important: Always run terraform init from the repo root where the backend and provider are defined, not inside the module folder (unless you are intentionally testing module alone).

Change to repo root:

cd ~/Terraform_ecs/network
pwd   # should show .../Terraform_ecs


Format files:

terraform fmt -recursive


Initialize (download providers and modules):

terraform init
# if you updated providers or want to force upgrades:
terraform init -upgrade


Validate config:

terraform validate


Create a plan (recommended to use a tfvars file if you use one):

# if you have terraform.tfvars in root
terraform plan -out=network-plan
# OR pass specific var values
terraform plan -var="region=eu-west-1" -var="name=my-ecs-demo" -out=network-plan


Apply the plan:

terraform apply "network-plan"
# or
terraform apply -auto-approve
============================================================================================================

====> cretae the folde alb then create the main.tf variable.tf we needs to pass the entaire sourec code which we have in the below

# modules/alb/main.tf
# Application Load Balancer
resource "aws_lb" "alb" {
  name                        = "${var.name}-alb"
  internal                    = false
  load_balancer_type          = "application"
  subnets                     = var.public_subnets
  security_groups             = [var.alb_sg_id]
  idle_timeout                = 60
  enable_deletion_protection  = false

  tags = {
    Name = "${var.name}-alb"
  }
}

# Target Group for ECS Fargate (target_type = "ip" for Fargate)
resource "aws_lb_target_group" "tg" {
  name             = "${var.name}-tg-ip"
  target_type      = "ip"
  port             = var.target_port
  protocol         = "HTTP"
  vpc_id           = var.vpc_id
  ip_address_type  = "ipv4"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.name}-tg"
  }
}

# ALB HTTP Listener (80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# OPTIONAL: HTTPS listener (commented out)
# To enable HTTPS you must create an ACM certificate and set protocol = "HTTPS" and certificate_arn.
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = var.acm_certificate_arn
#   default_action {
#     type = "forward"
#     target_group_arn = aws_lb_target_group.tg.arn
#   }
# }

varibale.tf file ==> create the file

variable "name" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB and target group will be created"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "target_port" {
  description = "Target port for the application"
  type        = number
  default     = 3000
}


terraform.tfvars.tf file will paste the below parameters
name           = "my-ecs-demo"
vpc_id         = "vpc-0044de06c0da8a416"         
public_subnets = ["subnet-09cc924f5ac633a2a", "subnet-0a9933648cdf88b00"]  
alb_sg_id      = "sg-0b1297784280f495a"          



terraform fmt -recursive
Initialize (download providers & modules)

bash
Copy code
terraform init
# or to force provider upgrades:
terraform init -upgrade
Validate

bash
Copy code
terraform validate
Plan (review changes)

bash
Copy code
terraform plan 
Apply

bash
Copy code
terraform apply 
=========================================================================================================================

A — ECS Module Structure

Inside your Terraform project (~/Terraform_ecs/modules/ecs):

modules/
  ecs/
    main.tf
    variables.tf
    terraform.tfvars.tf

B — Files for ECS Module
modules/ecs/main.tf
# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = local.cluster_name
}

# Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = local.family
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = "awsvpc"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.family}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = var.container_name
        }
      }
      secrets = [
        for s in var.secrets : {
          name      = s.name
          valueFrom = s.value_from
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  depends_on = [var.target_group_arn]
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.family}"
  retention_in_days = 7
}

modules/ecs/variables.tf
# ECS cluster/service variables
variable "aws_region" {
  description = "AWS region for ECS deployment"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "cpu" {
  description = "CPU units for ECS task"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Memory for ECS task"
  type        = string
  default     = "512"
}

variable "container_name" {
  description = "Name of the container"
  type        = string
}

variable "container_image" {
  description = "Container image (DockerHub or ECR)"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "private_subnets" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_sg_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN for ECS service"
  type        = string
}

variable "secrets" {
  description = "List of secrets for ECS container"
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []
}


create terrform.tfvars file paste the below code

name               = "my-ecs-demo"
container_name     = "node-app"
container_image    = "naveenladdu123/node-app:latest"
container_port     = 3000
cpu                = "256"
memory             = "512"
execution_role_arn = "arn:aws:iam::351889159534:role/ecsTaskExecutionRole"
task_role_arn      = "arn:aws:iam::351889159534:role/ecsTaskRole"
private_subnets    = ["subnet-0ea54719ae4a04d97","subnet-00be3f1a7ae2021bb"]
ecs_sg_id          = "sg-0b1297784280f495a"
target_group_arn   = "arn:aws:elasticloadbalancing:eu-west-1:351889159534:targetgroup/my-ecs-demo-tg-ip/12c6f88b75ce6318"
desired_count      = 2
aws_region         = "eu-west-1"


Step 1: Go into your module/project folder

If you are working in the ecs module, navigate into it:

cd ~/Terraform_ecs/ecs


(or wherever you placed your Terraform main.tf file)

 Step 2: Format Terraform files

This will auto-format all .tf files:

terraform fmt

 Step 3: Initialize Terraform

This downloads providers and sets up the backend:

terraform init

Step 4: Validate Terraform code

(Optional but recommended, checks for syntax errors)

terraform validate

Step 5: Create an execution plan

This shows what Terraform will create/modify:

terraform plan


If you want to save the plan:

terraform plan -out=tfplan
Step 6: Apply the changes

To actually create the resources:

terraform apply

============================================================================
Inside your Terraform_ecs project, create a role folder:

Terraform_ecs/
 └── role/
     ├── main.tf
     ├── variables.tf
     ├── terraform.tfvars

📄 Files Content
role/main.tf
# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.name}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

# Trust Policy for ECS
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Attach ECS Execution Policy
resource "aws_iam_role_policy_attachment" "exec_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Output for ECS Module
output "ecs_execution_role_arn" {
  description = "ARN of the ECS Execution Role"
  value       = aws_iam_role.ecs_task_execution.arn
}

role/variables.tf
variable "name" {
  description = "Base name for ECS resources"
  type        = string
}

role/terraform.tfvars
name = "my-ecs-demo"

Execution Steps

Now go into the role/ folder:

cd ~/Terraform_ecs/role


Run the Terraform commands step by step:

Format Terraform files
terraform fmt

Initialize provider plugins
terraform init

Validate syntax
terraform validate

Create a plan
terraform plan 

Apply the plan (creates IAM role)
terraform apply 


==============================================================================

