run "multi_instance_test" {
  command = plan

  variables {
    environment    = "prod"
    company_name   = "test"
    project_name   = "webapp"
    
    network_config = {
      subnet_ids         = ["subnet-1", "subnet-2"]
      security_group_ids = ["sg-web"]
      eip_count          = 2
    }
    
    key_pair_config = {
      create_new = true
      public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAA..."
    }
    
    additional_tags = {}
  }

  assert {
    condition     = length(aws_instance.this) == 3
    error_message = "Prod environment should create 3 instances"
  }

  assert {
    condition     = aws_instance.this[0].instance_type == "t3.large"
    error_message = "Prod should use t3.large instances"
  }

  assert {
    condition     = length(aws_eip.this) == 2
    error_message = "Should create 2 Elastic IPs"
  }

  assert {
    condition     = length(aws_key_pair.this) == 1
    error_message = "Should create 1 key pair"
  }
}


