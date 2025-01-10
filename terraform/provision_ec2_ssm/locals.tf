locals {
  resource_prefix = "${var.project_prefix}-${var.environment}"
  ec2_name        = "${local.resource_prefix}-${var.instance_name}"
  compliance_tags = merge(var.mandatory_tags, var.recommended_tags, var.optional_tags)
  ec2_name_tag = {
    Name = local.ec2_name
  }

  all_tags = merge(local.compliance_tags, local.ec2_name_tag)

  prefixed_instance_profile_name = "${local.resource_prefix}-${var.instance_profile_name}"
  prefixed_role_name             = "${local.resource_prefix}-${var.role_name}"
  prefixed_sg_name               = "${local.resource_prefix}-${var.sg_name}"

random_subnet_name = element(var.private_subnets, random_integer.subnet_index.result)
security_group_ids = [for sg in data.aws_security_group.sg_lookup : sg.id]

}

