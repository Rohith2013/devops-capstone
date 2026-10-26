# DevOps Capstone Project

End-to-end CI/CD pipeline for a Node.js web application. A push to GitHub triggers Jenkins (running on AWS EC2), which installs dependencies, builds a Docker image, pushes it to Docker Hub and deploys the container to an application EC2 server over SSH. Prometheus and Grafana monitor the server and the containers, and cron jobs automate backups and cleanup.

## Tech Stack

| Layer | Tools |
|---|---|
| Source Control | Git + GitHub |
| CI/CD | Jenkins on AWS EC2 |
| App | Node.js (Express) web app, single container |
| Containerization | Docker + Docker Hub |
| Infrastructure | AWS EC2 (Ubuntu), VPC, Internet Gateway, Security Group |
| Monitoring | Prometheus, Grafana, Node Exporter, cAdvisor |
| Scripting & Jobs | Bash + Cron |

## Architecture

```
Developer -> GitHub -> Jenkins (EC2) -> Docker Hub -> App EC2 (Docker container)
                                                          |
                                        Node Exporter + cAdvisor
                                                          |
                                                 Prometheus -> Grafana
                                      cron -> backup.sh / cleanup_logs.sh
```

## Repository Layout

```
.
├── app/                    # Node.js source (server.js, package.json)
├── Dockerfile
├── Jenkinsfile
├── monitoring/             # Prometheus + Grafana + cAdvisor (docker compose)
│   ├── docker-compose.yml
│   └── prometheus.yml
└── scripts/                # Bash automation
    ├── backup.sh
    ├── cleanup_logs.sh
    └── crontab.txt
```

## Run Locally

```bash
# Without Docker
cd app
npm install
npm start                      # http://localhost:3000

# With Docker
docker build -t devops-capstone-app .
docker run -d --name capstone-app -p 3000:3000 devops-capstone-app
curl http://localhost:3000/health
```

Endpoints: `/` (home page) and `/health` (health check, returns `{"status":"ok"}`).

## AWS Setup

1. Create a key pair (`capstone-key`, `.pem`) and keep it out of Git (`*.pem` is in `.gitignore`).
2. Make sure the VPC has an Internet Gateway attached and a route `0.0.0.0/0 -> igw` in its route table.
3. Create a security group with inbound rules:

   | Port | Purpose | Source |
   |---|---|---|
   | 22 | SSH | Your IP, and the security group itself (Jenkins to app server) |
   | 8080 | Jenkins | Your IP |
   | 80 | Application | Your IP |
   | 3001 | Grafana | Your IP |
   | 9090 | Prometheus | Your IP |

4. Launch two Ubuntu EC2 instances using that security group:
   - `jenkins-server` (t3.small)
   - `app-server` (t3.micro)

The application server is reached from Jenkins through its **private IP**, so no public IP is stored in the repository.

## Jenkins Server Setup

```bash
sudo apt update
sudo apt install -y docker.io openjdk-21-jre nodejs npm fontconfig
sudo systemctl enable --now docker

# Jenkins repository (current signing key)
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt update
sudo apt install -y jenkins

sudo usermod -aG docker jenkins
sudo systemctl enable --now jenkins
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Notes:
- Jenkins requires Java 21 or newer.
- On small instances Jenkins may mark the built-in node offline when free temp space is below 1 GiB. Lower the **Free Temp Space** threshold under *Manage Jenkins -> Nodes -> Configure Monitors*.

### Jenkins configuration

1. Install suggested plugins, then add the **SSH Agent** plugin.
2. Add credentials (*Manage Jenkins -> Credentials*):
   - `dockerhub-creds`: Docker Hub username + access token
   - `app-ec2-ssh`: SSH private key for user `ubuntu` on the app server
3. Create a **Pipeline** job:
   - Definition: *Pipeline script from SCM*
   - SCM: Git, repository URL of this repo, branch `*/main`
   - Script path: `Jenkinsfile`
   - Build trigger: **Poll SCM** with schedule `* * * * *`

## App Server Setup

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 git prometheus-node-exporter
sudo systemctl enable --now docker prometheus-node-exporter
sudo usermod -aG docker ubuntu

git clone <this-repository-url>
cd devops-capstone/monitoring
docker compose up -d
```

Open Prometheus on port `9090` and Grafana on port `3001`. In Grafana add a Prometheus data source with URL `http://prometheus:9090` and import dashboard ID `1860` (Node Exporter Full).

A 1 GB swap file is recommended on a t3.micro:

```bash
sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
```

## CI/CD Flow

1. Developer pushes code to GitHub.
2. Jenkins detects the change (Poll SCM) and starts the pipeline.
3. Stages: **Checkout -> Install Dependencies -> Build Docker Image -> Push to Docker Hub -> Deploy to App Server -> Verify Deployment**.
4. The app server pulls the new image, replaces the running container and the pipeline checks `/health`.
5. Prometheus scrapes Node Exporter (host metrics) and cAdvisor (container metrics); Grafana visualises them.
6. Cron runs `backup.sh` daily and `cleanup_logs.sh` weekly.

## Automation (cron)

```bash
chmod +x scripts/*.sh
crontab scripts/crontab.txt
crontab -l
```

| Schedule | Script | What it does |
|---|---|---|
| Daily 02:00 (server time, UTC) | `backup.sh` | Archives container logs and monitoring config to `~/backups`, keeps 7 days |
| Sunday 03:00 (server time, UTC) | `cleanup_logs.sh` | Deletes old backups, prunes stopped containers and dangling images |

## Access

- Application: `http://<app-server-ip>/`
- Jenkins: `http://<jenkins-server-ip>:8080`
- Prometheus: `http://<app-server-ip>:9090`
- Grafana: `http://<app-server-ip>:3001`

IP addresses are intentionally not published in this repository.
