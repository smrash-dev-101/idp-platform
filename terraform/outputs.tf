
output "instance_public_ip" {
  description = "Public IP address of the provisioned instance"
  value       = aws_instance.idp_example.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the provisioned instance"
  value       = aws_instance.idp_example.public_dns
}

output "ssh_command" {
  description = "Command to SSH into the provisioned instance"
  value       = "ssh -i ~/.ssh/idp-platform-key ubuntu@${aws_instance.idp_example.public_ip}"

}
