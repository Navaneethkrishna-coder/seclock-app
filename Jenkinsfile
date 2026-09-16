pipeline {

    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    environment {
        AWS_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID = '13.233.122.108'

        ECR_REPOSITORY = 'seclock'
        IMAGE_TAG = "${BUILD_NUMBER}"

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Python Setup') {
            steps {
                sh '''
                    set -e

                    echo "Python:"
                    python3 --version

                    echo "Pip:"
                    python3 -m pip --version

                    echo "Creating virtual environment..."
 i                   python3 -m venv venv

                    . venv/bin/activate

                    python -m pip install --upgrade pip
                    python -m pip install -r requirements.txt

                    echo "Installing security/testing tools..."
                    python -m pip install pytest bandit
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                sh '''
                    set -e

                    . venv/bin/activate

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
                    . venv/bin/activate

                    bandit -r . \
                        --exclude ./venv \
                        -f json \
                        -o bandit-report.json || true

                    echo "Bandit scan completed"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                        -t ${IMAGE_NAME} \
                        -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest \
                        .
                '''
            }
        }

        stage('Docker Image Scan - Trivy') {
            steps {
                sh '''
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        ${IMAGE_NAME}
                '''
            }
        }

        stage('Login to AWS ECR') {
            steps {
                sh '''
                    aws ecr get-login-password \
                        --region ${AWS_REGION} | \
                    docker login \
                        --username AWS \
                        --password-stdin ${ECR_REGISTRY}
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    docker push ${IMAGE_NAME}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                '''
            }
        }

        stage('Update Kubernetes Manifest') {
            steps {
                sh '''
                    echo "======================================"
                    echo "Image pushed successfully"
                    echo "Image: ${IMAGE_NAME}"
                    echo "======================================"

                    echo "GitOps deployment will be configured later."
                '''
            }
        }
    }

    post {

        success {
            echo "======================================"
            echo "SECLOCK CI/CD PIPELINE SUCCESSFUL"
            echo "Image: ${IMAGE_NAME}"
            echo "======================================"
        }

        failure {
            echo "======================================"
            echo "SECLOCK CI/CD PIPELINE FAILED"
            echo "Check the failed stage above."
            echo "======================================"
        }

        always {
            sh '''
                docker image prune -f || true
            '''
        }
    }
}
