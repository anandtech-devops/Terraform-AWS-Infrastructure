variable "name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# SSM Session Manager = shell access without SSH keys or an open port 22
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

output "instance_profile_name" { value = aws_iam_instance_profile.ec2.name }
output "role_arn" { value = aws_iam_role.ec2.arn }
