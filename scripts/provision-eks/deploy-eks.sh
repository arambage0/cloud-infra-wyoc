

# Source the configuration file
source ./eks-config.properties

action=""
infra_component=""


# Function to display usage/help information
usage() {
  echo "Usage: $0 [--setup INFRA_COMPONENT] [--config CONFIG_FILE]"
  echo "  --setup INFRA_COMPONENT    create infra component e.g. vpc-endpoints, cluster, node-groups"
  echo "  --config CONFIG_FILE    provides EKS related configurartions to setup EKS cluster"
  echo "  --help           Show this help message"
  exit 1
}


log_message() {
    local log_type=$1
    local log_msg=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "${timestamp} [${log_type}] ${log_msg}" >> ${log_file}
}

rotate_log() {
    local rotated_timestamp=$(date +"%Y%m%d%H%M%S")
    if [ -e ${log_file} ]; then
      console_message "INFO" "log file exists"
      log_message "INFO" "log file exists"
      mv  ${log_file} ${log_file}_${rotated_timestamp}
      console_message "INFO" "log file rotated"
      log_message "INFO" "log file rotated"
    else
      console_message "ERROR" "log file not exists"
      log_message "ERROR" "log file not exists"
    fi
}

console_message() {
    local log_type=$1
    local log_msg=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "${timestamp} [${log_type}] ${log_msg}"
}


check_vpc_endpoint_status() {
while true
endpoint_statuses=()
do
    for endpoint_name in $ecr_api_service_name $ecr_dkr_service_name $eks_service_name $eks_auth_service_name $sts_service_name $elb_service_name $logs_service_name
    do
        local endpoint_status=$(aws ec2 describe-vpc-endpoints --filters Name=service-name,Values="${endpoint_name}" Name=vpc-id,Values="${vpc_id}" --query VpcEndpoints[*].State --output text)
        local ep_name_tag=$(echo $endpoint_name | cut -d '.' -f4,5)"-vpc-endpoint"

        if [[ "${endpoint_status}" == 'available' ]]; then
                console_message "INFO" "${ep_name_tag} is in available state"
                log_message "INFO" "${ep_name_tag} is in available state"
        elif [[ "${endpoint_status}" == 'pending' ]]; then
                console_message "INFO" "${ep_name_tag} is still provisioning"
                log_message "INFO" "${ep_name_tag} is still provisioning"
                endpoint_statuses+=( $endpoint_status )
        elif [[ "${endpoint_status}" == 'failed' ]]; then
                console_message "ERROR" "${ep_name_tag} provisioning failed"
                log_message "ERROR" "${ep_name_tag} provisioning failed"
                endpoint_statuses+=( $endpoint_status )
        else
                console_message "ERROR" "${ep_name_tag} provisioning in rejected or pendingAcceptance state"
                log_message "ERROR" "${ep_name_tag} provisioning in rejected or pendingAcceptance state"
                endpoint_statuses+=( $endpoint_status )
        fi

    done


if [[ ! ${endpoint_statuses[@]} ]]
then
    console_message "INFO" "all vpc endpoints are in avaiable state"
    console_message "INFO" "vpc endpoint status check completed"
    log_message "INFO" "all vpc endpoints are in avaiable state"
    log_message "INFO" "vpc endpoint status check completed"
    break
else
    console_message "INFO" "few vpc endpoints are still provisioning or in invalid state"
    log_message "INFO" "few vpc endpoints are still provisioning or in invalid state"
    sleep 6
fi

done

}


create_vpc_endpoints() {

local app2endpoint_tier_sg_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values="${app2endpoint_sg_name}" --query  "SecurityGroups[*].[GroupId]"  --output text)
local endpoint_tier_sg_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values="${vpc_endpoint_sg_name}" --query  "SecurityGroups[*].[GroupId]"  --output text)


