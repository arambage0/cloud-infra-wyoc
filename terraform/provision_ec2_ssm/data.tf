# Fetch the Subnet ID for the randomly selected subnet name
data "aws_subnet" "random_subnet" {
  filter {
    name   = "tag:Name"
    values = [local.random_subnet_name]
  }
}


data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ec2_ssm_policy" {
  name = var.ssm_policy_name
}

data "aws_iam_policy" "permission_boundary_policy" {
  name = var.permission_boundary_policy_name
}


data "aws_vpc" "lts_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Retrieve Security Group IDs for each name
data "aws_security_group" "sg_lookup" {
  for_each = toset(var.pre_existing_sg_names)

  filter {
    name   = "group-name"
    values = [each.key]
  }
}


# Fetch the latest AMI matching the RedHat Linux CIS 8.X pattern
data "aws_ami" "latest_redhat_cis" {
  most_recent = true

  filter {
    name   = "name"
    values = ["redhat_linux_cis_8.X__*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["902784830519"] # Replace with the appropriate owner ID if necessary
}

