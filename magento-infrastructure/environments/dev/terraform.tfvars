allowed_account_ids = ["336573577202"]
region              = "ap-southeast-1"
bastion_ami         = "ami-0c802847a7dd848c0"
org                 = "org"
division            = "devops"
app                 = "magento"
env                 = "dev"
vpc_cidr            = "10.0.0.0/16"
bastion_ssh_key     = "terraform"
ng_ssh_key          = "terraform"
instance_types      = ["t3a.medium", "t3.medium", "t2.medium"]
capacity_type       = "SPOT"
ng_desired_size     = 1
ng_min_size         = 1
ng_max_size         = 5
labels = {
  sponsor = "henrytran"
}

cluster_autoscaler_sa = "cluster-autoscaler-sa"