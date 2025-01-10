terraform {
  backend "s3" {
    bucket         = "my-wyoc-s3-bucket"
    key            = "terraform/state/my-project.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "my-wyoc-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

module "security_group" {
  source        = "./modules/security_group"
  name          = local.prefixed_sg_name
  description   = var.sg_description
  vpc_id        = data.aws_vpc.lts_vpc.id
  ingress_rules = var.sg_ingress_rules
}

module "iam_role" {
  source                  = "./modules/iam_role"
  role_name               = local.prefixed_role_name
  assume_role_policy      = data.aws_iam_policy_document.assume_role_policy.json
  instance_profile_name   = local.prefixed_instance_profile_name
  permission_boundary_arn = data.aws_iam_policy.permission_boundary_policy.arn
  ssm_policy_arn          = data.aws_iam_policy.ec2_ssm_policy.arn
}

module "ec2" {
  source               = "./modules/ec2"
  ami                  = data.aws_ami.latest_redhat_cis.id
  instance_type        = var.instance_type
  key_name             = var.key_name
  subnet_id            = data.aws_subnet.random_subnet.id
  iam_instance_profile = module.iam_role.instance_profile_name
  all_tags             = local.all_tags
  security_group_ids   = concat([module.security_group.security_group_id], local.security_group_ids)
}


