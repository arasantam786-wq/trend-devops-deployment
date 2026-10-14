resource "aws_iam_openid_connect_provider" "eks" {
  url            = aws_eks_cluster.trend.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  eks_oidc_host = replace(
    aws_eks_cluster.trend.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
}

resource "aws_iam_policy" "load_balancer" {
  name   = "trend-load-balancer-policy"
  policy = file("${path.module}/load-balancer-policy.json")
}

resource "aws_iam_role" "load_balancer" {
  name = "trend-load-balancer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.eks_oidc_host}:aud" = "sts.amazonaws.com"
          "${local.eks_oidc_host}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "load_balancer" {
  role       = aws_iam_role.load_balancer.name
  policy_arn = aws_iam_policy.load_balancer.arn
}

output "load_balancer_controller_role_arn" {
  value = aws_iam_role.load_balancer.arn
}
