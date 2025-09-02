# Ejemplo Básico - EC2 Module

Ejemplo mínimo funcional del módulo terraform-aws-ec2.

## Qué crea

- 1 instancia EC2 t3.micro
- Key pair existente o nuevo
- IP pública automática
- Volumen root 20GB encriptado
- Tags organizacionales

## Uso

```bash
# Copiar archivo de variables
cp terraform.tfvars.example terraform.tfvars

# Editar variables necesarias
vim terraform.tfvars

# Inicializar
terraform init

# Planificar
terraform plan

# Aplicar
terraform apply
```

## Variables requeridas

Edita `terraform.tfvars`:

```hcl
# Actualizar con tu key pair existente
key_pair_config = {
  create_new        = false
  existing_key_name = "tu-key-existente"
}

# O crear nuevo key pair
key_pair_config = {
  create_new = true
  public_key = "ssh-rsa AAAAB3... tu-clave-publica"
}
```

## Conexión SSH

Después del deploy:

```bash
# Ver comando SSH generado
terraform output ssh_connection

# Ejemplo de conexión
ssh -i ~/.ssh/mi-key.pem ubuntu@<public-ip>
```

## Limpieza

```bash
terraform destroy
```

## Notas

- Usa VPC default de AWS para simplicidad
- Ideal para testing y demos
- Instancia eligible para free tier (t3.micro)
- Volumen encriptado por defecto