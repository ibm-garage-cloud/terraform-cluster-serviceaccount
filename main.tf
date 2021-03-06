provider "kubernetes" {
  config_path = var.cluster_config_file_path
}
provider "null" {}
provider "local" {}

locals {
  tmp_dir   = "${path.cwd}/.tmp"
  name_file = "${local.tmp_dir}/${var.service_account_name}.out"
}

resource "null_resource" "delete_namespace" {
  count  = var.create_namespace ? 1 : 0

  provisioner "local-exec" {
    command = "kubectl delete namespace ${var.namespace} --wait=true 1> /dev/null 2> /dev/null || exit 0"

    environment={
      KUBECONFIG = var.cluster_config_file_path
    }
  }
}

resource "kubernetes_namespace" "create" {
  depends_on = [null_resource.delete_namespace]
  count      = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "null_resource" "create_service_account" {
  depends_on = [kubernetes_namespace.create]

  provisioner "local-exec" {
    command = "kubectl create serviceaccount -n ${var.namespace} ${var.service_account_name} || exit 0"

    environment = {
      KUBECONFIG = var.cluster_config_file_path
    }
  }
}

resource "null_resource" "add_ssc_openshift" {
  depends_on = [null_resource.create_service_account]
  count      = var.cluster_type != "kubernetes" ? 1 : 0

  provisioner "local-exec" {
    command = "${path.module}/scripts/add-sccs-to-user.sh ${var.namespace} ${var.service_account_name} ${jsonencode(var.sscs)}"

    environment = {
      KUBECONFIG = var.cluster_config_file_path
    }
  }
}
