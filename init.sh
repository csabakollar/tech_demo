#!/bin/bash
cd $(dirname $0)
export KEYPAIR="CHANGE-ME"

function die() {
  echo -e "$*"
  exit 1
}

ansible-playbook ./ansible/demos_infrasturcture.yml
bash scripts/create_aws_vm.sh -vm nginx -vpc demos -region eu-west-1 -infra techdemo1 -role loadbalance -sn fea -pu -sg web,ssh
bash scripts/create_aws_vm.sh -vm app1  -vpc demos -region eu-west-1 -infra techdemo1 -role app         -sn fea -pu -sg web,ssh
bash scripts/create_aws_vm.sh -vm app2  -vpc demos -region eu-west-1 -infra techdemo1 -role app         -sn feb -pu -sg web,ssh

echo "Waiting 10 seconds to let the servers boot"
sleep 10 #so vms will be able to boot up

APP1_IP=$(aws ec2 describe-instances --region eu-west-1 --filter "Name=tag:Name,Values=app1" --output json |jq .Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp|xargs echo) || die "Can't find ip of app1 server"
APP2_IP=$(aws ec2 describe-instances --region eu-west-1 --filter "Name=tag:Name,Values=app2" --output json |jq .Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp|xargs echo) || die "Can't find ip of app2 server"
ansible-playbook -u centos --private-key=~/.ssh/$KEYPAIR.pem ./ansible/application.yml
ansible-playbook -u centos --private-key=~/.ssh/$KEYPAIR.pem ./ansible/nginx.yml -e "app1=$APP1_IP app2=$APP2_IP"
URL=$(aws ec2 describe-instances --region eu-west-1 --filter "Name=tag:role,Values=loadbalance" --output json |jq .Reservations[].Instances[].NetworkInterfaces[].Association.PublicDnsName|xargs echo)

echo "all done, now you can check the application on http://$URL/"
