### Web Server information
This configuration will launch a web server that's hosting a web server application written in Python-Django with postrgreSQL database. **You can access it on port 8000**

### About included SSH Keys
Keys were added intentionally to ease setup for demo/test environment as well as quick connection via SSH.  
They're not used anywhere outside this project.

### Usage
This setup is intended for AWS free tier, some necessary changes will need to be made in order for it to work in regions other than the one defined in **main.tf** file, including AWS AMI string.
  
Be sure to follow prerequisites section of below documentation, you can skip installing AWS CLI:  
https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-build