for ep_name in $ecr_api_service_name $ecr_dkr_service_name $eks_service_name $eks_auth_service_name $sts_service_name $elb_service_name $logs_service_name
do
    local ep_name_tag=$(echo $ep_name | cut -d '.' -f4,5)"-vpc-endpoint"
    console_message "INFO" ""${ep_name_tag}" provisioning started.."
    log_message "INFO" ""${ep_name_tag}" provisioning started.."

    aws ec2 create-vpc-endpoint  --vpc-endpoint-type Interface  --vpc-id "${vpc_id}"  --service-name "${ep_name}"  --subnet-ids "${subnet_aza_id}" "${subnet_azb_id}" "${subnet_azc_id}"  --security-group-ids "${endpoint_tier_sg_id}" "${app2endpoint_tier_sg_id}"  --ip-address-type ipv4   --region "${vpc_region}" --tag-specifications ResourceType=vpc-endpoint,"Tags=[{Key=Name,Value=$ep_name_tag}]">/dev/null 2>&1
    sleep 6

done

}

create_worker_nodes_userdata() {

log_message "INFO" "worker-node userdata creation started"
console_message "INFO" "worker-node userdata creation started"
eks_clsuter_ca_data=$(aws eks describe-cluster --query "cluster.certificateAuthority.data" --output text --name "${k8s_cluster_name}" --region "${vpc_region}")
eks_clsuter_api_endpoint=$(aws eks describe-cluster --query "cluster.endpoint" --output text --name "${k8s_cluster_name}" --region "${vpc_region}")
eks_service_cidr=$(aws eks describe-cluster --query "cluster.kubernetesNetworkConfig.serviceIpv4Cidr" --output text --name "${k8s_cluster_name}"  --region "${vpc_region}")


cat << EOF | base64 -w0 > ./userdata.txt
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -ex

EKS_CLSUTER_NAME=$k8s_cluster_name
EKS_CLUSTER_API=$eks_clsuter_api_endpoint
EKS_CLUSTER_CA=$eks_clsuter_ca_data
EKS_CLUSTER_DNS_IP=$eks_service_cidr

/etc/eks/bootstrap.sh "\${EKS_CLSUTER_NAME}" \\
  --b64-cluster-ca "\${EKS_CLUSTER_CA}" \\
  --apiserver-endpoint "\${EKS_CLUSTER_API}" \\
  --dns-cluster-ip "\${EKS_CLUSTER_DNS_IP}" \
  --kubelet-extra-args '--max-pods=$k8s_max_pod_limit' \\
  --use-max-pods false

--==MYBOUNDARY==--


EOF

log_message "INFO" "worker-node userdata creation completed"
console_message "INFO" "worker-node userdata creation completed"

}


create_launch_template() {

log_message "INFO" "launch template creation started"
console_message "INFO" "launch template creation started"
eks_optimized_ami_id=$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/1.31/amazon-linux-2/recommended/image_id     --region eu-west-1 --query "Parameter.Value" --output text)

addtional_sg_id=$(aws eks describe-cluster --name "${k8s_cluster_name}"   --query "cluster.resourcesVpcConfig.securityGroupIds" --output text)
cluster_sg_id=$(aws eks describe-cluster --name "${k8s_cluster_name}"     --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)
app2endpoint_sg_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values="${app2endpoint_sg_name}" --query  "SecurityGroups[*].[GroupId]"  --output text)
base64_userdata=$(cat ./userdata.txt)


# launch template for workder-nodes
cat << EOF  > ./lt_configs.json
{
    "ImageId":"$eks_optimized_ami_id",
    "UserData": "$base64_userdata",
    "SecurityGroupIds": [
            "$cluster_sg_id",
            "$addtional_sg_id",
            "$app2endpoint_sg_id"
        ],
    "KeyName": "$key_pair_name"
}

EOF

aws ec2 create-launch-template --launch-template-name TemplateForEKSNodeGroup --launch-template-data file://lt_configs.json > /dev/null 2>&1

