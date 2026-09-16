// Jenkinsfile — CI for a FastAPI app
// Flow: checkout -> venv/deps -> lint -> test -> build image -> push to ECR
//
// This is CI only. Deployment to Kubernetes is handled separately by ArgoCD
// (GitOps, pull-based) once that's set up -- this pipeline's job ends at ECR.
//
// Required Jenkins setup:
//   - Agent with: python3, docker, aws-cli v2
//   - Credentials:
//       'aws-ecr-creds' -> AWS Access Key ID / Secret (Username/Password credential type)
//   - Jenkins Pipeline plugins: Docker Pipeline

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        AWS_REGION       = 'ap-south-1'                                    // <-- change
        AWS_ACCOUNT_ID   = '859925121963'                                 // <-- change
        ECR_REPO         = 'fast-api'                                  // <-- change
        ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG        = "${env.BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        IMAGE_URI        = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python venv') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                    pip install pytest pytest-cov ruff httpx2
                '''
            }
        }

        stage('Lint') {
            steps {
                sh '''
                    . .venv/bin/activate
                    ruff check .
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    . .venv/bin/activate
                    pytest --cov=. --cov-report=xml --cov-report=term -v
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/junit*.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_URI} -t ${ECR_REGISTRY}/${ECR_REPO}:latest ."
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-ecr-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        aws ecr get-login-password --region ${AWS_REGION} \
                            | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        docker push ${IMAGE_URI}
                        docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
                    '''
                }
            }
        }

        // No deploy stage here on purpose.
        // Deployment to Kubernetes will be handled by ArgoCD (GitOps pull-based),
        // watching a manifests repo. When that's set up, add a stage here that
        // bumps the image tag in the manifests repo and pushes that commit --
        // NOT a direct kubectl/kubeconfig step.
    }

    post {
        success {
            echo "Built and pushed ${IMAGE_URI} to ECR successfully."
        }
        failure {
            echo "Pipeline failed at stage: ${env.STAGE_NAME}"
            // Hook up Slack/email notification here, e.g.:
            // slackSend(color: 'danger', message: "Build ${env.BUILD_NUMBER} failed: ${env.BUILD_URL}")
        }
        always {
            sh 'docker image prune -f || true'
            cleanWs()
        }
    }
}
