pipeline {

    agent any

    environment {
        AWS_REGION     = 'us-east-1'
        AWS_ACCOUNT_ID = '859925121963'
        ECR_REPOSITORY = 'fast-api'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        IMAGE_TAG    = "${BUILD_NUMBER}"
        IMAGE_NAME   = "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
        LATEST_IMAGE = "${ECR_REGISTRY}/${ECR_REPOSITORY}:latest"

        CONTAINER_NAME = 'seclock'
        APP_PORT       = '8000'
    }

    stages {

        stage('Environment Check') {
            steps {
                sh '''
                    set -eu

                    echo "===== Environment Check ====="

                    python3 --version
                    docker --version
                    aws --version
                    git --version

                    echo ""
                    echo "Workspace:"
                    pwd

                    echo ""
                    echo "Repository files:"
                    ls -la
                '''
            }
        }

        stage('Python Setup') {
            steps {
                sh '''
                    set -eu

                    echo "===== Python Setup ====="

                    rm -rf venv

                    python3 -m venv venv

                    . venv/bin/activate

                    python -m pip install --upgrade pip

                    python -m pip install -r requirements.txt

                    python -m pip install \
                        pytest \
                        bandit \
                        httpx2

                    echo "Python setup completed."
                '''
            }
        }

        stage('Application Import Check') {
            steps {
                sh '''
                    set -eu

                    . venv/bin/activate

                    echo "===== FastAPI Import Check ====="

                    python -c "from main import app; print('FastAPI application imported successfully')"
                '''
            }
        }

        stage('E2E Tests') {
            steps {
                sh '''
                    set -eu

                    . venv/bin/activate

                    echo "========================================"
                    echo "Running SEclock E2E Tests"
                    echo "========================================"

                    python test_e2e.py

                    echo ""
                    echo "ALL SEclock E2E TESTS PASSED."
                '''
            }
        }

        stage('Security Scan') {
            steps {
                sh '''
                    set -eu

                    . venv/bin/activate

                    echo "===== Bandit Security Scan ====="

                    bandit \
                        -r main.py \
                        crypto_engine.py \
                        ocr_engine.py \
                        audit_ledger.py \
                        -f txt \
                        --skip B105

                    echo ""
                    echo "Security scan completed successfully."
                '''
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    set -eu

                    echo "===== Docker Build ====="

                    docker build \
                        --pull \
                        -t "${IMAGE_NAME}" \
                        -t "${LATEST_IMAGE}" \
                        .

                    echo ""
                    echo "Docker image built successfully."

                    docker images "${ECR_REGISTRY}/${ECR_REPOSITORY}"
                '''
            }
        }

        stage('Docker Smoke Test') {
            steps {
                sh '''
                    set -eu

                    echo "===== Docker Smoke Test ====="

                    TEST_CONTAINER="seclock-smoke-test"

                    docker rm -f "${TEST_CONTAINER}" 2>/dev/null || true

                    docker run -d \
                        --name "${TEST_CONTAINER}" \
                        -p 18000:8000 \
                        "${IMAGE_NAME}"

                    SUCCESS=0

                    for i in $(seq 1 30); do

                        if curl -fsS \
                            --max-time 3 \
                            "http://127.0.0.1:18000/" \
                            > /dev/null 2>&1; then

                            SUCCESS=1

                            echo "Docker container is responding."

                            break
                        fi

                        echo "Waiting... ${i}/30"

                        sleep 2
                    done

                    if [ "${SUCCESS}" -ne 1 ]; then

                        echo "ERROR: Docker container failed."

                        docker ps -a \
                            --filter "name=${TEST_CONTAINER}"

                        echo ""
                        echo "Container logs:"

                        docker logs "${TEST_CONTAINER}" || true

                        docker rm -f "${TEST_CONTAINER}" || true

                        exit 1
                    fi

                    echo "Docker smoke test PASSED."

                    docker logs "${TEST_CONTAINER}" || true

                    docker rm -f "${TEST_CONTAINER}" || true
                '''
            }
        }

        stage('AWS Check') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-root']
                ]) {
                    sh '''
                        set -eu

                        echo "===== AWS Authentication ====="

                        aws sts get-caller-identity

                        echo ""
                        echo "Checking ECR repository..."

                        aws ecr describe-repositories \
                            --repository-names "${ECR_REPOSITORY}" \
                            --region "${AWS_REGION}" \
                            > /dev/null

                        echo ""
                        echo "ECR repository exists."
                    '''
                }
            }
        }

        stage('Login to ECR') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-root']
                ]) {
                    sh '''
                        set -eu

                        echo "===== Amazon ECR Login ====="

                        aws ecr get-login-password \
                            --region "${AWS_REGION}" | \
                        docker login \
                            --username AWS \
                            --password-stdin "${ECR_REGISTRY}"

                        echo ""
                        echo "ECR login successful."
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-root']
                ]) {
                    sh '''
                        set -eu

                        echo "===== Push Images to ECR ====="

                        echo "Pushing:"
                        echo "${IMAGE_NAME}"

                        docker push "${IMAGE_NAME}"

                        echo ""
                        echo "Pushing:"
                        echo "${LATEST_IMAGE}"

                        docker push "${LATEST_IMAGE}"

                        echo ""
                        echo "Images pushed successfully."
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                sh '''
                    set -eu

                    echo "===== Deploying SEclock ====="

                    docker pull "${LATEST_IMAGE}"

                    docker stop "${CONTAINER_NAME}" 2>/dev/null || true

                    docker rm "${CONTAINER_NAME}" 2>/dev/null || true

                    docker run -d \
                        --name "${CONTAINER_NAME}" \
                        --restart unless-stopped \
                        -p "${APP_PORT}:${APP_PORT}" \
                        "${LATEST_IMAGE}"

                    echo ""
                    echo "Container started."

                    docker ps \
                        --filter "name=${CONTAINER_NAME}" \
                        --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -eu

                    echo "===== Deployment Verification ====="

                    SUCCESS=0

                    for i in $(seq 1 30); do

                        if curl -fsS \
                            --max-time 5 \
                            "http://127.0.0.1:${APP_PORT}/" \
                            > /dev/null 2>&1; then

                            SUCCESS=1

                            echo ""
                            echo "SEclock application is responding."

                            break
                        fi

                        echo "Waiting... ${i}/30"

                        sleep 2
                    done

                    if [ "${SUCCESS}" -ne 1 ]; then

                        echo ""
                        echo "ERROR: Deployment verification failed."

                        echo ""
                        echo "Container status:"

                        docker ps -a \
                            --filter "name=${CONTAINER_NAME}"

                        echo ""
                        echo "Application logs:"

                        docker logs "${CONTAINER_NAME}" || true

                        exit 1
                    fi

                    echo ""
                    echo "========================================"
                    echo "SEclock DEPLOYMENT SUCCESSFUL"
                    echo "========================================"
                    echo ""
                    echo "Application:"
                    echo "http://EC2_PUBLIC_IP:${APP_PORT}"
                    echo ""
                    echo "Port: ${APP_PORT}"
                    echo "========================================"
                '''
            }
        }
    }

    post {

        success {
            echo '''
========================================
       SECLOCK CI/CD SUCCESS
========================================

E2E Tests       : PASSED
Security Scan   : PASSED
Docker Build    : PASSED
Docker Test     : PASSED
AWS Check       : PASSED
ECR Login       : PASSED
ECR Push        : PASSED
EC2 Deployment  : PASSED
Verification    : PASSED

Application Port: 8000

========================================
            '''
        }

        failure {
            sh '''
                echo "========================================"
                echo "SECLOCK PIPELINE FAILED"
                echo "========================================"

                echo ""
                echo "Container status:"

                docker ps -a \
                    --filter "name=seclock" || true

                echo ""
                echo "SEclock logs:"

                docker logs seclock 2>/dev/null || true

                echo ""
                echo "========================================"
            '''
        }

        always {
            sh '''
                docker rm -f seclock-smoke-test 2>/dev/null || true
                docker image prune -f || true
            '''
        }
    }
}
