variable "region" {}
variable "vpc_name" {}
variable "instance_type" {}
variable "key_name" {}
variable "instance_name" {}
variable "sg_name" {}
variable "sg_description" {}

variable "environment" {}
variable "environment_level" {}
variable "project_prefix" {}


variable "sg_ingress_rules" {
  description = "List of ingress rules for the security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}
variable "role_name" {}
variable "ssm_policy_name" {}
variable "permission_boundary_policy_name" {}
variable "instance_profile_name" {}

variable "pre_existing_sg_names" {
  description = "List of pre-existing Security Group Names to attach to the instance"
  type        = list(string)
  default     = []
}


variable "private_subnets" {
  description = "List of private subnet names"
  type        = list(string)
  default     = []
}

### Map variables ###

variable "mandatory_tags" {
  description = "mandatory_tags for resource tagging"
  type        = map(string)
}

//BaseImageName =  <-- this is mandatory tag, should be dynamically generated

variable "recommended_tags" {
  description = "recommended_tags for resource tagging"
  type        = map(string)
}

variable "optional_tags" {
  description = "optional_tags for resource tagging"
  type        = map(string)
}
