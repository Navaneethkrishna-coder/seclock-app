pipeline {
    agent any

    // ---------------------------------------------------------------------
    // Configure these to match your environment
    // ---------------------------------------------------------------------
    environment {
        AWS_ACCOUNT_ID   = '859925121963'                  // <-- your AWS account id
        AWS_REGION       = 'ap-south-1'                    // <-- your AWS region
        ECR_REPO_NAME    = 'fast-api'                   // <-- ECR repo name (create it beforehand)
        ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME       = "${ECR_REGISTRY}/${ECR_REPO_NAME}"
        IMAGE_TAG        = "${env.BUILD_NUMBER}"
        K8S_NAMESPACE    = 'default'
        K8S_DEPLOYMENT   = 'seclock-app'
        K8S_CONTAINER    = 'seclock-app'
        // Jenkins credential IDs (create these in Jenkins > Manage Credentials)
        AWS_CRED_ID      = 'AKIA4QN4IBOVUOJ3JJY7'                 // AWS Access Key/Secret with ECR push rights
        KUBECONFIG_CRED  = 'k8s-kubeconfig'                // "Secret file" credential holding kubeconfig
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Navaneethkrishna-coder/seclock-app.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
                """
            }
        }

        // Optional: run tests inside the built image before pushing.
        // Uncomment and adapt the entrypoint/command for your stack.
        /*
        stage('Test') {
            steps {
                sh "docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} <your-test-command>"
            }
        }
        */

        stage('Login to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: "${AWS_CRED_ID}"
                ]]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} \
                          | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    """
                }
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh """
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                """
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: "${KUBECONFIG_CRED}", variable: 'KUBECONFIG_FILE')]) {
                    sh """
                        export KUBECONFIG=\$KUBECONFIG_FILE

                        # Make sure namespace + base manifests exist (idempotent apply)
                        kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f k8s/service.yaml -n ${K8S_NAMESPACE}

                        # Point the deployment at the freshly built, immutable tag
                        kubectl set image deployment/${K8S_DEPLOYMENT} \
                          ${K8S_CONTAINER}=${IMAGE_NAME}:${IMAGE_TAG} \
                          -n ${K8S_NAMESPACE}

                        kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                          -n ${K8S_NAMESPACE} --timeout=180s
                    """
                }
            }
        }

        stage('Cleanup Local Images') {
            steps {
                sh """
                    docker rmi ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest || true
                """
            }
        }
    }

    post {
        success {
            echo "Deployed ${IMAGE_NAME}:${IMAGE_TAG} to ${K8S_DEPLOYMENT} successfully."
        }
        failure {
            echo "Pipeline failed. Check the stage logs above."
        }
        always {
            sh 'docker logout ${ECR_REGISTRY} || true'
        }
    }
}
