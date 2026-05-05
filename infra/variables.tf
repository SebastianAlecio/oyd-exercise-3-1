variable "region" {
  description = "AWS region to deploy resources into."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string
}

variable "name" {
  description = "Logical name prefix passed to the compute_ec2 module."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance. Must match the architecture of var.instance_type."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Must match the architecture of var.ami_id."
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed inbound on TCP 8080."
  type        = list(string)
}

variable "app_s3_bucket" {
  description = "Name of the S3 bucket hosting server.rb."
  type        = string
}
