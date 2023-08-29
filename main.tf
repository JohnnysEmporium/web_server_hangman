terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.5.3"
}

provider "aws" {
  region = "eu-north-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc-0" {
  cidr_block = "10.0.0.0/23"
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc-0.id
}

resource "aws_subnet" "subnet-0" {
  vpc_id     = aws_vpc.vpc-0.id
  cidr_block = "10.0.1.0/27"

  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.vpc-0.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

resource "aws_route_table_association" "route-table-association" {
  subnet_id      = aws_subnet.subnet-0.id
  route_table_id = aws_route_table.route-table.id
}

resource "aws_security_group" "sg-allow-web" {
  name   = "allow_web_traffic"
  vpc_id = aws_vpc.vpc-0.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "hangman-app"
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_network_interface" "app-server-nic" {
  subnet_id       = aws_subnet.subnet-0.id
  private_ips     = ["10.0.1.30"]
  security_groups = [aws_security_group.sg-allow-web.id]
}

resource "aws_eip" "app-server-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.app-server-nic.id
  associate_with_private_ip = "10.0.1.30"
  depends_on                = [aws_internet_gateway.gateway]
}

resource "aws_key_pair" "app-server-key-pair" {
  key_name   = "app-server-public-key"
  public_key = var.public_key
}

resource "aws_instance" "app-server" {
  ami               = "ami-0989fb15ce71ba39e"
  instance_type     = "t3.nano"
  availability_zone = data.aws_availability_zones.available.names[0]
  key_name          = "app-server-public-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.app-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install python3-pip -y
              sudo apt install python3.10-venv -y
              sudo apt install postgresql -y
              sudo apt install python3 -y
              sudo apt install git -y
              
              sudo -u postgres bash -c "psql -c \"create user admin password 'admin';\""
              sudo -u postgres bash -c "psql -c \"create database hangmandb;\""
              sudo -u postgres bash -c "psql -c \"grant all privileges on database hangmandb to admin;\""
            
              iptables -I INPUT -p tcp --dport 8000 -j LOG
              
              mkdir /hangman-app
              cd /hangman-app
              git clone "https://github.com/JohnnysEmporium/Django_Hangman.git"
              chmod -R 774 /hangman-app
              chown -R :ubuntu /hangman-app

              python3 -m venv env
              source env/bin/activate
              pip3 install django
              pip3 install psycopg2-binary
              
              cd Django_Hangman/
              python3 manage.py makemigrations accounts
              python3 manage.py migrate
              nohup python3 manage.py runserver 0.0.0.0:8000 > app_log 2>&1 &            
              EOF
  tags = {
    Name = "app-server"
  }
}