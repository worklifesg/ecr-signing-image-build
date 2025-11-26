resource "aws_kms_key" "signing_key" {
  description              = "Asymmetric key for container signing"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_4096"
  deletion_window_in_days  = 7
}

resource "aws_kms_alias" "signing_key_alias" {
  name          = "alias/ecr-signing-key"
  target_key_id = aws_kms_key.signing_key.key_id
}
