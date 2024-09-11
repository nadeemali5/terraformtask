provider "aws" {
  region     = "us-west-2"  # Adjust as needed
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key

}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[0]
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[1]
  availability_zone = "us-west-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[0]
  availability_zone = "us-west-2c"
  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[1]
  availability_zone = "us-west-2d"
  tags = {
    Name = "private-subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-route-table"
  }
}

# Public Route Table Association for Public Subnets
resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "allow_all" {
  vpc_id = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_all"
  }

  #Another inbound & outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


## Target Group Creation
resource "aws_lb_target_group" "my_tg_a" { 
 name     = "target-group-a"
 port     = 80
 protocol = "HTTP"
 vpc_id   = aws_vpc.main.id
 health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"

 }  
 tags = {
    Name = "my-target-group"
 }
}



# Application Load Balancer Creation
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_all.id]
  subnets            = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
  idle_timeout        = 60
  tags = {
    Name = "app-lb"
  }
}

# Application Load Balancer Listner
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.my_tg_a.arn
      }
    }
  }
}



##Full Access Ec2 configuration
resource "aws_iam_role" "app_role" {
  name = "app_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_role_policy" {
  role       = aws_iam_role.app_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}



# Auto Scaling Launch Configuration
resource "aws_launch_configuration" "app" {
  name_prefix          = "app-"
  image_id             = "ami-0075013580f6322a1"  
  instance_type        = "t2.micro"
  security_groups      = [aws_security_group.allow_all.id]
  user_data            = <<-EOF
                            #!/bin/bash
                            sudo apt-get update
                            sudo apt-get install -y nginx
                            sudo systemctl start nginx
                            sudo systemctl enable nginx
                            echo '<!doctype html>
                            <html lang="en"><h1>Home page!</h1></br>
                            <h3>(Instance A)</h3>
                            </html>' | sudo tee /var/www/html/index.html
                            EOF
}






# Auto Scaling Group Creation
resource "aws_autoscaling_group" "app" {
  launch_configuration = aws_launch_configuration.app.id
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
  target_group_arns = [aws_lb_target_group.my_tg_a.arn]
}





# Auto Scaling Policy Scale out
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.app.name
}

#Auto Sclaing Policy Sclae In
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.app.name
}





