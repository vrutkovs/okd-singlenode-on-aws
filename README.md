# OKD 4.8 Single Node install on AWS UPI

This set of terraform scripts installs single node OKD 4.8 cluster. It uses AWS as a platform.
Installation method is User Provisioned Infrastructure - necessary resources created via Terraform
Note that repo was not yet updated to terraform 1.0 (ignition provider is missing), use 0.12.x.

This approach start a single bootstrap node, attaches two disks and writes bootstrap content to fist (root)
disk and master content to the other. Once bootstrap is complete the disks are swapped and the instance 
boots into a master/worker cluster. Necessary infra is created to support additional workers, which 
can be created via MachineSets.

This method still requires some manual intervention (scripting the changes would be appreciated).


## Howto

* Fill in `terraform.tfvars`
* `terraform plan && terraform apply -auto-approve`
* SSH on bootstrap node via public IP
* On first boot wait for FCOS be updated to OKD content: `journalctl -b -f -u release-image`
* After reboot wait for bootstrap to complete: `journalctl -b -f -u bootkube`
* Wait until master content is written to the other disk: `journalctl -b -f -u install-to-disk`
* Stop the instance, detach the disks and attach the second one as `/dev/xvda`, start the instance
* Terraform would copy `./kubeconfig` to the root of the repo, use it to watch cluster setup progress
* BUG: Route53 zone needs to be retagged, see `Degraded` message in `oc describe co ingress`:
  * `Name:<clustername>-<randomhash>-int` instead of `Name: <clustername>-int`
  * `kubernetes.io/cluster/<clustername>-<randomhash>:owned` instead of `kubernetes.io/cluster/<clustername>-<randomhash>:owned`
* `oc -n openshift-console get routes/console` would output console URL, `./kubeadmin-password` file would have `kubeadmin` user password
