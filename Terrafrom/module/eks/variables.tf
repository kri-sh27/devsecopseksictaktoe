variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "main-eks-cluster"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.36"
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS and Fargate"
  type        = list(string)
}