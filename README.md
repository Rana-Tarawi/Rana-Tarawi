# Project Overview
This project sets up a CI/CD pipeline using Jenkins to monitor a Gogs repository for changes, triggering automated deployments and Docker image builds. Ansible is used within the pipeline to automate the setup and configuration of services, ensuring consistency and reducing manual tasks.

Key components include:
- **VM Provisioning**: Four VMs for Jenkins, Gogs, Apache, and Grafana.
- **User Management**: Bash scripts for managing users on the Apache server.
- **Service Automation**: Ansible playbooks for installing and configuring Apache and Grafana.
- **Notifications**: Detailed status updates sent upon pipeline execution.
  
This setup ensures a streamlined and efficient deployment process.

## VM2 Gogs Server:
### Setup Gogs Server  
Installing GIT is necessary for the Gogs server to manage Git repositories.
```sh
sudo dnf install git
```
Creates a system user named git to run the Gogs service
```sh
sudo adduser --system  -s  /bin/bash -md /home/git git
```
Downloads and extracts the Gogs tarball. This is where the Gogs binaries and files will reside.
```sh
wget https://dl.gogs.io/0.13.0/gogs_0.13.0_linux_amd64.tar.gz -P /tmp
sudo tar xf /tmp/gogs_0.13.0_linux_amd64.tar.gz -C /home/git
```
 Change Ownership and Sett SELinux Context
```sh
sudo chown -R git: /home/git/gogs
sudo semanage fcontext -a -t bin_t /home/git/gogs/gogs
sudo restorecon -v /home/git/gogs/gogs
```
 Enable and Start Gogs
```sh
sudo systemctl enable --now gogs
sudo systemctl status gogs
```
Configure Firewall port for Gogs service
create the Gogs service XML configuration file in /etc/firewalld/services/gogs.xml then open this service on firewall
```xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Gogs</short>
  <description>Gogs Server for managing Git repositories</description>
  <port protocol="tcp" port="3000"/>
</service>
```
```sh
sudo firewall-cmd --permanent --add-service=gogs --zone=public
sudo firewall-cmd --reload
```
Installs SQLite, a lightweight database engine used by Gogs for storing data.
```sh
sudo yum install sqlite
```
Then Edit Gogs' configuration to set SQLite as its database type and /home/git/gogs/gogs.db as its path to database file.