log_message "INFO" "launch template creation completed"
console_message "INFO" "launch template creation completed"

}




create_eks_cluster() {
# trust policy for cluster role
cat << EOF > ./eks-cluster-role-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF


# trust policy for node role
cat << EOF > ./node-role-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create cluster role and mapped policies
aws iam create-role --role-name "${cluster_role_name}" --assume-role-policy-document file://"eks-cluster-role-trust-policy.json"  --permissions-boundary "${permission_boundary_arn}" > /dev/null 2>&1
aws iam attach-role-policy --policy-arn "${cluster_role_policy_1}" --role-name "${cluster_role_name}" > /dev/null 2>&1
aws iam attach-role-policy --policy-arn "${cluster_role_policy_2}" --role-name "${cluster_role_name}" > /dev/null 2>&1
sleep 2
log_message "INFO" "EKS Cluster role "${cluster_role_name}" creation completed."
console_message "INFO" "EKS Cluster role "${cluster_role_name}" creation completed."


# Create cluster node role and mapped policies
aws iam create-role --role-name "${node_role_name}" --assume-role-policy-document file://"node-role-trust-policy.json"  --permissions-boundary "${permission_boundary_arn}"  > /dev/null 2>&1
aws iam attach-role-policy --policy-arn "${node_role_policy_1}" --role-name "${node_role_name}"  > /dev/null 2>&1
aws iam attach-role-policy --policy-arn "${node_role_policy_2}" --role-name "${node_role_name}"  > /dev/null 2>&1
aws iam attach-role-policy --policy-arn "${node_role_policy_3}" --role-name "${node_role_name}"  > /dev/null 2>&1
aws iam attach-role-policy --policy-arn "${node_role_policy_4}" --role-name "${node_role_name}"  > /dev/null 2>&1
sleep 2
log_message "INFO" "EKS Node role "${node_role_name}" creation completed."
console_message "INFO" "EKS Node role "${node_role_name}" creation completed."


# Create additional custom security group
aws ec2 create-security-group --group-name "${additional_security_group_name}" --description "EKS Cluster Additonal Custom SG" --vpc-id "${vpc_id}"  \
     --tag-specifications ResourceType=security-group,"Tags=[{Key=Name,Value=${additional_security_group_name}}]"  > /dev/null 2>&1

additional_sg_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values="${additional_security_group_name}" --query  "SecurityGroups[*].[GroupId]"  --output text)
log_message "INFO" "Additional custom security group  "${additional_security_group_name}" creation completed."
console_message "INFO" "Additional custom security group  "${additional_security_group_name}" creation completed."


#Add ingress rules
aws ec2 authorize-security-group-ingress    --group-id "${additional_sg_id}" \
    --ip-permissions \
        IpProtocol=-1,IpRanges="[{CidrIp=${vpc_primary_cidr},Description='Allow all traffic from vpc secondary cidr range'}]" \
        IpProtocol=-1,IpRanges="[{CidrIp=${vpc_secondary_cidr},Description='Allow all traffic from vpc primary cidr range'}]" \
    --output table  > /dev/null 2>&1
sleep 2

log_message "INFO" ""${additional_security_group_name}" Ingress rules added and security group provisioning completed"
console_message "INFO" ""${additional_security_group_name}" Ingress rules added and security group provisioning completed"

#Retrive IAM role-EKSClusterRole ARN
eks_cluster_role_arn=$(aws iam get-role --role-name "${cluster_role_name}"  --query 'Role.[Arn]' --output text)

log_message "INFO" ""${k8s_cluster_name}" eks cluster creation started"
console_message "INFO" ""${k8s_cluster_name}" eks cluster creation started"

