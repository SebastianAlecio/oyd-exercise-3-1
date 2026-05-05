variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod). Used in resource names and tags."
  type        = string
}

variable "name" {
  description = "Logical name prefix for all resources created by this module."
  type        = string
}

variable "ami_id" {
  description = "AMI ID to launch the EC2 instance from. Must match the architecture of var.instance_type."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Defaults to t3.micro (x86_64). Must match the architecture of var.ami_id."
  type        = string
  default     = "t3.micro"
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed inbound access to TCP port 8080."
  type        = list(string)
}

variable "app_s3_bucket" {
  description = "Name of the S3 bucket that hosts server.rb. The instance pulls the file from s3://<bucket>/server.rb at boot."
  type        = string
}
