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


