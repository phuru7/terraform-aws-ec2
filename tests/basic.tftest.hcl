run "basic_configuration" {
  command = plan

  variables {
    environment    = "dev"
    company_name   = "test"
    project_name   = "app"
    
    network_config = {
      subnet_ids         = ["subnet-123"]
      security_group_ids = ["sg-123"]
    }
    
    key_pair_config = {
      create_new        = false
      existing_key_name = "test-key"
    }
    
    additional_tags = {}
  }

  assert {
    condition     = length(aws_instance.this) == 1
    error_message = "Should create exactly 1 instance"
  }

  assert {
    condition     = aws_instance.this[0].instance_type == "t3.micro"
    error_message = "Dev environment should use t3.micro"
  }
}