module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "~> 21.0"
  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  enable_irsa = true

  addons = {
    coredns = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent = true
    }

    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    main = {
      name = "main-node-group"

      instance_types = ["t3.small"]

      min_size     = 2
      max_size     = 2
      desired_size = 2

      capacity_type = "ON_DEMAND"

      subnet_ids = var.subnet_ids

    }
  }

  tags = {
    Environment = "dev"
    Project     = "tic-tac-toe"
    ManagedBy   = "Terraform"
  }
}