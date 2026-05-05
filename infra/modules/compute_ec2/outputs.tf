output "instance_arn" {
  description = "ARN of the EC2 instance running the Ruby HTTP server."
  value       = aws_instance.this.arn
}

output "public_ip" {
  description = "Public IPv4 address of the EC2 instance. Reach the server at http://<public_ip>:8080."
  value       = aws_instance.this.public_ip
}
