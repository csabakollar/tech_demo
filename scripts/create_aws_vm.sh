#!/bin/bash

#############################################
cd $(dirname $0)
SSHKEY="${HOME}/.ssh/${KEYPAIR}.pem"

function usage() {
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo -e "  -vm                     New VM's FQDN/Name (mandatory)"
  echo -e "  -region                 Region of the VM (mandatory) (example: eu-west-1)"
  echo -e "  -vpc                    VPC Name (mandatory)"
  echo -e "  -infra                  Infrastructure of the VM (mandatory)"
  echo -e "  -role                   Role of the VM (mandatory)"
  echo -e "  -sn | --subnet          Subnet name (mandatory)"
  echo -e "  -vt | --vmtype          New VM's type (optional) (default: t2.micro)"
  echo -e "  -ds | --disk_size       Disk size in GBs (optional) (default: 8GB)"
  echo -e "  -dt | --disk_type       Disk type <standard|gp2|io1> (optional) (default: standard magnetic)"
  echo -e "  -pu | --public_ip       Assign a dynamic public IP to the VM (optional) (default: no)"
  echo -e "  -fi | --fixed_ip        Assign a fixed public IP to the VM (optional) (default: no)"
  echo -e "  -sg | --security_groups Security Group(s) (optional, default: ssh)"
  echo
  echo "Example: $0 -vm web01.example.com -region eu-west-1 -vpc demos -infra techdemo1 \\"
  echo -e "                            -role fe_web -sn fea -vt t2.small -ds 10 -d standard -pu -sg ssh,web\n"
  echo "The command above will create a VM named web01.example.com"
  echo "in Ireland region in the demos VPC in the fea subnet."
  echo "Instance type will be a t2.small, with 30GB magnetic disc and a public IP address."
  echo "The machine will be reachable via its FQDN via SSH and HTTP/HTTPS"
  echo
}

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
RESET=$(tput sgr0)

function die() {
  echo -e "${RED}$*${RESET}"
  exit 1
}

function success() {
  echo -e "${GREEN}$*${RESET}"
}


if [ $# -eq 0 ]; then
  usage
  exit 2
fi

while [ "$1" != "" ]; do
  case $1 in
    -vm) shift; VM=$1 ;;
    -region) shift; REGION=$1 ;;
    -vpc) shift; VPC=$1 ;;
    -infra) shift; INFRA=$1 ;;
    -role) shift; ROLE=$1 ;;
    -sn|--subnet) shift; SN=$1 ;;
    -vt|--vmtype) shift; VT=$1 ;;
    -ds|--disk_size) shift; DS=$1 ;;
    -dt|--disk_type) shift; DT=$1 ;;
    -pu|--public_ip) PU="yes" ;;
    -fi|--fixed_ip) FI="true"; PU="yes"; FIXED="yes" ;;
    -sg|--security_groups) shift; SG=$1 ;;
    -sr|--server_role) shift; SR=$1 ;;
    -h) usage; exit ;;
    *) usage; exit 1
  esac
  shift
done

###
### Checks
###
#Check that the default ssh key exists
[[ -f ${SSHKEY} ]] || die "Cannot find ${KEYPAIR}.pem private key in ${HOME}/.ssh directory"
### CHECKING THAT REQUIRED VARIABLES ARE PRESENT
[[ ${VM} ]] || die "Missing argument: vm"
[[ ${VPC} ]] || die "Missing argument: vpc"
[[ ${ROLE} ]] || die "Missing argument: role"
[[ ${INFRA} ]] || die "Missing argument: infra"
[[ ${SN} ]] || die "Missing argument: subnet"
[[ ${REGION} ]] || die "Missing argument: region"
HOSTNAME=$(echo ${VM} | cut -f 1 -d'.')
#Check whether the credentials to connect to ec2 are set
export |grep -qw AWS_ACCESS_KEY || die "Cannot find AWS_ACCESS_KEY environmental variable"
export |grep -qw AWS_SECRET_KEY || die "Cannot find AWS_SECRET_KEY environmental variable"
#Check if ansible binary is present
which ansible-playbook 2>&1 >/dev/null || die "Cannot find ansible-playbook executable"
#Check if awscli binary is present
which aws 2>&1 >/dev/null || die "Cannot find aws executable"
#Check wether VM's name is valid
echo ${VM} |egrep -qv '[^a-z._A-Z0-9-]' || die "invalid name, only a-z, A-Z, 0-9, ., - and _ are allowed"
[[ ${DS} ]] || DS=8
echo ${DS}|egrep -q -v '[^0-9]' || die "Invalid disk size"
#Check region's validity
case "$REGION" in
  eu-west-1) AMI="ami-33734044" ;; #CENTOS 7.1
  eu-central-1) AMI="ami-e68f82fb" ;; #CENTOS 7.1
  *) die "Currently unsupported region: $REGION";;
esac
#Check if VM already exists
[[ $(aws ec2 describe-instances --region ${REGION} --filter "Name=tag:Name,Values=${VM}" "Name=instance-state-name,Values=running,pending,shutting-down,stopped,stopping" --output json|wc -l) -gt 3 ]] && die "VM already exists, please terminate it first!"
################################################################################
### SETTING UP VARIABLES TO THEIR DEFAULTS IF THEY WEREN'T SET
# Default VM type is t2.micro
[[ ${VT} ]] || VT="t2.micro"
case "${VT}" in
	t2.micro|t2.small|t2.medium|t2.large|c4.large|c4.xlarge|m4.large|m4.xlarge|r3.large|r3.xlarge) ;;
	*) usage && die "Unknown VM type" ;;
