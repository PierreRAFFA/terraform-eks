# Gets a token to connect to the cluster
# Used to create aws auth at the cluster level
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = terraform.workspace
  cluster_version = "1.22"

  cluster_endpoint_private_access = false
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }

    kube-proxy = {}
    aws-ebs-csi-driver = {}
    
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  create_kms_key = true
  cluster_encryption_config = [{
    resources = ["secrets"]
  }]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Allow access from control plane to webhook port of AWS load balancer controller
  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
  }
  
  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
    instance_type = var.default_instance_type
    instance_market_options = {
      market_type = "spot"
    }
    update_launch_template_default_version = true
    iam_role_additional_policies = [
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ]
  }

  self_managed_node_groups = {

    # Used to run api apps
    applications-v4 = {
      pre_bootstrap_user_data = <<-EOT
      echo "hello"
      EOT

      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=spot --max-pods=35'"

      post_bootstrap_user_data = <<-EOT
      cd /tmp
      sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
      sudo systemctl enable amazon-ssm-agent
      sudo systemctl start amazon-ssm-agent
      echo "SSM agent installed"
      export USE_MAX_PODS=false
      EOT

      min_size     = 3
      max_size     = 6
      desired_size = 4
    }
  }

  # EKS Managed Node Group(s)
  # eks_managed_node_group_defaults = {
  #   disk_size      = 50
  #   instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
  # }

  # eks_managed_node_groups = {
  #   blue = {}
  #   green = {
  #     min_size     = 1
  #     max_size     = 10
  #     desired_size = 1

  #     instance_types = ["t3.large"]
  #     capacity_type  = "SPOT"
  #   }
  # }

  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::583444921015:role/eks-master"
      username = "eks-master"
      groups   = ["system:masters"]
    },{
      rolearn  = "arn:aws:iam::583444921015:role/eks-read"
      username = "eks-read"
      groups   = ["view"]
    },
  ]

  # aws_auth_users = [
  #   {
  #     userarn  = "arn:aws:iam::583444921015:user/deployer"
  #     username = "deployer"
  #     groups   = ["system:masters"]
  #   }
  # ]

  # aws_auth_accounts = [
  #   "777777777777",
  #   "888888888888",
  # ]

  tags = {
    Environment = terraform.workspace
    Terraform   = "true"
  }
}