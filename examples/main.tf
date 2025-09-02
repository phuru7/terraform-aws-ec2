terraform {
  required_version = ">= 1.1"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = var.project_name
      Company       = var.company_name
      ManagedBy     = "Terraform"
      Example       = "basic"
    }
  }
}

# Data sources para obtener información existente
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_vpc.default.id
}

# Módulo EC2
module "ec2_basic_example" {
  source = "/.."
  
  # Configuración base requerida
  project_name = var.project_name
  environment  = var.environment
  company_name = var.company_name
  
  # Configuración de instancia
  instance_count = var.instance_count
  instance_type  = var.instance_type
  
  # Red (usando VPC default para simplicidad)
  subnet_ids         = data.aws_subnets.default.ids
  security_group_ids = [data.aws_security_group.default.id]
  
  # Configuración de Key Pair
  key_pair_config = var.key_pair_config
  
  # IP pública automática
  associate_public_ip_address = var.associate_public_ip_address
  
  # Configuración del volumen root
  root_volume = var.root_volume
  
  # Tags específicos
  tags = var.tags
  
  additional_tags = {
    instances = {
      Example = "basic-usage"
      Owner   = var.owner
    }
  }
}