esac
# Default Disk Type is Standard
[[ ${DT} ]] || DT="standard"
case "${DT}" in
	standard|gp2|io1) ;;
	*) usage && die "Unknown disk type" ;;
esac
# Default Security Group is ssh,zabbix
[[ ${SG} ]] || SG="ssh"
[[ ${PU} ]] || PU="no"
[[ ${FIXED} ]] || FIXED="no"
[[ ${PU} ]] || PU="no"
################################################################################
echo -e "Summary:\n VM: ${HOSTNAME}\n Instance type: ${VT}\n VM role: ${ROLE}\n VM Environment: ${INFRA}\n Disk type: ${DT}\n Disk size: ${DS}\n VPC: ${VPC}\n Subnet: ${SN}"
echo -e " Public IP: ${PU}\n Fixed IP: ${FIXED}"

echo -e "\nValidating the arguments:"
echo -e "o Validating VPC: ${VPC}... \c"
VPCID=$(aws ec2 describe-vpcs --region ${REGION} --filter Name=tag:Name,Values=${VPC} --output json | grep VpcId | cut -f4 -d'"')
[[ ${VPCID} ]] || die "cannot validate: ${VPC}!"
success "validated."

echo -e "o Validating SUBNET: ${VPC}-${INFRA}-${SN} \c"
SUBNETNAMES=$(aws ec2 describe-subnets --region ${REGION} --filter Name=vpc-id,Values=${VPCID} --output json | grep -i ${VPC}'-' | cut -f4 -d'"')
for SUBNET in ${SUBNETNAMES}; do
    # let's convert the subnet names in lowercase
    SUBNETLC=$(echo ${SUBNET}| awk '{print tolower($0)}')
    SNLC=$(echo ${SN} | awk '{print tolower($0)}')
    if [ "${SUBNETLC}" == "${VPC}-${INFRA}-${SNLC}" ]; then
      SUBNETID=$(aws ec2 describe-subnets --region ${REGION} --filter Name=tag:Name,Values=${SUBNET} --output json | grep -i SubnetId | cut -f4 -d'"')
      REGION=$(aws ec2 describe-subnets --region ${REGION} --filter Name=tag:Name,Values=${SUBNET} --output json | grep -i AvailabilityZone | cut -f4 -d'"'|rev |cut -c2- |rev)
    fi
done
[[ ${SUBNETID} ]] || die "cannot validate: ${SN}!"
success "validated."

echo $SG |grep -q ssh || SG="$SG,ssh"
SGARR=$(echo $SG | tr "," "\n")
I=0
SGQUOTED=""
for SECGROUP in $SGARR; do
  echo -e "o Validating SG: ${VPC}-${INFRA}-${SECGROUP} \c"
  GROUPID=$(aws ec2 describe-security-groups --region ${REGION} --filter Name=tag:Name,Values=${VPC}-${INFRA}-${SECGROUP} --output json | grep GroupId | cut -f4 -d'"')
  [[ ${GROUPID} ]] || die "cannot validate: ${VPC}-${INFRA}-${SECGROUP}!"
  success "validated."
  if [ $I -eq "0" ]; then
    SGLIST="${GROUPID}"
  else
    SGLIST="$SGLIST ${GROUPID}"
  fi
  (( I += 1 ))
done

#Create the VM
echo -e "\nCreating VM ${HOSTNAME}"
ansible-playbook -e "infra=${INFRA} customer=${VPC} role=${ROLE} ami=${AMI} keypair=${KEYPAIR} customername=${VPC} hostname=${HOSTNAME} subnet=${SUBNETID} instancetype=${VT} volumesize=${DS} volumetype=${DT} vmname=${VM} region=${REGION} public_ip=${PU} fixed_ip=${FI}" ../ansible/aws_create_vm.yml || die "VM creation failed!"

PRIVATEIP=$(aws ec2 describe-instances --region ${REGION} --filter "Name=tag:Name,Values=${VM}" --output json |grep -w PrivateIpAddress |cut -f4 -d'"'|uniq)
[[ ${PU} == "no" ]] && echo -e "\no VM ${VM} has been created! IP: ${PRIVATEIP}" && echo "o Wait for VM to be booted and be configured by AWS (~90s)" && exit 0
PUBLICIP=$(aws ec2 describe-instances --region ${REGION} --filter "Name=tag:Name,Values=${VM}" --output json| grep PublicIpAddress | cut -f4 -d\")
echo -e "\no VM ${VM} has been created! IP: ${PUBLICIP}"
INSTANCEID=$(aws ec2 describe-instances --region ${REGION} --filter "Name=tag:Name,Values=${VM}" "Name=instance-state-name,Values=running" --output json| grep InstanceId | cut -f4 -d\")
echo -e "\no Changing VM's security groups..."
SEGROUPCHANGES=$(aws ec2 modify-instance-attribute --region ${REGION} --instance-id ${INSTANCEID} --groups ${SGLIST})
echo "o Wait for VM to be booted and be configured by AWS (~90s)"
