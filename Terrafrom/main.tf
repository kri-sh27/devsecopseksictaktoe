# Find the existing ECR repository used by GitHub Actions


# data "aws_ecr_repository" "app" {
#   name = "my-app"
# }

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


  vpc_id             = aws_vpc.myvpc.id
   private_subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]
}

  # subnet_ids = [
  #   aws_subnet.sub1.id,
  #   aws_subnet.sub2.id
  # ]



output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "application_image_uri" {
  value = "${aws_ecr_repository.app.repository_url}:latest"
}


output "load_balancer_dns_name" {
  value = aws_lb.myalb.dns_name
}


# Private subnets for EKS Fargate
resource "aws_subnet" "private1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet_cidr_private1
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "eks-private-subnet-1"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/main-eks-cluster" = "shared"
  }
}

resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet_cidr_private2
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "eks-private-subnet-2"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/main-eks-cluster" = "shared"
  }
}

# NAT gateway in the first public subnet
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "eks-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.sub1.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "eks-nat"
  }
}

# Route private subnet traffic through NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "eks-private-route-table"
  }
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}


# Discover the existing EKS cluster's OIDC provider.
data "aws_eks_cluster" "main" {
  name = module.eks.cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# IAM permissions for the AWS Load Balancer Controller.
resource "aws_iam_policy" "load_balancer_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/aws-load-balancer-controller-iam-policy.json")
}

# Allow only the controller's Kubernetes service account to assume this role.
data "aws_iam_policy_document" "load_balancer_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "main-eks-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

# Helm provider connects to the already-created EKS cluster.
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.main.certificate_authority[0].data
    )

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", "ap-south-1"
      ]
    }
  }
}

# Install the AWS Load Balancer Controller.
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      region      = "ap-south-1"
      vpcId       = aws_vpc.myvpc.id

      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"

        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.load_balancer_controller.arn
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.load_balancer_controller,
    module.eks
  ]
}
