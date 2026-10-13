
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa           = true
  endpoint_public_access = true


  access_entries = {
  github_actions = {
    principal_arn = "arn:aws:iam::929897439921:role/eks-2048-terraform-githubactions"

    policy_associations = {
      deployment_access = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}

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

  fargate_profiles = {
    application = {
      name = "main-application-fargate"

      selectors = [
        {
          namespace = "tic-tac-toe"
        }
      ]

    aws_load_balancer_controller = {
      name = "aws-load-balancer-controller"

      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "app.kubernetes.io/name" = "aws-load-balancer-controller"
          }
        }
      ]

      subnet_ids = var.private_subnet_ids
    }


      subnet_ids = var.private_subnet_ids
    }

    kube_system = {
      name = "main-kube-system-fargate"

      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "k8s-app" = "kube-dns"
          }
        }
      ]

      subnet_ids = var.private_subnet_ids
    }
  }

  tags = {
    Environment = "dev"
    Project     = "tic-tac-toe"
    ManagedBy   = "Terraform"
  }
}