## VM3
### 1. User Management:
Bash script to create three users named Devo, Testo, and Prodo on VM3, and add them to a group named "deployG" for centralized access control.
```bash
## Function check for value is an integer (only one digit)
function isINT {
        local VAL="${1}"
        local MSG="${2}"
        local EXITCODE="${3}"
        RES=$(echo "${VAL}" | grep -cE '^[0-9]$')
        [ ${RES} -ne 1 ] && echo "${MSG}" && exit ${EXITCODE}
}

# Exit codes
# 0 : success
# 1 : Failed to create from specific user caused the error to the end of the list  due to errors with adduser command
# 2 : exceeds number of users to be created per script which is 9 users



###if you want to get number of users to be created uncomment these 3 lines and comment the 4th line
#echo -n  "Enter number of users to be created: "
#read NUM
#isINT $NUM "you have exceeded the limit which is 9 users" 2

NUM=3

#getting group name ...
echo -n "Enter the group: "
read GRP
echo ""
[ -z "$(grep -q $GRP  /etc/group)" ] && sudo groupadd $GRP


for((i=0; i<NUM; i++));
do

# getting usernames and passwords ...
        echo -n "Enter a username: "
        read CURUSER
        echo ""
        echo -n "Enter a password: "
        read -s CURPASS
        echo ""
        HASHEDPASS=$(sudo openssl passwd -6 "${CURPASS}")

# creating users ...
        sudo adduser -s /bin/bash -p ${HASHEDPASS}  -md /home/${CURUSER} ${CURUSER}
        if [ $? -ne 0 ]; then
                echo "ERROR in creating users from $CURUSER that caused the error to the end of the list  which explained above" && exit 1
        fi

#adding users to the group ...
        sudo usermod -aG $GRP $CURUSER

done

echo "All users are created and added to the group successfully"

exit 0
```
Prepare text File with inputs to Run Script:
```sh
sudo bash createUsers-Group.sh < inputs
```
user deletion script to remove a user based on the username provided as an argument.
```bash
#!/bin/bash

## Function check for value is an integer (only one digit)
function isINT {
        local VAL="${1}"
        local MSG="${2}"
        local EXITCODE="${3}"
        RES=$(echo "${VAL}" | grep -cE '^[0-9]$')
        [ ${RES} -ne 1 ] && echo "${MSG}" && exit ${EXITCODE}
}

# Exit codes
# 0 : success
# 1 : Failed to delete users from specific user caused the error to the end of the list due to errors with userdel command
# 2 : exceeds number of users to be deleted per script which is 9 users


#getting number of users to be deleted
echo -n  "Enter number of users to be deleted: "
read NUM
isINT $NUM "you have exceeded the limit which is 9 users" 2

for((i=0; i<NUM; i++));
do

# getting usernames ...
        echo -n "Enter a username: "
        read CURUSER
        echo ""

#deleting user ...
        sudo userdel -r $CURUSER
        if [ $? -ne 0 ]; then
                echo "ERROR in deleting users from ${CURUSER} to the end of the list which explained above" && exit 1
        fi
done

echo "All users are deleted successfully"

exit 0
```
Prepare text File with inputs to Run Script:
```sh
sudo bash deleteUsers.sh < deletingInputs
```
Bash script to retrieve a list of users not inside the "deployG" group.
```bash
#!/bin/bash

GRPNAME=deployG

#if you want to get group name as an input uncomment these three lines
#echo 'Enter group name: '
#read GRPNAME
#echo ''

USERSIN=$(grep $GRPNAME /etc/group | cut -d: -f4 | sed 's/,/|/g')
#echo $USERSIN
grep -vE $USERSIN /etc/passwd | cut -d: -f1

exit 0
```
### 2. Ansible playbook to setup Apache on this worker:
The tasks of this playbook are to install Apache Web Server and ensure the service is up and running.
```yaml
- hosts: webserver
  tasks:
    - name: Install apache
      yum:
        name: httpd
        state: present
    - name: start apache
      service:
        name: httpd
        state: started
        enabled: yes
    - name: Open apache port and reload firewalld
      ansible.posix.firewalld:
        port: 80/tcp
        permanent: yes
        state: enabled
        immediate: yes
```
## VM4
###  Ansible playbook to setup Grafana on this worker:
The tasks of this playbook are: add Grafana Repository, install it, then enable and start it.
Open Grafana Port and reload the firewall.
Wait for Grafana to start and ensure that it's responding before resetting the admin Password using Grafana-cli if it's still the default password.
```yaml
---
- name: Install and configure Grafana
  hosts: grafana
  tasks:
    - name: Add Grafana repository
      yum_repository:
        name: grafana
        description: Grafana repository
        baseurl: https://packages.grafana.com/oss/rpm
        gpgcheck: yes
        gpgkey: https://packages.grafana.com/gpg.key
    - name: Install Grafana
      yum:
        name: grafana
        state: present
    - name: Start and enable Grafana service
      service:
        name: grafana-server
        state: started
        enabled: yes
    - name: Open Grafana port and reload firewalld
      ansible.posix.firewalld:
        port: 3000/tcp
        permanent: yes
        state: enabled
        immediate: yes
    - name: Wait for Grafana to start
      wait_for:
        port: 3000
        state: started
        timeout: 60
    - name: Verify Grafana is responding
      uri:
        url: http://localhost:3000/api/health
        method: GET
        status_code: 200
      register: grafana_health
    - name: Debug Grafana health check
      debug:
        var: grafana_health
    - name: Check current Grafana admin password
      uri:
        url: http://localhost:3000/login
        method: POST
        body: '{"user":"admin", "password":"rana"}'
        headers:
          Content-Type: "application/json"
        status_code: 200
      register: login
      ignore_errors: yes
    - name: Reset admin password using grafana-cli
      command: grafana-cli admin reset-admin-password rana
      args:
        chdir: /usr/share/grafana
      when: login.status != 200
```
## vm1
### 1. Setup jenkins
Start by adding the Jenkins repository and installing dependencies.
Install Jenkins, then start and enable it. 
Finally, allow access to Jenkins through the firewall and create a new service XML configuration file in /etc/firewalld/services/Jenkins.xml, then open this service on the firewall.
```sh
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat/jenkins.io-2023.key

sudo yum install fontconfig java-17-openjdk
sudo yum install jenkins

sudo systemctl enable --now Jenkins
sudo systemctl status jenkins
```
```xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Jenkins ports</short>
  <description>Jenkins port exceptions</description>
  <port protocol="tcp" port="8080"/>
</service>
```
``` sh
sudo firewall-cmd --permanent --add-service=jenkins --zone=public
sudo firewall-cmd –reload
```

