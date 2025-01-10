

export TF_VAR_s3_bucket="my-wyoc-s3-bucket-a"
export TF_VAR_s3_key="terraform/saga-infra.tfstate"
export TF_VAR_s3_region="eu-west-1"
export TF_VAR_dynamodb_table="my-wyoc-state-lock-a"

terraform init   -backend-config="bucket=${TF_VAR_s3_bucket}" -backend-config="key=${TF_VAR_s3_key}" -backend-config="region=${TF_VAR_s3_region}" -backend-config="dynamodb_table=${TF_VAR_dynamodb_table}"

