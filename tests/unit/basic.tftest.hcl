# tests/unit/basic.tftest.hcl

provider "aws" {
  region = "us-east-1"
}

# Test 1: Configuración mínima válida
run "test_basic_configuration" {
  command = plan

  variables {
    environment  = "dev"
    company_name = "acme"
    project_name = "test-app"

    network_config = {
      subnet_ids         = ["subnet-12345"]
      security_group_ids = ["sg-12345"]
      eip_count          = 0
    }

    key_pair_config = {
      create_new        = false
      existing_key_name = "test-key"
    }
  }

  # Validaciones de naming pattern
  assert {
    condition     = length(local.name_pattern) > 0
    error_message = "Name pattern debe generarse correctamente"
  }

  assert {
    condition     = local.name_pattern == "dev-acme-test-app"
    error_message = "Name pattern incorrecto: ${local.name_pattern}"
  }

  # Validar configuración de environment defaults
  assert {
    condition     = local.resolved_instance_count == 1
    error_message = "Dev environment debe tener 1 instancia por defecto"
  }

  assert {
    condition     = local.resolved_instance_type == "t3.micro"
    error_message = "Dev environment debe usar t3.micro por defecto"
  }
}

# Test 2: Validación de variables requeridas
run "test_required_variables" {
  command = plan

  variables {
    environment  = "prod"
    company_name = "test-company"
    project_name = "webapp"

    network_config = {
      subnet_ids         = ["subnet-1", "subnet-2"]
      security_group_ids = ["sg-web"]
    }

    key_pair_config = {
      create_new = true
      public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..."
    }
  }

  # Validar que prod environment aplica configuración correcta
  assert {
    condition     = local.resolved_instance_count == 3
    error_message = "Prod environment debe tener 3 instancias por defecto"
  }

  assert {
    condition     = local.resolved_instance_type == "t3.large"
    error_message = "Prod environment debe usar t3.large por defecto"
  }

  assert {
    condition     = local.resolved_monitoring == true
    error_message = "Prod environment debe tener monitoring habilitado"
  }

  assert {
    condition     = local.resolved_disable_api_termination == true
    error_message = "Prod environment debe tener protección de terminación"
  }
}

# Test 3: Override de configuración de environment
run "test_environment_override" {
  command = plan

  variables {
    environment  = "dev"
    company_name = "test"
    project_name = "override-test"

    # Override dev defaults
    instance_config = {
      instance_count = 2
      instance_type  = "t3.medium"
      monitoring     = true
    }

    network_config = {
      subnet_ids         = ["subnet-1"]
      security_group_ids = ["sg-1"]
    }

    key_pair_config = {
      create_new        = false
      existing_key_name = "override-key"
    }
  }

  # Validar que los overrides funcionan
  assert {
    condition     = local.resolved_instance_count == 2
    error_message = "Override de instance_count debe funcionar"
  }

  assert {
    condition     = local.resolved_instance_type == "t3.medium"
    error_message = "Override de instance_type debe funcionar"
  }

  assert {
    condition     = local.resolved_monitoring == true
    error_message = "Override de monitoring debe funcionar"
  }
}