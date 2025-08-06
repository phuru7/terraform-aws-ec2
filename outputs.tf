output "key_pair_info" {
  description = "Key pair information used by instances"
  value = var.key_pair_config.create_new ? {
    id          = aws_key_pair.this[0].id
    arn         = aws_key_pair.this[0].arn
    name        = aws_key_pair.this[0].key_name
    fingerprint = aws_key_pair.this[0].fingerprint
    created     = true
    } : {
    name    = var.key_pair_config.existing_key_name
    created = false
  }
}

output "eip_info" {
  description = "Elastic IP information"
  value = {
    public_ips = [for eip in aws_eip.this : eip.public_ip]
    dns_names  = [for eip in aws_eip.this : eip.public_dns]
    associations = [for eip in aws_eip.this : eip.association_id]
    count = length(aws_eip.this)
  }
}

output "instances_info" {
  description = "Complete summary of all instances with essential information"
  value = {
    count = length(aws_instance.this)
    instances = [
      for i in range(length(aws_instance.this)) : {
        # Basic Info
        id                = aws_instance.this[i].id
        name              = "${var.environment}-${var.company_name}-${var.project_name}-${i + 1}"
        arn               = aws_instance.this[i].arn
        instance_type     = aws_instance.this[i].instance_type
        availability_zone = aws_instance.this[i].availability_zone
      
        # Network
        private_ip = aws_instance.this[i].private_ip
        public_ip  = aws_instance.this[i].public_ip
        subnet_id  = aws_instance.this[i].subnet_id

        # Storage
        root_volume_id    = aws_instance.this[i].root_block_device[0].volume_id
        root_volume_sizes = aws_instance.this[i].root_block_device[0].volume_size
        ebs_volume_ids = [for vol in aws_ebs_volume.this : vol.id]
      }
    ]
  }
}

output "network_info" {
  description = "Complete network information for all instances"
  value = {
    private_ips            = aws_instance.this[*].private_ip
    public_ips             = aws_instance.this[*].public_ip
    private_dns            = aws_instance.this[*].private_dns
    public_dns             = aws_instance.this[*].public_dns
    subnet_ids             = aws_instance.this[*].subnet_id
  }
}

output "connection_info" {
  description = "SSH/RDP connection information for external tools (Ansible, etc.)"
  value = [
    for i in range(length(aws_instance.this)) : {
      name = "${var.environment}-${var.company_name}-${var.project_name}-${i + 1}"
      id   = aws_instance.this[i].id

      # Connection details
      host = i < length(aws_eip.this) ? aws_eip.this[i].public_ip : (
        aws_instance.this[i].public_ip != null ? aws_instance.this[i].public_ip : aws_instance.this[i].private_ip
      )
      private_ip = aws_instance.this[i].private_ip
      key_name   = aws_instance.this[i].key_name
    }
  ]
}