### Setup E-mail Server:
Install the Postfix mail transfer agent and s-nail for sending mail
```sh
sudo dnf install postfix
sudo dnf install s-nail-14.9.22-6.el9.x86_64
```
Create application password
Open the Postfix SASL password file in /etc/postfix/sasl_passwd and add your Gmail credentials 
```plaintext
[smtp.gmail.com]:587    your_email@gmail.com:application password
```
Create a hashed version of the password file then Set File Permissions
```sh
sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
```
modify the Postfix configuration file in /etc/postfix/main.cf Configure SASL, set Gmail as the SMTP relay host and enable TLS
```plaintext
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_sasl_tls_security_options = noanonymous
smtp_use_tls = yes
smtp_tls_security_level = encrypt
relayhost = [smtp.gmail.com]:587
```
Enable and start the Postfix service to apply the new configuration
```sh
sudo systemctl enable --now postfix
```

### Setup asnible and docker:
#### steps to setup Ansible
Install ansible-core and ansible.posix. 
Create ansible user on master and workers to ssh to workers and run ansible playbooks.
Allow ansible user to ssh to workers using key-based authentication.
Edit the inventory file /etc/ansible/hosts to include the workers, then edit /etc/ansible/ansible.cfg with the path of the inventory.
Allow ansible user to run sudo commands on workers without being prompt to enter passwords using /etc/sudoers on workers and /etc/ansible/ansible.cfg on master.
#### steps to setup Docker
Add a Docker repository.
Install Docker along with the Docker CLI and container, then start and enable it. 
Add the Jenkins user to the Docker group to ensure that Jenkins has the necessary permissions to manage Docker containers.
##### Create Dockerfile to set up an Nginx server to serve a custom HTML page:
```dockerfile
# Use a proper Nginx image
FROM nginx:latest

# Copy HTML file to Nginx
COPY index.html /usr/share/nginx/html/index.html

# Run Nginx
ENTRYPOINT nginx -g "daemon off;"
```
## Jenkins Pipeline configuration:
### Pipeline:
```groovy
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
```
### Steps for setting up a pipeline trigger:
configure pipeline on jenkins to be trigerred when a change is pushed to the Gogs option in the Build Triggers section.
configure webhook to be triggered with push event on Gogs repo settings with payload url: <free static public domain>/gogs-webhook/?job=rana-tarawi-project as shown in the screenshots.

![Screenshot (1122)](https://github.com/user-attachments/assets/a3f6a49d-681e-49d5-89d2-0c74cbf1c967)

![Screenshot (1123)](https://github.com/user-attachments/assets/6df219df-c9ca-4edb-90cd-09bd8e0e8580)

#### Steps to generate a free static public domain for jenkins server\
Download and Install ngrok
```sh
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar -xvzf ngrok-v3-stable-linux-amd64.tgz
sudo mv ngrok /usr/local/bin
```
Add your ngrok authentication token
```sh
ngrok config add-authtoken <YOUR_AUTH_TOKEN>
```
Claim a free static domain on the ngrok website for use
Launch ngrok with your chosen domain to tunnel traffic from the public URL to jenkins local server's port (8080).Finally, retrieve the public URL.
```sh
ngrok http 8080 --domain=precious-vigorously-sponge.ngrok-free.app --log=stdout > /dev/null &
curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'
```
### steps for setting up email notification:
The screenshot shows the required configuration in the E-mail Notification section in Dashboard -> Manage Jenkins -> System. 
It uses the email server, which was previously setup on the same machine that hosts the Jenkins server. 
The email server listens to port 25 and forwards the outgoing emails to the gmail server (relayhost).

![Screenshot (1126)](https://github.com/user-attachments/assets/228215d6-9781-414a-b7a6-dea49aa23281)

### Additional required configurations:
Install the necessary plugins, such as the Gogs, Git, Ansible, SSH Agent, and so on.
Token for repository access should be generated on the Gogs server to be utilized in the pipeline.
ON Jenkins: ADD credentials ,required to be utilized in the pipeline: 1. When using Ansible, provide your username and private key to establish a secure connection.
2. generated token on Gogs for the access repository.

# Results:
## Trigger pipeline upon push event on Gogs repo

![Screenshot (1127)](https://github.com/user-attachments/assets/8da45f77-9b3a-4bdb-8f7a-fbe3f54fbf03)


![Screenshot (1128)](https://github.com/user-attachments/assets/835231d9-1348-43ef-9ce4-65dd61836294)

## Part of the pipeline execution

![Screenshot (1129)](https://github.com/user-attachments/assets/e0b44d03-6cc8-4464-a11e-f8840b12c9b9)


![Screenshot (1130)](https://github.com/user-attachments/assets/71fb5851-9488-4548-a4e7-23ede3976278)


![Screenshot (1133)](https://github.com/user-attachments/assets/a3052f23-143d-4b83-84ce-e8752826b4df)

## E-mail notifications

![Screenshot (1131)](https://github.com/user-attachments/assets/b219b559-85ba-4632-8f95-b6217e9e8bc8)


![Screenshot (1132)](https://github.com/user-attachments/assets/2c5c0745-f213-44f6-bb8b-f492c119dd14)


