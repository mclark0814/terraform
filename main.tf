## Terraform configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.19.0"
    }
  }
}
provider "aws" {
  region                  = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
 # profile                 = "myprofile"
}
terraform {
  cloud {
    organization = "www-mclark"

    workspaces {
        name     = "Project_19"
    }
  }  
}
# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main"
  }
}
#Create public subnet #1
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "public-subnet1"
  }
}
#Create public subnet #2
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "public-subnet2"
  }
}
#Create private subnet #1
resource "aws_subnet" "private_subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1c"
  tags = {
    Name = "private-subnet1"
  }
}
#Create private subnet #2
resource "aws_subnet" "private_subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1d"
  tags = {
    Name = "private-subnet2"
  }
}
#Create internet gateway
resource "aws_internet_gateway" "proj19_internet_gateway" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}
#Create route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main_public_rt"
  }
}
#Create route
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.proj19_internet_gateway.id
}
#Create route table association
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rt.id
}
#Create security group
resource "aws_security_group" "main_sg" {
  name        = "public_sg"
  description = "main security group"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.63/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#Create AWS AMI Ubuntu server
data "aws_ami" "server_ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
#Create AWS EC2 Key Pair
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "kp" {
  key_name   = "MyKey"       # Create a "myKey" to AWS!!
  public_key = tls_private_key.pk.public_key_openssh
  provisioner "local-exec" { # Create a "myKey.pem" to your computer!!
    command = "echo '${tls_private_key.pk.private_key_pem}' > ./MyKey.pem"
  }
}
#Create AWS EC2 instance #1
resource "aws_instance" "project19web1" {
  instance_type = "t2.micro"
  ami           = data.aws_ami.server_ami.id
  tags = {
    Name = "project19web1"
  }
  key_name               = aws_key_pair.kp.id
  vpc_security_group_ids = [aws_security_group.main_sg.id]
  subnet_id              = aws_subnet.public_subnet1.id
  root_block_device {
    volume_size = 10
  }
}
#Create AWS EC2 instance #2
resource "aws_instance" "project19web2" {
  instance_type = "t2.micro"
  ami           = data.aws_ami.server_ami.id
  tags = {
    Name = "project19web2"
  }
  key_name               = aws_key_pair.kp.id
  vpc_security_group_ids = [aws_security_group.main_sg.id]
  subnet_id              = aws_subnet.public_subnet1.id
  root_block_device {
    volume_size = 10
  }
}
# Create aws_lb_target_group
resource "aws_lb_target_group" "target-group" {
  name        = "first-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id
}
# Creating ALB
resource "aws_lb" "application-lb" {
  name               = "first-alb"
  internal           = false
  ip_address_type    = "ipv4"
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.main_sg.id}"]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
  tags = {
    Name = "First-alb"
  }
}
#Creating Listener
resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.application-lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.target-group.arn
    type             = "forward"
  }
}
#ec2 attachment
resource "aws_lb_target_group_attachment" "ec2_attach" {
  count            = length(aws_instance.project19web1)
  target_group_arn = aws_lb_target_group.target-group.arn
  target_id        = aws_instance.project19web1.id
}
resource "aws_db_subnet_group" "default" {
  name       =  "main"
  subnet_ids = ["${aws_subnet.private_subnet1.id}", "${aws_subnet.private_subnet2.id}"]
}
resource "aws_db_instance" "database-instance1" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  db_name              = "mydb"
  username             = "user1"
  password             = "project19"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = "main"
  skip_final_snapshot  = true
  availability_zone = "us-east-1c"
}