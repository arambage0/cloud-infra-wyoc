source ./ec2-config.properties

console_message() {
   local log_type=$1
   local log_msg=$2
   local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
   echo "${timestamp} [${log_type}] ${log_msg}"
                }
