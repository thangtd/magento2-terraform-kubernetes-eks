output "efs_csi_driver_role" {
  value = aws_iam_role.efs_csi_driver_role.arn
}

output "efs_csi_driver_policy" {
  value = aws_iam_policy.efs_csi_driver_policy.arn
}

output "efs_sg_id" {
  value = aws_security_group.efs_sg.id
}

output "efs-file-system-id" {
  value = aws_efs_file_system.efs_for_eks_cluster.id
}
