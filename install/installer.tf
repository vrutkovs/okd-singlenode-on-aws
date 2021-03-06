locals {
#  infrastructure_id = "${var.infrastructure_id != "" ? "${var.infrastructure_id}" : "${var.clustername}-${random_id.clusterid.hex}"}"
  infrastructure_id = var.infrastructure_id
}

resource "null_resource" "openshift_installer" {
  provisioner "local-exec" {
    command = "oc adm release extract -a ${var.openshift_pull_secret} --command='openshift-install' ${var.openshift_payload} --to ${path.module}"
  }

}

resource "null_resource" "openshift_client" {
  provisioner "local-exec" {
    command = "oc adm release extract -a ${var.openshift_pull_secret} --command='oc' ${var.openshift_payload} --to ${path.module}"
  }
}

resource "null_resource" "aws_credentials" {
  provisioner "local-exec" {
    command = "mkdir -p ~/.aws"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.aws_credentials.rendered}' > ~/.aws/credentials"
  }
}

data "template_file" "aws_credentials" {
  template = <<-EOF
[default]
aws_access_key_id = ${var.aws_access_key_id}
aws_secret_access_key = ${var.aws_secret_access_key}
EOF
}


data "template_file" "install_config_yaml" {
  template = <<-EOF
apiVersion: v1
baseDomain: ${var.domain}
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 1
metadata:
  name: ${var.clustername}
networking:
  clusterNetworks:
  - cidr: ${var.cluster_network_cidr}
    hostPrefix: ${var.cluster_network_host_prefix}
  machineCIDR:  ${var.vpc_cidr_block}
  networkType: OVNKubernetes
  serviceNetwork:
  - ${var.service_network_cidr}
platform:
  aws:
    region: ${var.aws_region}
bootstrapInPlace:
  installationDisk: /dev/whatever
pullSecret: '${file(var.openshift_pull_secret)}'
sshKey: ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBI54TLk2HagnSAI06HcksarHAVOYeqaIz9GMH6lxDa3SUbZ4+jw5hfVVlprTRmtNm9jTRB1Is15H5CHr9UT+8ZQ= vrutkovs@localhost.localdomain
EOF
}


resource "local_file" "install_config" {
  content  =  data.template_file.install_config_yaml.rendered
  filename =  "${path.module}/install-config.yaml"
}

resource "null_resource" "generate_manifests" {
  triggers = {
    install_config =  data.template_file.install_config_yaml.rendered
  }

  depends_on = [
    local_file.install_config,
    null_resource.aws_credentials,
    null_resource.openshift_installer,
  ]

  provisioner "local-exec" {
    command = "rm -rf ${path.module}/temp"
  }

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/temp"
  }

  provisioner "local-exec" {
    command = "mv ${path.module}/install-config.yaml ${path.module}/temp"
  }

  provisioner "local-exec" {
    command = "${path.module}/openshift-install --dir=${path.module}/temp create manifests"
  }
}

# because we're providing our own control plane machines, remove it from the installer
resource "null_resource" "manifest_cleanup_control_plane_machineset" {
  depends_on = [
    null_resource.generate_manifests
  ]

  triggers = {
    install_config =  data.template_file.install_config_yaml.rendered
    local_file     =  local_file.install_config.id
  }

  provisioner "local-exec" {
    command = "rm -f ${path.module}/temp/openshift/99_openshift-cluster-api_master-machines-*.yaml"
  }
}

# remove these machinesets, we will rewrite them using the security group and subnets that we created
resource "null_resource" "manifest_cleanup_worker_machineset" {
  depends_on = [
    null_resource.generate_manifests
  ]

  triggers = {
    install_config =  data.template_file.install_config_yaml.rendered
    local_file     =  local_file.install_config.id
  }

  provisioner "local-exec" {
    command = "rm -f ${path.module}/temp/openshift/99_openshift-cluster-api_worker-machines*.yaml"
  }
}

