# Dev environment values for the compute_ec2 module
region              = "us-west-2"
environment         = "dev"
name                = "oyd-ex31"
ami_id              = "ami-0fa1ce9aa6f270301"
instance_type       = "t3.micro"
allowed_cidr_blocks = ["186.151.92.250/32"]
app_s3_bucket       = "pdds-bucket"
