region          = "eu-west-1"
vpc_name        = "LSA-NONPROD-LTSQA-vpc"
instance_type   = "t2.large"
key_name        = "lsa-nonprod-ire-private-key"
private_subnets = ["LSA-NONPROD-LTSQA-app_internal_subnets-eu-west-1a", "LSA-NONPROD-LTSQA-app_internal_subnets-eu-west-1b", "LSA-NONPROD-LTSQA-app_internal_subnets-eu-west-1c"]
instance_name   = "app-node01"

sg_name        = "AppNodeSecurityGroup"
sg_description = "Allow multiple ports"

# Existing Security Groups
pre_existing_sg_names = ["App-Tier-LTSQA-SG", "App2Endpoint-Tier-LTSQA-SG"]


sg_ingress_rules = [
  {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["20.101.58.0/23"]
  },
  {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["20.101.58.0/23"]
  },
  {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["20.101.58.0/23"]
  }
]

role_name                       = "AppNodeSSMEC2Role"
ssm_policy_name                 = "AmazonSSMManagedInstanceCore"
permission_boundary_policy_name = "ServiceRoleBoundary"
instance_profile_name           = "AppNodeSSMInstanceProfile"


environment       = "non-prod"
environment_level = "nonprod-e2e"
project_prefix    = "saga-lts"


mandatory_tags = {
  ApplicationName    = "SAGASurveillanceAnalytics"
  ApplicationID      = "APP-80897"
  CostCentre         = "L96532-IMO"
  ProjectCode        = "P007723"
  Environment        = "LTS-NONPROD"
  DataClassification = "Restricted"
  ManagedBy          = "XYO"
  Automation         = "YES"
}



recommended_tags = {
  BusinessUnit        = "LSEGSurveillance"
  Owner               = "AWS-SAGA-LTS-NONPROD@SAGA.COM"
  BusinessCriticality = "1"
  AssignmentGroup     = "CMUKAppSupportSurv"
}


optional_tags = {
  Account  = "AWS-SAGA-LTS-NONPROD"
  Workload = "NONPROD"
}
