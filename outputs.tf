# ── Security Group ────────────────────────────────────────
output "security_group_ids" {
  description = "Map of instance key to security group ID. Empty if create_security_group = false"
  value       = { for k, v in aws_security_group.this : k => v.id }
}

# ── EC2 Instances ─────────────────────────────────────────
output "instance_ids" {
  description = "Map of instance key to instance ID"
  value       = { for k, v in aws_instance.this : k => v.id }
}

output "instance_arns" {
  description = "Map of instance key to instance ARN"
  value       = { for k, v in aws_instance.this : k => v.arn }
}

output "private_ips" {
  description = "Map of instance key to private IP"
  value       = { for k, v in aws_instance.this : k => v.private_ip }
}

# ── Elastic IPs ───────────────────────────────────────────
output "eip_public_ips" {
  description = "Map of instance key to Elastic IP. Only includes instances with eip = true"
  value       = { for k, v in aws_eip.this : k => v.public_ip }
}

# ── EBS Volumes ───────────────────────────────────────────
output "ebs_volume_ids" {
  description = "Map of volume key to EBS volume ID"
  value       = { for k, v in aws_ebs_volume.this : k => v.id }
}