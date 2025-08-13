data "aws_ssm_parameter" "github_trust_role_arn" {
  name = "/i2508/oidc/github_trust_role_arn"
}