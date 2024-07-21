pipeline {
    agent any
    environment {
        IMAGEPATH = "There is no such file"
        GRAFANA_URL = ""
        GRAFANA_STATUS = "Skipped due to earlier failure(s)"
    }
    stages {
        stage('Checkout') {
            steps {
                // Clone the Git repository
                git url: 'http://192.168.1.10:3000/rana/testRepo.git', credentialsId: 'token'
            }
        }
        stage('Install Apache') {
            steps {
                ansiblePlaybook(
                    credentialsId: 'ssh',
                    disableHostKeyChecking: true,
                    playbook: 'InstallApache.yml'
                )
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    // Build the Docker image
                    sh "docker build -t mynginx ."
                    // Save the Docker image to a tar file
                    sh "docker save mynginx -o mynginx.tar"
                    // Compress the tar file
                    sh "tar -czvf mynginx.tar.gz mynginx.tar"
                    IMAGEPATH = "${env.WORKSPACE}/mynginx.tar.gz"
            
                }
            }

        }
        
        stage('Setup Grafana') {
            steps {
                ansiblePlaybook(
                    credentialsId: 'ssh',
                    disableHostKeyChecking: true,
                    playbook: 'SetupGrafana.yml'
                )
            }
            post{
                success{
                    script{
                        GRAFANA_STATUS = currentBuild.result
                        GRAFANA_URL    = "http://192.168.1.14:3000"               
                    }
                }
     
            }


        }
    }
    post{
            always {
                script {
               def groupUsers = sshagent(['ssh']) {
                   sh(script: "ssh -o StrictHostKeyChecking=no ansible@192.168.1.11 'grep deployG /etc/group | cut -d: -f4'", returnStdout: true)
                    
            }
                    def pipelineStatus = currentBuild.result
                    def executionTime = new Date().format("yyyy-MM-dd HH:mm:ss")
                    
                    //Jenkins Pipeline Execution Status email
                    def emailBody = """
                       Pipeline Execution Status: ${pipelineStatus}
                       Date and Time of Execution: ${executionTime}
                       List of users in deployG group: ${groupUsers}
                       Path to Docker image.tar.gz: ${IMAGEPATH}
                    """

                    //send Jenkins Pipeline Execution Status email
                    sh """
                       echo "${emailBody}" | mail -s "Jenkins Pipeline Execution Status" ranatarawi3@gmail.com
                    """
                
                    //Grafana Setup Status email                    
                    emailBody = """
                        Grafana Setup Status: ${GRAFANA_STATUS}
                        Grafana URL: ${GRAFANA_URL}
                        """
                    // send Grafana Setup Status email
                    sh """
                        echo "${emailBody}" | mail -s "Jenkins Pipeline Grafana Setup Status" ranatarawi3@gmail.com
                       """
                }
            }
        }
}

