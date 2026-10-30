pipeline {
    agent any

    environment {
        DOCKERHUB_CREDS = credentials('dockerhub-creds')
        IMAGE_NAME      = 'rohithemc/devops-capstone-app'
        IMAGE_TAG       = "${env.BUILD_NUMBER}"
        APP_SERVER      = 'ubuntu@172.31.6.39'
        CONTAINER_NAME  = 'capstone-app'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                dir('app') {
                    sh 'npm install'
                }
            }
        }

        stage('Test') {
            steps {
                sh 'docker run --rm -v "$WORKSPACE/app":/usr/src/app -w /usr/src/app -u "$(id -u):$(id -g)" -e HOME=/tmp node:20-alpine npm test'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh 'echo "${DOCKERHUB_CREDS_PSW}" | docker login -u "${DOCKERHUB_CREDS_USR}" --password-stdin'
                sh 'docker push ${IMAGE_NAME}:${IMAGE_TAG}'
                sh 'docker push ${IMAGE_NAME}:latest'
            }
        }

        stage('Deploy to App Server') {
            steps {
                sshagent(credentials: ['app-ec2-ssh']) {
                    sh 'ssh -o StrictHostKeyChecking=no ${APP_SERVER} "docker pull ${IMAGE_NAME}:${IMAGE_TAG} && (docker rm -f ${CONTAINER_NAME} || true) && docker run -d --name ${CONTAINER_NAME} --restart unless-stopped -p 80:3000 ${IMAGE_NAME}:${IMAGE_TAG}"'
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sshagent(credentials: ['app-ec2-ssh']) {
                    sh 'sleep 5 && ssh -o StrictHostKeyChecking=no ${APP_SERVER} "curl -fsS http://localhost/health"'
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo 'Deployed successfully'
        }
        failure {
            echo 'Pipeline failed, check console output'
        }
    }
}
