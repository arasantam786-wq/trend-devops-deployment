data "aws_instance" "workstation" {
  instance_id = "i-027e9679ee4604da4"
}

resource "aws_iam_role" "eks_cluster" {
  name = "trend-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "trend" {
  name     = "trend-eks"
  version  = "1.36"
  role_arn = aws_iam_role.eks_cluster.arn

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true

    public_access_cidrs = distinct([
      var.admin_cidr,
      "${data.aws_instance.workstation.public_ip}/32"
    ])
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
    aws_route.private_internet
  ]
}

resource "aws_security_group_rule" "jenkins_to_eks" {
  type                     = "ingress"
  description              = "Jenkins access to Kubernetes API"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.trend.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.jenkins.id
}

resource "aws_eks_access_entry" "terraform_admin" {
  cluster_name  = aws_eks_cluster.trend.name
  principal_arn = "arn:aws:iam::060651979375:role/trend-terraform-role"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_admin" {
  cluster_name  = aws_eks_cluster.trend.name
  principal_arn = aws_eks_access_entry.terraform_admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

output "eks_cluster_name" {
  value = aws_eks_cluster.trend.name
}
