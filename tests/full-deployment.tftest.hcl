run "full_deployment" {
  command = plan

  variables {
    environment    = "staging"
    company_name   = "acme"
    project_name   = "webapp"
    
    instance_config = {
      instance_count = 2
      instance_type  = "t3.medium"
      monitoring     = true
    }
    
    network_config = {
      subnet_ids         = ["subnet-1", "subnet-2"]
      security_group_ids = ["sg-web", "sg-app"]
      eip_count          = 1
    }
    
    key_pair_config = {
      create_new = true
      public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAA..."
    }
    
    ebs_volumes = {
      app_data = {
        device_name      = "/dev/sdf"
        volume_size      = 200
        volume_type      = "gp3"
        instance_indices = [0, 1]
      }
      logs = {
        device_name      = "/dev/sdg"
        volume_size      = 50
        instance_indices = [0]
      }
    }
    
    root_volume = {
      size = 100
      type = "gp3"
    }
    
    additional_tags = {
      instances = {
        Environment = "staging"
      }
    }
  }

  # Instances validation
  assert {
    condition     = length(aws_instance.this) == 2
    error_message = "Should create 2 instances"
  }

  assert {
    condition     = aws_instance.this[0].monitoring == true
    error_message = "Monitoring should be enabled"
  }

  # EBS volumes validation
  assert {
    condition     = length(aws_ebs_volume.this) == 3
    error_message = "Should create 3 EBS volumes (2 app_data + 1 logs)"
  }

  # EIP validation
  assert {
    condition     = length(aws_eip.this) == 1
    error_message = "Should create 1 Elastic IP"
  }

  # Key pair validation
  assert {
    condition     = length(aws_key_pair.this) == 1
    error_message = "Should create 1 key pair"
  }

  # Root volume validation
  assert {
    condition     = aws_instance.this[0].root_block_device[0].volume_size == 100
    error_message = "Root volume should be 100GB"
  }

  # Security validation - IMDSv2
  assert {
    condition     = aws_instance.this[0].metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 should be enforced"
  }
}

