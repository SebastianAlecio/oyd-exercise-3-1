output "instance_arn" {
  description = "ARN of the EC2 instance running the Ruby HTTP server."
  value       = module.compute.instance_arn
}

output "public_ip" {
  description = "Public IPv4 address of the EC2 instance."
  value       = module.compute.public_ip
}
