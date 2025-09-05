#################################
# Key Pair Information
#################################
output "key_pair_info" {
  description = "Key pair information used by instances"
  value = var.key_pair_config.create_new ? {
    id          = aws_key_pair.this[0].id
    arn         = aws_key_pair.this[0].arn
    name        = aws_key_pair.this[0].key_name
    fingerprint = aws_key_pair.this[0].fingerprint
    created     = true
    public_key  = aws_key_pair.this[0].public_key
    } : {
    name    = var.key_pair_config.existing_key_name
    created = false
  }
}

#################################
# Elastic IP Information
#################################
output "eip_info" {
  description = "Elastic IP information with enhanced details"
  value = {
    count          = length(aws_eip.this)
    public_ips     = [for eip in aws_eip.this : eip.public_ip]
    dns_names      = [for eip in aws_eip.this : eip.public_dns]
    associations   = [for eip in aws_eip.this : eip.association_id]
    allocation_ids = [for eip in aws_eip.this : eip.allocation_id]

    eip_mappings = [
      for i in range(length(aws_eip.this)) : {
        instance_id   = aws_instance.this[i].id
        instance_name = "${local.name_pattern}-${i + 1}"
        public_ip     = aws_eip.this[i].public_ip
        public_dns    = aws_eip.this[i].public_dns
        allocation_id = aws_eip.this[i].allocation_id
      }
    ]
  }
}

#################################
# Instances Information
#################################
output "instances_info" {
  description = "Complete summary of all instances with essential information"
  value = {
    count = length(aws_instance.this)
    environment_config = {
      environment  = var.environment
      company_name = var.company_name
      project_name = var.project_name
      name_pattern = local.name_pattern
    }
    instances = [
      for i in range(length(aws_instance.this)) : {
        # Basic Info
        id                = aws_instance.this[i].id
        name              = "${local.name_pattern}-${i + 1}"
        arn               = aws_instance.this[i].arn
        instance_type     = aws_instance.this[i].instance_type
        availability_zone = aws_instance.this[i].availability_zone

        # Network Info
        private_ip  = aws_instance.this[i].private_ip
        public_ip   = aws_instance.this[i].public_ip
        private_dns = aws_instance.this[i].private_dns
        public_dns  = aws_instance.this[i].public_dns
        subnet_id   = aws_instance.this[i].subnet_id

        # EIP Info
        elastic_ip = i < length(aws_eip.this) ? {
          public_ip     = aws_eip.this[i].public_ip
          public_dns    = aws_eip.this[i].public_dns
          allocation_id = aws_eip.this[i].allocation_id
        } : null

        # Storage Info
        root_volume = {
          id        = aws_instance.this[i].root_block_device[0].volume_id
          size      = aws_instance.this[i].root_block_device[0].volume_size
          type      = aws_instance.this[i].root_block_device[0].volume_type
          encrypted = aws_instance.this[i].root_block_device[0].encrypted
        }

        # EBS volume attachment
        ebs_volumes = [
          for vol_key, vol in aws_ebs_volume.this : {
            name        = vol_key
            id          = vol.id
            size        = vol.size
            type        = vol.type
            encrypted   = vol.encrypted
            device_name = aws_volume_attachment.this[vol_key].device_name
          } if can(regex("${i}$", vol_key))
        ]

        # Configuration Applied
        configuration = {
          monitoring             = aws_instance.this[i].monitoring
          termination_protection = aws_instance.this[i].disable_api_termination
          stop_protection        = aws_instance.this[i].disable_api_stop
          shutdown_behavior      = aws_instance.this[i].instance_initiated_shutdown_behavior
          iam_instance_profile   = aws_instance.this[i].iam_instance_profile
        }
      }
    ]
  }
}

#################################
# Network Information 
#################################
output "network_info" {
  description = "Complete network information for all instances"
  value = {
    vpc_info = {
      subnet_ids         = var.network_config.subnet_ids
      security_group_ids = var.network_config.security_group_ids
      public_ip_enabled  = var.network_config.associate_public_ip_address
      eip_count          = var.network_config.eip_count
    }
    instances_network = {
      private_ips = aws_instance.this[*].private_ip
      public_ips  = aws_instance.this[*].public_ip
      private_dns = aws_instance.this[*].private_dns
      public_dns  = aws_instance.this[*].public_dns
      subnet_ids  = aws_instance.this[*].subnet_id
    }
    elastic_ips = length(aws_eip.this) > 0 ? {
      public_ips = aws_eip.this[*].public_ip
      dns_names  = aws_eip.this[*].public_dns
    } : null
  }
}


#################################
# EBS Volumes Information
#################################
output "ebs_volumes_info" {
  description = "Detailed information about all EBS volumes"
  value = {
    count = length(aws_ebs_volume.this)
    volumes = {
      for vol_key, vol in aws_ebs_volume.this : vol_key => {
        # Volume details
        id                = vol.id
        arn               = vol.arn
        size              = vol.size
        type              = vol.type
        iops              = vol.iops
        throughput        = vol.throughput
        encrypted         = vol.encrypted
        kms_key_id        = vol.kms_key_id
        availability_zone = vol.availability_zone
        multi_attach      = vol.multi_attach_enabled
        
        # Attachment details
        attachment = {
          device_name = aws_volume_attachment.this[vol_key].device_name
          instance_id = aws_volume_attachment.this[vol_key].instance_id
        }
        
        # Configuration source
        source_config = var.ebs_volumes[split("-", vol_key)[0]]
      }
    }
    
    # Summary by instance
    by_instance = {
      for i in range(local.resolved_instance_count) : "${local.name_pattern}-${i + 1}" => [
        for vol_key, vol in aws_ebs_volume.this : {
          name        = vol_key
          id          = vol.id
          size        = vol.size
          type        = vol.type
          device_name = aws_volume_attachment.this[vol_key].device_name
        } if can(regex("${i}$", vol_key))
      ]
    }
  }
}


#################################
# Connection Information
#################################
output "connection_info" {
  description = "SSH/RDP connection information for external tools (Ansible, etc.)"
  value = [
    for i in range(length(aws_instance.this)) : {
      # Instance identification
      name = "${local.name_pattern}-${i + 1}"
      id   = aws_instance.this[i].id
      index = i

      # Connection details with priority: EIP > Public IP > Private IP
      host = i < length(aws_eip.this) ? aws_eip.this[i].public_ip : (
        aws_instance.this[i].public_ip != null ? aws_instance.this[i].public_ip : aws_instance.this[i].private_ip
      )
      
      # All available IPs
      ips = {
        private_ip = aws_instance.this[i].private_ip
        public_ip  = aws_instance.this[i].public_ip
        elastic_ip = i < length(aws_eip.this) ? aws_eip.this[i].public_ip : null
      }
      
      # SSH/Connection details
      connection = {
        key_name = aws_instance.this[i].key_name
        user     = can(regex("ubuntu", data.aws_ami.this[0].name)) ? "ubuntu" : "ec2-user"
        port     = 22
      }
      
      # Instance details for automation
      instance_details = {
        type              = aws_instance.this[i].instance_type
        availability_zone = aws_instance.this[i].availability_zone
        subnet_id        = aws_instance.this[i].subnet_id
        environment      = var.environment
      }
    }
  ]
}
