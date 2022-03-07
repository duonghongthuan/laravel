pipeline {
    agent any
    environment {
        DOCKER_TAG="${GIT_BRANCH.tokenize('/').pop()}-${GIT_COMMIT.substring(0,7)}"
        DOCKER_IMAGE="laravel-cicd"
        DOCKER_REGISTRY="registry.d2t.vn"
        DOCKER_USERNAME = credentials("docker-user")
        DOCKER_PASSWORD = credentials("docker-password")
    }
    stages {
        stage("Build") {
            environment {
                DB_HOST = credentials("laravel-host")
                DB_DATABASE = credentials("laravel-database")
                DB_USERNAME = credentials("laravel-user")
                DB_PASSWORD = credentials("laravel-password")
            }
            steps {
                sh 'php --version'
                sh 'rm -rf composer.lock'
                sh 'composer install --no-cache'
                sh 'composer --version'
                sh 'cp .env.example .env'
                sh 'echo DB_HOST=${DB_HOST} >> .env'
                sh 'echo DB_USERNAME=${DB_USERNAME} >> .env'
                sh 'echo DB_DATABASE=${DB_DATABASE} >> .env'
                sh 'echo DB_PASSWORD=${DB_PASSWORD} >> .env'
                sh 'php artisan key:generate'
                sh 'cp .env .env.testing'
                sh 'php artisan migrate'
            }
        }

        stage("Unit test") {
            steps {
                sh 'php artisan test'
            }
        }

        stage("Code coverage") {
            steps {
                sh "vendor/bin/phpunit --coverage-html 'reports/coverage'"
            }
        }

        stage('SonarQube analysis') {
            environment {
                SCANNER_HOME = tool 'sonarqube-scanner'
            }
            steps {
                withSonarQubeEnv(credentialsId: 'sonarqube_access_token', installationName: 'sonarqube-container') {
                    sh '''$SCANNER_HOME/bin/sonar-scanner \
                    -Dsonar.projectKey=laravel-cicd \
                    -Dsonar.projectName=laravel-cicd \
                    -Dsonar.sources=platform/ \
                    -Dsonar.language=php \
                    -Dsonar.exclusions=app/Providers/** \
                    -Dsonar.projectVersion=${BUILD_NUMBER}-${GIT_COMMIT_SHORT}'''
                }
            }
        }

        stage("Docker build") {
            steps {
                sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
                sh "docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
                sh "docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
            }
        }

        stage("Docker push") {
            steps {
                sh "docker login --username ${DOCKER_USERNAME} --password ${DOCKER_PASSWORD} ${DOCKER_REGISTRY}"
                sh "docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
                sh "docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
                sh "docker image rm ${DOCKER_IMAGE}:${DOCKER_TAG}"
            }
        }

        stage("Deploy to staging") {
            steps{
                sshagent(['192.168.1.33']) {
                    sh "ssh -o StrictHostKeyChecking=no -l root 192.168.1.33 docker login --username ${DOCKER_USERNAME} --password ${DOCKER_PASSWORD} ${DOCKER_REGISTRY}"
                    sh 'ssh -o StrictHostKeyChecking=no -l root 192.168.1.33 docker rm -f laravel-cicd'
                    sh "ssh -o StrictHostKeyChecking=no -l root 192.168.1.33 docker run --rm -p 9999:80 --name ${DOCKER_IMAGE} -d ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
                }
            }
        }
    }
    post{
        success{
            echo "========pipeline executed successfully ========"
            mail bcc: '', body: 'Laravel CI/CD Build Success on http://192.168.1.33:9999', cc: '', from: '', replyTo: '', subject: 'Laravel CI/CD Build Success', to: 'thuandh@d2t.vn'
        }
    }
}