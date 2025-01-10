resource "aws_iam_role" "ec2_role" {
  name               = var.role_name
  assume_role_policy = var.assume_role_policy
  permissions_boundary = var.permission_boundary_arn
}


resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = var.ssm_policy_arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = var.instance_profile_name
  role = aws_iam_role.ec2_role.name
}

