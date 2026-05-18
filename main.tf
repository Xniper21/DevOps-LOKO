# 1. Configuración de Terraform y almacenamiento del estado
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Almacena el estado localmente en el repositorio para que GitHub Actions lo reconozca en cada push
  backend "local" {
    path = "terraform.tfstate"
  }
}

# 2. Proveedor de AWS configurado con credenciales dinámicas de AWS Academy
provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
}

# Declaración de variables para los secretos dinámicos del laboratorio
variable "aws_access_key_id" {
  type        = string
  description = "Access Key ID temporal de AWS Academy"
}

variable "aws_secret_access_key" {
  type        = string
  description = "Secret Access Key temporal de AWS Academy"
}

variable "aws_session_token" {
  type        = string
  description = "Session Token temporal de AWS Academy"
}

# 3. Referencia a la VPC por defecto existente en el laboratorio
data "aws_vpc" "default" {
  default = true
}

# 4. Grupo de Seguridad para habilitar los puertos del Frontend y Microservicios
resource "aws_security_group" "proyecto_sg" {
  name        = "sg_proyecto_semestral_v2" # <--- Agrégale un _v2 aquí
  description = "Permitir el trafico para los microservicios de ventas, despachos y frontend"
  vpc_id      = data.aws_vpc.default.id

  # Puerto SSH (22): Requerido para el despliegue automático desde GitHub Actions
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto HTTP (80): Para acceder al Frontend de React (front_despacho)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto 8081: Para el Microservicio de Despachos (Spring Boot)
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto 8082: Para el Microservicio de Ventas (Spring Boot)
  ingress {
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regla de salida global para permitir descargas de paquetes y actualizaciones
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Instancia EC2 con aprovisionamiento automático de Docker y Docker Compose
resource "aws_instance" "app_server" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS en us-east-1
  instance_type = "t2.medium"             # 4GB RAM necesarios para compilar y correr dos apps de Java + React

  # Llave SSH universal predeterminada en las cuentas de AWS Academy
  key_name               = "vockey" 
  vpc_security_group_ids = [aws_security_group.proyecto_sg.id]

  # Script de automatización (User Data) para instalar el motor de Docker
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update -y
              apt-get install -y docker-ce docker-compose
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "Servidor-ProyectoSemestral"
  }
}

# 6. Salida de la IP pública para que GitHub Actions la use dinámicamente
output "instance_public_ip" {
  value       = aws_instance.app_server.public_ip
  description = "IP publica de la instancia EC2 generada por Terraform"
}