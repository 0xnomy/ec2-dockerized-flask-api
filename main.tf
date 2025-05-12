terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.25.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # You can change this to your preferred region
}

# Create a security group that explicitly allows HTTP
resource "aws_security_group" "bookstore_sg" {
  name        = "bookstore-api-sg"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "bookstore-sg"
  }
}

# EC2 Instance
resource "aws_instance" "bookstore_server" {
  ami                    = "ami-0c9978668f8d55984"  # Amazon Linux 2 AMI in us-east-1
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.bookstore_sg.id]
  
  tags = {
    Name = "Web Server of Bookstore"
  }

  user_data = file("bootstrap.sh")
}

# Output the public DNS of the EC2 instance
output "bookstore_api_url" {
  value = "http://${aws_instance.bookstore_server.public_dns}"
  description = "URL of the Bookstore Web API"
}

# Output the frontend URL
output "bookstore_frontend_url" {
  value = "http://${aws_instance.bookstore_server.public_dns}/frontend"
  description = "URL of the Bookstore Frontend"
}