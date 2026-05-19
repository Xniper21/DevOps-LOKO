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

# Detectar la VPC por defecto para conocer su segmento de red (CIDR)
data "aws_vpc" "default" {
  default = true
}

# Modificación del Security Group adaptado para ECS e interacción con la BD
resource "aws_security_group" "proyecto_sg" {
  name        = "proyecto-semestral-sg-ecs"
  description = "Permitir trafico para hibrido Innovatech (ECS + EC2)"

  # Regla para conectarte por SSH a la base de datos si necesitas revisar tablas
  ingress {
    description = "SSH desde cualquier lugar"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regla para el Frontend en ECS (Puerto HTTP estándar)
  ingress {
    description = "Acceso HTTP para el Frontend en ECS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regla para el Backend en ECS (Puertos de tus microservicios)
  ingress {
    description = "Acceso a Microservicios en ECS"
    from_port   = 8081
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # REGLA CRÍTICA: Permite que ECS se conecte a la base de datos local de la EC2
  # Usamos el CIDR de la VPC por defecto para que la comunicación sea interna y segura
  ingress {
    description = "Acceso a MySQL/PostgreSQL desde la red interna de la VPC"
    from_port   = 3306 # Cambiar a 5432 si tu base de datos es PostgreSQL
    to_port     = 3306 # Cambiar a 5432 si tu base de datos es PostgreSQL
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Script modificado para configurar la Base de Datos en lugar de Docker
variable "user_data_db" {
  type    = string
  default = <<-EOF
            #!/bin/bash
            apt-get update -y
            # Ejemplo para instalar MySQL Server de forma automatizada
            apt-get install -y mysql-server
            systemctl start mysql
            systemctl enable mysql
            
            # Configurar MySQL para que escuche peticiones de la red interna (no solo localhost)
            sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
            systemctl restart mysql
            
            # Nota: Aquí deberías ejecutar tus scripts de creación de tablas/usuarios si los tienes
            EOF
}

# La única máquina física que queda: Servidor de Base de Datos
resource "aws_instance" "db_server" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro" # Para una BD de pruebas, micro es más que suficiente
  key_name               = "vockey"
  vpc_security_group_ids = [aws_security_group.proyecto_sg.id]
  user_data              = var.user_data_db
  tags                   = { Name = "Servidor-Base-Datos-Innovatech" }
}

# OUTPUTS CLAVE: De aquí extraerás los datos para tu task-definition.json
output "db_public_ip" {
  description = "IP publica para conectarte tú mediante Workbench o DBeaver"
  value       = aws_instance.db_server.public_ip
}

output "db_private_ip" {
  description = "ESTA ES LA IP QUE DEBES PEGAR EN EL DB_HOST DE TU TASK-DEFINITION"
  value       = aws_instance.db_server.private_ip
}

output "vpc_cidr_block" {
  description = "Segmento de red interna de tu laboratorio"
  value       = data.aws_vpc.default.cidr_block
}