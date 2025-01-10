variable "ami" {}
variable "instance_type" {}
variable "key_name" {}
variable "subnet_id" {}
variable "iam_instance_profile" {}
variable "all_tags" {}
variable "security_group_ids" {
  description = "List of security group IDs to attach to the instance"
  type        = list(string)
}