aws eks create-cluster --region "${vpc_region}"  --name "${k8s_cluster_name}" --kubernetes-version "${k8s_cluster_version}" --role-arn "${eks_cluster_role_arn}" --resources-vpc-config subnetIds="${subnet_aza_id}","${subnet_azb_id}","${subnet_azc_id}",securityGroupIds="${additional_sg_id}",endpointPublicAccess="${endpoint_public_access_flag}",endpointPrivateAccess="${endpoint_private_access_flag}" --access-config authenticationMode="${authentication_mode}" --logging ${controlplane_logging_settings}  > /dev/null 2>&1
sleep 3



log_message "INFO" ""${k8s_cluster_name}" eks cluster creation in progress"
console_message "INFO" ""${k8s_cluster_name}" eks cluster creation in progress"
sleep 9
log_message "INFO" ""Checking ${k8s_cluster_name}" eks cluster status"
console_message "INFO" ""Checking ${k8s_cluster_name}" eks cluster status"
sleep 3
local eks_cluster_status=$(aws eks describe-cluster --region "${vpc_region}" --name "${k8s_cluster_name}"   --query "cluster.status")
log_message "INFO" ""${k8s_cluster_name}" eks cluster status is "${eks_cluster_status}""
console_message "INFO" ""${k8s_cluster_name}" eks cluster status is "${eks_cluster_status}""
log_message "INFO" "Rechecking "${k8s_cluster_name}" eks cluster status "
console_message "INFO" "Rechecking "${k8s_cluster_name}" eks cluster status "
sleep 6
local eks_cluster_status=$(aws eks describe-cluster --region "${vpc_region}" --name "${k8s_cluster_name}"   --query "cluster.status")
log_message "INFO" ""${k8s_cluster_name}" eks cluster status is "${eks_cluster_status}""
console_message "INFO" ""${k8s_cluster_name}" eks cluster status is "${eks_cluster_status}""
log_message "INFO" "Waiting for "${k8s_cluster_name}" eks cluster status is to active"
console_message "INFO" "Waiting for "${k8s_cluster_name}" eks cluster status is to active"

aws eks wait cluster-active --name "${k8s_cluster_name}"
log_message "INFO" "Waiting for "${k8s_cluster_name}" eks cluster status is to active is completed"
console_message "INFO" "Waiting for "${k8s_cluster_name}" eks cluster status is to active is completed"
log_message "INFO" "Run manual verification  for "${k8s_cluster_name}" eks cluster status in AWS console"
console_message "INFO" "Run manual verification  for "${k8s_cluster_name}" eks cluster status in AWS console"

}


