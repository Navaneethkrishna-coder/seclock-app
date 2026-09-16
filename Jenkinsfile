pipeline {

    agent any

    environment {
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '859925121963'

        ECR_REPOSITORY = 'fast-api'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        DOCKER_IMAGE = "${ECR_REGISTRY}/${ECR_REPOSITORY}"

        SONAR_PROJECT_KEY = 'seclock-app'
        SONAR_PROJECT_NAME = 'SECLOCK'
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        skipDefaultCheckout(true)
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                sh '''
                    echo "======================================"
                    echo "Checkout successful"
                    echo "======================================"

                    python3 --version

                    echo "Project files:"
                    ls -la
                '''
            }
        }

        stage('Python Setup') {
            steps {
                sh '''
                    set -e

                    echo "Installing Python dependencies..."

                    python3 -m pip install --upgrade pip

                    python3 -m pip install -r requirements.txt

                    python3 -m pip install pytest bandit
                '''
            }
        }

        stage('Build and Test') {
            steps {
                sh '''
                    set -e

                    echo "======================================"
                    echo "Running Tests"
                    echo "======================================"

                    if [ -f "test_e2e.py" ]; then
                        pytest -v test_e2e.py
                    elif [ -d "tests" ]; then
                        pytest -v
                    else
                        echo "No tests found"
                    fi
                '''
            }
        }

        stage('Security Scan - Bandit') {
            steps {
                sh '''
                    echo "======================================"
                    echo "Running Bandit"
                    echo "======================================"

                    bandit -r . \
                        --exclude ./venv \
                        -f json \
                        -o bandit-report.json || true

                    echo "Bandit scan completed"
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {

                    sh '''
                        echo "======================================"
                        echo "Running SonarQube"
                        echo "======================================"

                        sonar-scanner \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.projectName="${SONAR_PROJECT_NAME}" \
                            -Dsonar.sources=. \
                            -Dsonar.exclusions="__pycache__/**,sample_certificates/**,static/**"
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "======================================"
                    echo "Building Docker Image"
                    echo "======================================"

                    docker build \
                        -t ${DOCKER_IMAGE}:${BUILD_NUMBER} \
                        -t ${DOCKER_IMAGE}:latest \
                        .

                    docker images
                '''
            }
        }

        stage('Docker Image Scan') {
            steps {
                sh '''
                    echo "======================================"
                    echo "Running Trivy Scan"
                    echo "======================================"

                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        ${DOCKER_IMAGE}:${BUILD_NUMBER}

                    echo "Trivy scan completed"
                '''
            }
        }

        stage('Login to AWS ECR') {
            steps {
                sh '''
                    echo "======================================"
                    echo "Logging into AWS ECR"
                    echo "======================================"

                    aws ecr get-login-password \
                        --region ${AWS_REGION} | \
                    docker login \
                        --username AWS \
                        --password-stdin ${ECR_REGISTRY}

                    echo "ECR login successful"
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    echo "======================================"
                    echo "Pushing Image to ECR"
                    echo "======================================"

                    docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}

                    docker push ${DOCKER_IMAGE}:latest

                    echo "======================================"
                    echo "Image pushed successfully"
                    echo "======================================"

                    echo "${DOCKER_IMAGE}:${BUILD_NUMBER}"
                    echo "${DOCKER_IMAGE}:latest"
                '''
            }
        }

    }

    post {

        success {
            echo """
            ======================================
            SECLOCK CI PIPELINE SUCCESSFUL
            ======================================

            ECR Repository:
            ${ECR_REPOSITORY}

            Region:
            ${AWS_REGION}

            Image:
            ${DOCKER_IMAGE}:${BUILD_NUMBER}

            Latest:
            ${DOCKER_IMAGE}:latest

            ======================================
            """
        }

        failure {
            echo '''
            ======================================
            SECLOCK PIPELINE FAILED
            ======================================

            Check the failed stage above.

            ======================================
            '''
        }

        always {
            sh '''
                docker image prune -f || true
            '''

            cleanWs()
        }
    }
}
