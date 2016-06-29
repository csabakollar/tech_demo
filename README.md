# Tech_demo
Short demo how to provision and deploy a small service with load balancing capabilities using Docker, nginx, Ansible, AWS and bash scripts on CentOS basis
from the network creation, VM provisioning, docker image creation via application deployment.

This demo's main purpose is to show how you can use bash scripts with ansible to interact with AWS and with Docker for application deployment

### Who is this solution meant for ###
- anyone who is working in the devops/sysops area

### Skills required ###
- basic understanding of AWS, Ansible and Docker
- bash scripting knowledge

### Tools you will need ###
- ansible and dynamic inventory
  Further info at:
  * http://docs.ansible.com/ansible/intro_dynamic_inventory.html
  * dynamic inv script: https://raw.github.com/ansible/ansible/devel/contrib/inventory/ec2.py
- bash (duhh...)
- awscli (to install it run: pip install awscli #python is required!)
- jq (just to show, you can interact with json files with bash. I know, I know... not the most elegant way to do it, but still... it's BASH :)

### Before you start ###
- modify the init.sh script, and update the KEYPAIR variable so it points to your AWS keypair. On AWS it's found under EC2 -> Key Pairs
- you must have the private key in your home dir under .ssh with the same name with pem extension as you specified at KEYPAIR.
  E.g.: if KEYPAIR=mykey (and it's the same name on AWS TOO), then place that private key to ~/.ssh/mykey.pem
- export AWS_ACCESS_KEY and AWS_SECRET_KEY environment variables in your shell so the script will be able to provision VMs in your name

### Docker images ###
You must decide whether you want to use your own container images or mine, if my prebuilt images are ok, skip this step (even if you are using mine, build the images without pushing to docker hub, to see how things work... also don't forget to check the 2 dockerfiles, they are cool!)
- if you choose to build it yourself:
```
docker build -t yourtag/app --rm docker/application
docker build -t yourtag/nginx --rm docker/nginx
```
To test it (linux || mac):
```
docker run -dh app -p 8484:8484 yourtag/app
docker run -dh nginx -p 80:80 yourtag/nginx
curl localhost:8484 || curl $(docker-machine ip yourmachinename):8484
curl localhost || curl $(docker-machine ip yourmachinename)
```
If it's working correctly, push it to your repo:
```
docker push yourtag/app
docker push yourtag/nginx
```
and modify the ansible/nginx.yml and ansible/application.yml files and rewrite the docker_image variable to your image name

### What's next ###
- run the init.sh script, which will create a VPC, 2 subnets, 1 route table and 2 security groups, then 3 VMs (2 for running the application and 1 for load balancing)
- after the provisioning, ansible will install docker-engine on the 3 new VMs and create the application container on the application servers and the nginx container on the load balancer server
- if I didn't make any mistake you should see a message like this:
```
all done, now you can check the application on http://ec2-XX-XXX-XXX-XX.eu-west-1.compute.amazonaws.com/
```
- Go to the url and start hitting f5 or cmd-r (ctrl-r) to see the load balancing working. The message will change accordingly which application server is handling your request!

### NOTES ###
- you can run the init.sh script as many times you want. it's idempotent!
- if you have free-tier AWS acc, you don't need to worry about this project, it shouldn't create anything which is not matching the free-tier
- I was trying to keep as simple this project as much I could, but if you have any questions, please send a mail to csaba.kollar@gmail.com
- if you want to run the steps one by one:
  * first step can run by itself. If you want to make changes, do so in the ansible/demos_infrastructure.yml file, like the size of the VPC or the name of the VPC etc...
  * vm provisioning steps, if you are not using init.sh, add KEYPAIR variable to scripts/create_aws_vm.sh
  * if you are installing application servers with ansible manually, KEYPAIR var is needed
  * for nginx, you must know and send the IPs of APP1 and APP2 servers + KEYPAIR var is needed
- for cleanup, go to EC2 console, disable termination protection on nginx, app1 and app2 vms, and terminate them
  then go to vpc console and simply remove the demos (if you haven't changed the name) vpc, which will cleanup everything
