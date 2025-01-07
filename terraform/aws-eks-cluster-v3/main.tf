
locals {
  cluster_name = "demo-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

resource "aws_ecr_repository" "repo" {
  name                 = "django-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

########## SECURITY GROUPS ##########
module "sgs" {
  source = "./security-groups"

  vpc_id = module.vpc.vpc_id
}

########## VPC ##########
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.17.0"

  name                 = "demo-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

########## EKS ##########
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.31"
  cluster_name    = local.cluster_name
  cluster_version = "1.31"

  # Optional
  cluster_endpoint_public_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets

  tags = {
    Environment = "demo"
    GithubRepo  = "kubernetes"
  }

  # workers_group_defaults = {
  #   root_volume_type = "gp2"
  # }

  # worker_groups = [
  #   {
  #     name                          = "worker-group-1"
  #     instance_type                 = "t2.small"
  #     additional_userdata           = "echo foo bar"
  #     asg_desired_capacity          = 2
  #     additional_security_group_ids = [module.sgs.worker_group_mgmt_sg_one_id]
  #   },
  #   {
  #     name                          = "worker-group-2"
  #     instance_type                 = "t2.medium"
  #     additional_userdata           = "echo foo bar"
  #     additional_security_group_ids = [module.sgs.worker_group_mgmt_sg_two_id]
  #     asg_desired_capacity          = 1
  #   },
  # ]
}

