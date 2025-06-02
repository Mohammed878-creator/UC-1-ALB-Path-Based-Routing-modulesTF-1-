#Provider
provider "aws" {
  region = "ca-central-1"
}
 
# VPC and Networking
resource "aws_vpc" "demo-vpc-uc1" {
cidr_block = var.vpc_cidr
  tags = {
    Name = "demo-vpc-uc1"
  }
}

#Creation INternet Gateway
resource "aws_internet_gateway" "gw" {
vpc_id = aws_vpc.demo-vpc-uc1.id
}

#Creation Public Subnet
resource "aws_subnet" "public" {
  count             = 3
vpc_id = aws_vpc.demo-vpc-uc1.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = element(["ca-central-1a", "ca-central-1b", "ca-central-1d"], count.index)
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

#Assigning Internet to Internet Gateway in Routes
resource "aws_route_table" "public" {
vpc_id = aws_vpc.demo-vpc-uc1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#Adding Public subnets in Subnet Association
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
 
# Creating Security Group from ALB 
resource "aws_security_group" "alb" {
  name   = "alb-sg"
vpc_id = aws_vpc.demo-vpc-uc1.id
 
  ingress {
    from_port   = 80
    to_port     = 80
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
 
resource "aws_security_group" "ec2" {
  name   = "ec2-sg"
vpc_id = aws_vpc.demo-vpc-uc1.id
 
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
security_groups = [aws_security_group.alb.id]
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
 
# EC2 Instances
resource "aws_instance" "app" {
  count                  = 3
  ami                    = "ami-08355844f8bc94f55"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[count.index].id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data              = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install nginx -y
    sudo systemctl start nginx
    sudo systemctl enable nginx
    sudo mkdir -p /var/www/html/{images,register}
    echo "Home Page $(hostname) Instance A" | sudo tee /var/www/html/index.html
    echo "Images Page $(hostname) Instance B" | sudo tee /var/www/html/images/index.html
    echo "Register Page $(hostname) Instance C" | sudo tee /var/www/html/register/index.html
  EOF
  tags = {
    Name = "app-instance-${count.index + 1}"
  }
}
 
# Creation of Application Load Balancer
resource "aws_lb" "demo_alb_uc1" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
security_groups = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}
 
resource "aws_lb_target_group" "groups" {
  count    = 3
  name     = "tg-${count.index}"
  port     = 80
  protocol = "HTTP"
vpc_id = aws_vpc.demo-vpc-uc1.id
}
 
resource "aws_lb_target_group_attachment" "attach" {
  count            = 3
  target_group_arn = aws_lb_target_group.groups[count.index].arn
target_id = aws_instance.app[count.index].id
  port             = 80
}
 
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.demo_alb_uc1.arn
  port              = "80"
  protocol          = "HTTP"
 
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Page not found"
      status_code  = "404"
    }
  }
}
 
# Path-based Routing Rules
resource "aws_lb_listener_rule" "home" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
 
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.groups[0].arn
  }
 
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}
 
resource "aws_lb_listener_rule" "images" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200
 
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.groups[1].arn
  }
 
  condition {
    path_pattern {
      values = ["/images*"]
    }
  }
}
 
resource "aws_lb_listener_rule" "register" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 300
 
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.groups[2].arn
  }
 
  condition {
    path_pattern {
      values = ["/register*"]
    }
  }
}