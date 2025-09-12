run "ebs_volumes_test" {
  command = plan

  variables {
    environment    = "dev"
    company_name   = "test"
    project_name   = "storage"
    
    network_config = {
      subnet_ids         = ["subnet-123"]
      security_group_ids = ["sg-123"]
    }
    
    key_pair_config = {
      create_new        = false
      existing_key_name = "test-key"
    }
    
    ebs_volumes = {
      data = {
        device_name = "/dev/sdf"
        volume_size = 100
        volume_type = "gp3"
      }
      logs = {
        device_name = "/dev/sdg"
        volume_size = 50
        volume_type = "gp2"
      }
    }
    
    additional_tags = {}
  }

  assert {
    condition     = length(aws_ebs_volume.this) == 2
    error_message = "Should create 2 EBS volumes"
  }

  assert {
    condition     = aws_ebs_volume.this["data-0"].size == 100
    error_message = "Data volume should be 100GB"
  }

  assert {
    condition     = aws_ebs_volume.this["logs-0"].size == 50
    error_message = "Logs volume should be 50GB"
  }

  assert {
    condition     = length(aws_volume_attachment.this) == 2
    error_message = "Should create 2 volume attachments"
  }
}
