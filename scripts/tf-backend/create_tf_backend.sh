

# Default values
AWS_REGION="eu-west-1"
S3_BUCKET_NAME="my-terraform-backend-a"
DYNAMODB_TABLE_NAME="terraform-state-lock-a"


# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --region) AWS_REGION="$2"; shift ;;
        --bucket-name) S3_BUCKET_NAME="$2"; shift ;;
        --dynamodb-table-name) DYNAMODB_TABLE_NAME="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Create S3 bucket
echo "Creating S3 bucket: $S3_BUCKET_NAME in region: $AWS_REGION"
aws s3api create-bucket \
    --bucket "$S3_BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION" \
 

if [ $? -ne 0 ]; then
    echo "Failed to create S3 bucket. Exiting."
    exit 1
fi

# Enable versioning on the S3 bucket
echo "Enabling versioning on S3 bucket: $S3_BUCKET_NAME"
aws s3api put-bucket-versioning \
    --bucket "$S3_BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
  

if [ $? -ne 0 ]; then
    echo "Failed to enable versioning on S3 bucket. Exiting."
    exit 1
fi

# Create DynamoDB table
echo "Creating DynamoDB table: $DYNAMODB_TABLE_NAME"
aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION" \
   

if [ $? -ne 0 ]; then
    echo "Failed to create DynamoDB table. Exiting."
    exit 1
fi

echo "Terraform backend setup completed successfully!"