create_managed_nodegroup() {
# Manual Step
#---------
# 1. Add access entry to cover aws console login full-admin role once cluster is active

#Retrive IAM role-EKSNodeRole ARN
eks_node_role_arn=$(aws iam get-role --role-name "${node_role_name}"  --query 'Role.[Arn]' --output text)

if [[ "${use_launch_template}" == 'true' ]]; then
    echo "use_launch_template $use_launch_template"
    # Create EKS Cluster managed-node-group with launch template with ami and bootstrap script
    aws eks create-nodegroup --cluster-name "${k8s_cluster_name}"  --nodegroup-name "${nodegroup_name}" --node-role "${eks_node_role_arn}" --subnets ""${subnet_aza_id}""  ""${subnet_azb_id}""  ""${subnet_azc_id}"" --scaling-config minSize="${node_min_size}",maxSize="${node_max_size}",desiredSize="${node_desired_size}" --instance-types "${instance_types}" --launch-template name=TemplateForEKSNodeGroup,version=1 > /dev/null 2>&1

else
    # Create EKS Cluster managed-node-group with fully eks amis no more customization
    # Manual step: Add app2endpoint sg to each ec2 instance to proper cluster communication
    aws eks create-nodegroup --cluster-name "${k8s_cluster_name}"  --nodegroup-name "${nodegroup_name}" --node-role "${eks_node_role_arn}" --subnets ""${subnet_aza_id}""  ""${subnet_azb_id}""  ""${subnet_azc_id}""  --scaling-config minSize="${node_min_size}",maxSize="${node_max_size}",desiredSize="${node_desired_size}" --instance-types "${instance_types}"  --ami-type "${ami_type}" > /dev/null 2>&1

fi


log_message "INFO" ""${nodegroup_name}" node group  for "${k8s_cluster_name}" creation started"
console_message "INFO" ""${nodegroup_name}" node group  for "${k8s_cluster_name}" creation started"


log_message "INFO" ""${nodegroup_name}" node group  for "${k8s_cluster_name}" creation in progress"
console_message "INFO" ""${nodegroup_name}" node group  for "${k8s_cluster_name}" creation in progress"

log_message "INFO" ""${nodegroup_name}" node group  wait for activation"
console_message "INFO" ""${nodegroup_name}" node group  wait for activation"
aws eks wait nodegroup-active     --cluster-name "${k8s_cluster_name}" --nodegroup-name "${nodegroup_name}"

log_message "INFO" "Waiting for "${nodegroup_name}" status is to active is completed"
console_message "INFO" "Waiting for "${nodegroup_name}" status is to active is completed"

log_message "INFO" "Run manual verification  for "${nodegroup_name}" eks cluster status in AWS console"
console_message "INFO" "Run manual verification  for "${nodegroup_name}" eks cluster status in AWS console"

# aws eks describe-nodegroup  --cluster-name "${k8s_cluster_name}"   --nodegroup-name "${nodegroup_name}" --query "nodegroup.status"

}


create_eks_addons() {

log_message "INFO"  "EKS addons installation started"
console_message "INFO"  "EKS addons installation started"
aws eks create-addon --cluster-name "${k8s_cluster_name}"  --addon-name vpc-cni
sleep 15
aws eks create-addon --cluster-name "${k8s_cluster_name}"  --addon-name coredns
sleep 15
aws eks create-addon --cluster-name "${k8s_cluster_name}"  --addon-name kube-proxy
sleep 15

log_message "INFO" "Checking addons status"
console_message "INFO" "Checking addons status"
aws eks describe-addon --cluster-name "${k8s_cluster_name}" --addon-name vpc-cni
aws eks describe-addon --cluster-name "${k8s_cluster_name}"  --addon-name coredns
aws eks describe-addon --cluster-name "${k8s_cluster_name}"  --addon-name kube-proxy


console_message "INFO" "Login to AWS console and check the addon status"
log_message "INFO" "Login to AWS console and check the addon status"
}


# Parse command-line arguments
while [ $# -gt 0 ]; do
  case $1 in
    --setup)
      if [ -n "$2" ]; then
        infra_component=$2
        action="setup"
        shift 2
      else
        echo "Error: --create requires an infra component to define e.g. vpc-endpoints, cluster, etc."
        usage
      fi
      ;;
    --config)
      if [ -n "$2" ]; then
        config_file_name=$2
        shift 2
      else
        echo "Error: create operation requires --config config file name"
        usage
      fi
      ;;
    --help)
      usage
      ;;
    *)
      echo "Error: Invalid option $1"
      usage
      ;;
  esac
done

# Perform the requested action

rotate_log

case $action in
  setup)

    if [ -n "$infra_component" -a "$infra_component" = "vpc-endpoints" ]; then
        create_vpc_endpoints
        check_vpc_endpoint_status
    elif [ -n "$infra_component" -a "$infra_component" = "cluster" ]; then
        create_eks_cluster
    elif [ -n "$infra_component" -a "$infra_component" = "managed-node-group" ]; then
        create_worker_nodes_userdata
        create_launch_template
        create_managed_nodegroup
    elif [ -n "$infra_component" -a "$infra_component" = "eks-addons" ]; then
        create_eks_addons
    else
        echo "Invalid operation!"
    fi

    ;;
  *)
    echo "Error: No action specified."
    usage
    ;;
esac
