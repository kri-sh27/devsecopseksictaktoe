# Find the existing ECR repository used by GitHub Actions


data "aws_ecr_repository" "app" {
  name = "my-app"
}


resource "aws_vpc" "myvpc" {
  cidr_block           = var.cidr_block
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "myvpc"
  }
}
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet_cidr_sub1
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                                     = "eks-public-subnet-1"
    "kubernetes.io/role/elb"                 = "1"
    "kubernetes.io/cluster/main-eks-cluster" = "shared"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet_cidr_sub2
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                                     = "eks-public-subnet-2"
    "kubernetes.io/role/elb"                 = "1"
    "kubernetes.io/cluster/main-eks-cluster" = "shared"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myigw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "eks-public-route-table"
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "websg" {
  name        = "websg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "websg"
  }
}

resource "aws_ecr_repository" "app" {
  name                 = "my-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "my-app"
  }
}
resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.websg.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]
  tags = {
    Name = "myalb"
  }
}
resource "aws_lb_target_group" "tg" {
  name        = "mytg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}


resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
# module "ecs" {
#   source = "./module/ecs"

#   vpc_id = aws_vpc.myvpc.id

#   private_subnets = [
#     aws_subnet.sub1.id,
#     aws_subnet.sub2.id
#   ]

#   sg_ecs           = aws_security_group.websg.id
#   alb_target_group = aws_lb_target_group.tg.arn

# }
module "eks" {
  source = "./module/eks"


  cluster_name       = "main-eks-cluster"
  kubernetes_version = "1.36"


  vpc_id = aws_vpc.myvpc.id

  subnet_ids = [
    aws_subnet.sub1.id,
    aws_subnet.sub2.id
  ]
  
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  value = data.aws_ecr_repository.app.repository_url
}

output "application_image_uri" {
  value = "${data.aws_ecr_repository.app.repository_url}:latest"
}


output "load_balancer_dns_name" {
  value = aws_lb.myalb.dns_name
}
