resource "aws_iam_role_policy" "jenkins_eks" {
  name = "trend-eks-describe"
  role = aws_iam_role.jenkins.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "eks:DescribeCluster"
      Resource = aws_eks_cluster.trend.arn
    }]
  })
}

resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = aws_eks_cluster.trend.name
  principal_arn = aws_iam_role.jenkins.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = aws_eks_cluster.trend.name
  principal_arn = aws_eks_access_entry.jenkins.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["trend"]
  }
}