#redo the worker machineset
resource "local_file" "worker_machineset" {
  count           = length(var.aws_worker_availability_zones)

  depends_on = [
    null_resource.manifest_cleanup_worker_machineset
  ]

  file_permission = "0644"
  filename        = "${path.module}/temp/openshift/99_openshift-cluster-api_worker-machineset-${count.index}.yaml"
  content         = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${local.infrastructure_id}
  name: ${local.infrastructure_id}-worker-${element(var.aws_worker_availability_zones, count.index)}
  namespace: openshift-machine-api
spec:
  replicas: 0
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${local.infrastructure_id}
      machine.openshift.io/cluster-api-machineset: ${local.infrastructure_id}-worker-${element(var.aws_worker_availability_zones, count.index)}
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: ${local.infrastructure_id}
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: ${local.infrastructure_id}-worker-${element(var.aws_worker_availability_zones, count.index)}
    spec:
      metadata:
        creationTimestamp: null
      providerSpec:
        value:
          ami:
            id: ${var.ami}
          apiVersion: awsproviderconfig.openshift.io/v1beta1
          blockDevices:
          - ebs:
              iops: ${var.aws_worker_root_volume_iops}
              volumeSize: ${var.aws_worker_root_volume_size}
              volumeType: ${var.aws_worker_root_volume_type}
          credentialsSecret:
            name: aws-cloud-credentials
          deviceIndex: 0
          iamInstanceProfile:
            id: ${local.infrastructure_id}-worker-profile
          instanceType: ${var.aws_worker_instance_type}
          kind: AWSMachineProviderConfig
          metadata:
            creationTimestamp: null
          placement:
            availabilityZone: ${element(var.aws_worker_availability_zones, count.index)}
            region: ${var.aws_region}
          publicIp: null
          securityGroups:
          - filters:
            - name: tag:Name
              values:
              - ${local.infrastructure_id}-worker-sg
          subnet:
            filters:
            - name: tag:Name
              values:
              - ${local.infrastructure_id}-private-${element(var.aws_worker_availability_zones, count.index)}
          tags:
          - name: kubernetes.io/cluster/${local.infrastructure_id}
            value: owned
          userDataSecret:
            name: worker-user-data
EOF
}

# build the bootstrap ignition config
resource "null_resource" "generate_ignition_config" {
  depends_on = [
    null_resource.manifest_cleanup_control_plane_machineset,
    local_file.worker_machineset,
  ]

  triggers = {
    install_config                   =  data.template_file.install_config_yaml.rendered
    local_file_install_config        =  local_file.install_config.id
  }

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/temp"
  }

  provisioner "local-exec" {
    command = "rm -rf ${path.module}/temp/_manifests ${path.module}/temp/_openshift"
  }

  provisioner "local-exec" {
    command = "cp -r ${path.module}/temp/manifests ${path.module}/temp/_manifests"
  }

  provisioner "local-exec" {
    command = "cp -r ${path.module}/temp/openshift ${path.module}/temp/_openshift"
  }

  provisioner "local-exec" {
    command = "${path.module}/openshift-install --dir=${path.module}/temp create single-node-ignition-config"
  }

  provisioner "local-exec" {
    command = "${path.module}/openshift-install --dir=${path.module}/temp create ignition-configs"
  }
}

resource "null_resource" "cleanup" {
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${path.module}/temp"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/openshift-install"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/oc"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/kubectl"
  }
}

data "local_file" "bootstrap_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename =  "${path.module}/temp/bootstrap-in-place-for-live-iso.ign"
}

data "local_file" "master_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename =  "${path.module}/temp/master.ign"
}

data "local_file" "worker_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename =  "${path.module}/temp/worker.ign"
}

data "local_file" "cluster_infrastructure" {
  depends_on = [
    null_resource.generate_manifests
  ]

  filename =  "${path.module}/temp/manifests/cluster-infrastructure-02-config.yml"
}

resource "null_resource" "get_auth_config" {
  depends_on = [null_resource.generate_ignition_config]
  provisioner "local-exec" {
    when    = create
    command = "cp ${path.module}/temp/auth/* ${path.root}/ "
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm ${path.root}/kubeconfig ${path.root}/kubeadmin-password "
  }
}
