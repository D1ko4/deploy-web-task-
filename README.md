# Flask Web Application with CI/CD Deployment

**🚀 Live demo:** https://hello.d1ko4.com/

## 📋 Table of Contents

- [📖 About the Task](#about-the-task)
- [🐳 Step 1: Containerizing Flask Application](#step-1-containerizing-flask-application)
- [🔄 Step 2: Nginx Reverse Proxy](#step-2-nginx-reverse-proxy)
- [⚙️ Step 3: CI/CD Pipeline](#step-3-cicd-pipeline)
- [📊 Step 4: Monitoring & Logging](#step-4-monitoring--logging)
- [� Step 5: Zero-Downtime Deployment (Blue-Green)](#step-5-zero-downtime-deployment-blue-green)
- [�🖥️ Step 6: Proxmox Setup](#step-6-proxmox-setup)

## 📖 About the Task

This DevOps task demonstrates:

- 🐳 **Docker containerization**
- 🔄 **Nginx reverse proxy configuration**
- ⚙️ **CI/CD automation with GitHub Actions**
- 📊 **Basic monitoring and logging**
- 📚 **Documentation with reproducible steps**

## 🐳 Step 1: Containerizing Flask Application

A simple Flask web application was containerized using Docker.

**Project structure:**
```
├── app.py
├── requirements.txt
├── Dockerfile
└── docker-compose.yml
```

**Local development:**

Windows:
```bash
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python app.py
```

Linux:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

**Docker deployment:**
```bash
docker compose up -d --build
```

The application responds with "Hello, World!" at http://localhost:5000

## 🔄 Step 2: Nginx Reverse Proxy

Used Nginx Proxy Manager (NPM) for reverse proxy with web UI and SSL certificate management.

**Server setup:**
- Provider: [serverspace.kz](https://serverspace.kz)
- OS: Ubuntu 24.04 (x64)

**Installation:**
```bash
sudo apt update && sudo apt upgrade -y
```

**User setup for security:**
```bash
adduser devops
usermod -aG sudo devops
su - devops
```

**Docker Compose configuration:**
```yaml
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
```

**Running NPM:**
```bash
docker compose up -d
```

Access admin interface at: `http://<SERVER_IP>:81`

**Note:** If IPv6 is not enabled, add `DISABLE_IPV6=true` to the configuration.

## ⚙️ Step 3: CI/CD Pipeline

Automated deployment using GitHub Actions with self-hosted runner.

**Create runner user:**
```bash
sudo adduser d1ko4
sudo usermod -aG sudo d1ko4
sudo usermod -aG docker d1ko4
```

**Install GitHub Actions runner:**
```bash
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.328.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-linux-x64-2.328.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.328.0.tar.gz
./config.sh --url https://github.com/D1ko4/deploy-web-task- --token <TOKEN>
```

**Run as service:**
```bash
sudo ./svc.sh install
sudo ./svc.sh start
```

**DNS setup:**
- Created subdomain: `hello.d1ko4.com → 85.198.90.104` (A record)

**Docker network configuration:**
```bash
docker network create web || true
docker network connect web hello-flask || true
docker network connect web for_nginx-app-1 || true
```

**GitHub Actions workflow:**
```yaml
name: CI/CD Deploy
on:
  push:
    branches: [ "main" ]
jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - name: Checkout repo
        uses: actions/checkout@v3
      - name: Build and run with Docker Compose
        run: |
          docker compose down || true
          docker compose up -d --build
```

## 📊 Step 4: Monitoring & Logging

**Default logging:**
All containers output logs to stdout/stderr:
```bash
# Application logs
docker logs hello-flask

# Nginx Proxy Manager logs
docker logs for_nginx-app-1

# Via docker-compose
docker compose logs -f web
```

**Persistent logs:**
Logs are stored on the host system:
```yaml
services:
  web:
    volumes:
      - /home/d1ko4/logs/app:/app/logs
  npm:
    volumes:
      - /home/d1ko4/logs/nginx:/var/log/nginx
```

**Storage locations:**
- Flask logs: `/home/d1ko4/logs/app`
- Nginx logs: `/home/d1ko4/logs/nginx`

## � Step 5: Zero-Downtime Deployment (Blue-Green)

To avoid downtime during deploys, I implemented a Blue-Green deployment strategy.
Instead of replacing the running container, we keep two identical environments (blue and green), only one is active at a time.

**How it works:**

1. The active color (e.g., blue) serves traffic
2. CI builds a new image tagged with the commit SHA
3. The new image is deployed to the idle color (green)
4. A health-check confirms the idle container is working
5. Traffic is switched to the idle color (Nginx Proxy Manager always forwards to `hello-active`)
6. The old container remains available for rollback, but traffic no longer goes through it

This ensures that users never experience downtime during updates.

**Files overview:**

- `ACTIVE` – state file storing the current live color (blue or green)
- `docker-compose.bluegreen.yml` – defines both hello-blue and hello-green services
- `deploy_to_idle.sh` – builds and starts the idle color with the new image, then health-checks it
- `switch_to_idle_and_flip.sh` – switches the alias hello-active to point to the new color and updates ACTIVE
- CI/CD Workflow (`ci.yml`) – GitHub Actions job that automates building, deploying, and switching on every push to main

**CI/CD integration:**

The GitHub Actions workflow:
1. Builds a new Docker image tagged with the commit SHA
2. Deploys to the idle color (`deploy_to_idle.sh`)
3. Switches traffic by running `switch_to_idle_and_flip.sh`

## �🖥️ Step 6: Proxmox Setup

**Challenges encountered:**
- Proxmox installation requires bare metal or dedicated hardware
- Server lacked WAN connectivity in test environment
- Wi-Fi configuration was not feasible without initial internet access

**Future implementation plan:**
1. Set up Proxmox on hardware with proper LAN access
2. Create Ubuntu VMs with Docker
3. Deploy the Flask + Nginx + CI/CD pipeline inside Proxmox VMs

**Note:** This step was not completed due to hardware limitations but is planned for future implementation.