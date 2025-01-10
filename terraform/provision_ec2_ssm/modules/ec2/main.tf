resource "aws_instance" "ec2_instance" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_id
  iam_instance_profile = var.iam_instance_profile
  vpc_security_group_ids = var.security_group_ids
  tags = var.all_tags
    
}

