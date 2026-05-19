terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
}

variable "aws_access_key_id" { type = string }
variable "aws_secret_access_key" { type = string }
variable "aws_session_token" { type = string }

data "aws_vpc" "default" {
  default = true
}

# Nombre cambiado a _v3 para evitar el error de duplicados en AWS Academy
resource "aws_security_group" "proyecto_sg" {
  name        = "proyecto-semestral-sg"
  description = "Permitir trafico para el despliegue de Innovatech"

  # REGLA CRÍTICA: Permitir SSH para que GitHub Actions pueda entrar
  ingress {
    description = "SSH desde cualquier lugar para el pipeline"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Requerido para que el runner de GitHub dinámico se conecte
  }

  # Tus otras reglas de puertos (80, 8081, 8082)...
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8081
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Script base para instalar Docker en ambas maquinas
variable "user_data_docker" {
  type    = string
  default = <<-EOF
            #!/bin/bash
            apt-get update -y
            apt-get install -y apt-transport-https ca-certificates curl software-properties-common
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
            add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
            apt-get update -y
            # Instala docker y el plugin moderno de compose con espacio
            apt-get install -y docker-ce docker-compose-plugin
            systemctl start docker
            systemctl enable docker
            usermod -aG docker ubuntu
            EOF
}

# Máquina 1: Frontend (React)
resource "aws_instance" "frontend_server" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro" # Al correr solo Nginx/React, 1GB de RAM es suficiente
  key_name               = "vockey"
  vpc_security_group_ids = [aws_security_group.proyecto_sg.id]
  user_data              = var.user_data_docker
  tags                   = { Name = "Servidor-Frontend" }
}

# Máquina 2: Backend (Microservicios Ventas y Despachos)
resource "aws_instance" "backend_server" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.medium" # Se mantiene medium por el alto consumo de los 2 entornos Java
  key_name               = "vockey"
  vpc_security_group_ids = [aws_security_group.proyecto_sg.id]
  user_data              = var.user_data_docker
  tags                   = { Name = "Servidor-Backend-Microservicios" }
}

# Outputs individuales para el pipeline de CI/CD
output "frontend_public_ip" {
  value = aws_instance.frontend_server.public_ip
}

output "backend_public_ip" {
  value = aws_instance.backend_server.public_ip
}