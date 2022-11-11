
################################################################################################
# More info at https://aws.amazon.com/blogs/containers/backup-and-restore-your-amazon-eks-cluster-resources-using-velero/
################################################################################################

resource "aws_s3_bucket" "velero" {
  bucket = "pierreraffavelero"
}

# Create IAM Roles for Service Accounts
# Velero performs a number of API calls to resources in EC2 and S3 to perform snapshots and save the backup to the S3 bucket. 
# The following IAM policy will grant Velero the necessary permissions.
module "velero_irsa_role" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "${var.company_name}-velero"
  attach_velero_policy  = true
  velero_s3_bucket_arns = [aws_s3_bucket.velero.arn]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["velero:velero"]
    }
  }
}
