data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.name_prefix}-aws-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-aws-lb-controller-role" })
}

# Official AWS Load Balancer Controller IAM policy — pin the version to match
# the Helm chart/controller image version you deploy. Fetched from:
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/<controller-tag>/docs/install/iam_policy.json
# Do not hand-edit; replace wholesale when the controller version changes.
resource "aws_iam_policy" "lb_controller" {
  name   = "${var.name_prefix}-aws-lb-controller-policy"
  policy = file("${path.module}/iam_policy.json")

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-aws-lb-controller-policy" })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}