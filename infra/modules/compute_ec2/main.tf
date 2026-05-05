locals {
  resource_prefix = "${var.name}-${var.environment}"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.resource_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${local.resource_prefix}-role"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "s3_read_server_rb" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.app_s3_bucket}/server.rb"]
  }
}

resource "aws_iam_role_policy" "s3_read_server_rb" {
  name   = "${local.resource_prefix}-s3-read"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.s3_read_server_rb.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.resource_prefix}-profile"
  role = aws_iam_role.this.name
}

resource "aws_security_group" "this" {
  name        = "${local.resource_prefix}-sg"
  description = "Allow inbound TCP 8080 from allowed CIDR blocks for the Ruby HTTP server."

  ingress {
    description = "App HTTP port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Allow all outbound (for dnf install and S3 fetch)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.resource_prefix}-sg"
    Environment = var.environment
  }
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y ruby
    aws s3 cp s3://${var.app_s3_bucket}/server.rb /opt/server.rb
    COMPUTE_TYPE=ec2 nohup ruby /opt/server.rb &
  EOT
}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  user_data              = local.user_data

  tags = {
    Name        = local.resource_prefix
    Environment = var.environment
  }
}
