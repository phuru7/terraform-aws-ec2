output "instance_summary" {
  description = "Summary of created instances"
  value = {
    count = module.ec2_basic_example.instances_info.count
    names = [for instance in module.ec2_basic_example.instances_info.instances : instance.name]
    ids   = [for instance in module.ec2_basic_example.instances_info.instances : instance.id]
  }
}

output "public_ips" {
  description = "Public IP addresses of instances"
  value       = module.ec2_basic_example.network_info.public_ips
}

output "private_ips" {
  description = "Private IP addresses of instances"
  value       = module.ec2_basic_example.network_info.private_ips
}

output "ssh_connection" {
  description = "SSH connection command"
  value = [
    for conn in module.ec2_basic_example.connection_info : 
    "ssh -i ~/.ssh/${conn.key_name}.pem ubuntu@${conn.host}"
  ]
}

output "key_pair_used" {
  description = "Key pair information"
  value       = module.ec2_basic_example.key_pair_info
}

output "vpc_info" {
  description = "VPC information used"
  value = {
    vpc_id     = data.aws_vpc.default.id
    subnet_ids = data.aws_subnets.default.ids
  }
}