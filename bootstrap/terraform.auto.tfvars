

# ---- GitHub OIDC Provider and IAM Role Configuration ----
oidc_url             = "https://token.actions.githubusercontent.com"
oidc_client_id_list  = ["sts.amazonaws.com"]
oidc_thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

iam_role_name   = "AWS_OIDC_ROLE_ARN"
iam_policy_name = "github_permission_policy"


