#------------------------------------------------------------------------------
# written by: Miguel Afonso
#             https://www.linkedin.com/in/mmafonso/
#
# date: Aug-2021
#
# usage: Add tls certs for EKS cluster load balancer
#------------------------------------------------------------------------------
module "cert_manager_irsa" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "{{ cookiecutter.terraform_aws_modules_iam }}"
  create_role                   = true
  role_name                     = "${local.name}-cert_manager-irsa"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cert_manager_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:cert-manager:cert-manager"]
}

data "template_file" "cert-manager-values" {
  template = file("${path.module}/templates/cert-manager-values.yaml.tpl")
  vars = {
    role_arn = module.cert_manager_irsa.iam_role_arn
  }
}

resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  version    = "{{ cookiecutter.terraform_helm_cert_manager }}"
  values = [
    data.template_file.cert-manager-values.rendered
  ]

  depends_on = [module.eks]
}

resource "aws_iam_policy" "cert_manager_policy" {
  name        = "${local.name}-cert-manager-policy"
  path        = "/"
  description = "Policy, which allows CertManager to create Route53 records"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "route53:GetChange",
        "Resource" : "arn:aws:route53:::change/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ],
        "Resource" : "arn:aws:route53:::hostedzone/*"
      },
      {
        "Effect" : "Allow",
        "Action" : "route53:ListHostedZonesByName",
        "Resource" : "*"
      }
    ]
  })
}