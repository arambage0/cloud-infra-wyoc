
source ./ec2-config.properties

console_message() {
   local log_type=$1
   local log_msg=$2
   local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
   echo "${timestamp} [${log_type}] ${log_msg}"
                }

cat << EOF > ./ec2-role-trust-policy.json
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

aws iam create-role --role-name "${iam_role_name}" --assume-role-policy-document file://"ec2-role-trust-policy.json"  --permissions-boundary "${permission_boundary_arn}" > /dev/null 2>&1
console_message "INFO" "iam role is created"

aws iam attach-role-policy --policy-arn "${iam_policy_arn}"  --role-name "${iam_role_name}"     > /dev/null 2>&1
console_message "INFO" "iam policy is attached to role"

aws iam create-instance-profile --instance-profile-name "${ec2_instance_profile_name}"  > /dev/null 2>&1
console_message "INFO" "instance-profile is created"

aws iam add-role-to-instance-profile --role-name "${iam_role_name}"  --instance-profile-name "${ec2_instance_profile_name}" > /dev/null 2>&1
console_message "INFO" "iam role is added to instance-profile"

# Create additional custom security group
aws ec2 create-security-group --group-name "${ec2_sg_name}" --description "${ec2_sg_name}"  --vpc-id "${app_vpc_id}"   --tag-specifications ResourceType=security-group,"Tags=[{Key=Name,Value=$ec2_sg_name}]" > /dev/null 2>&1
console_message "INFO" "ec2 default security group is created"

default_sg_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values="${ec2_sg_name}" --query  "SecurityGroups[*].[GroupId]"  --output text)

app2endpoint_sg_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values="${app2_endpoint_sg_name}" --query  "SecurityGroups[*].[GroupId]"  --output text)

ec2_instance_id=$(aws ec2 run-instances --image-id "${ec2_ami_id}"  --count 1 --instance-type "${ec2_instance_type}" --subnet-id "${ec2_subnet_id}" --security-group-ids "${app2endpoint_sg_id}" "${default_sg_id}" --user-data "${ec2_user_data}"  --tag-specifications ResourceType=instance,"Tags=[{Key=Name,Value=$ec2_name}]" --iam-instance-profile Name="${ec2_instance_profile_name}"  --query 'Instances[*].InstanceId' --output text)
console_message "INFO" "${ec2_name} ec2 is provisioned. instance id: ${ec2_instance_id}"

# To do - check clould init script completion: use below commands
# 1. Run the command targetting ec2 
# aws ssm send-command --document-name "AWS-RunShellScript" --parameters 'commands=["cloud-init status"]' --targets "Key=instanceids,Values=i-1234567890abcdef0" --comment "echo cloud-init status"
#
# 2. Get the command-id from first command and run below command
# aws ssm list-command-invocations --command-id "716fcfd0-c36a-44c8-91ca-ad6268c713bc" --details


console_message "INFO" "Checking ${ec2_name} ec2 ,instance id is ${ec2_instance_id} status"

while true
do
 aws ec2 describe-instance-status --instance-ids "${ec2_instance_id}" > /tmp/ec2-status.json
 instance_state=$(jq '.InstanceStatuses[].InstanceState.Name' /tmp/ec2-status.json)
 instance_status=$(jq '.InstanceStatuses[].InstanceStatus.Status' /tmp/ec2-status.json)
 system_status=$(jq '.InstanceStatuses[].SystemStatus.Status' /tmp/ec2-status.json)

 if [[ "${instance_state}" == '"running"' ]] && [[ "${instance_status}" == '"ok"' ]] && [[ "${system_status}" == '"ok"' ]]
 then
           console_message "INFO" "${ec2_name} ec2,instance id is ${ec2_instance_id} is ready now"
           console_message "INFO" "script execution completed successfully"

           break 
 else
           console_message "INFO" "${ec2_name} ec2,instance id is ${ec2_instance_id} still spinning up"
           sleep 6
 fi

done


rm -f /tmp/ec2-status.json
