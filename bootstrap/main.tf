locals {
  public_endpoints = var.publish_strategy == "External" ? true : false
}

resource "aws_s3_bucket" "ignition" {
  acl = "private"

  tags = merge(
    {
      "Name" = "${var.cluster_id}-"
    },
    var.tags,
  )

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_s3_bucket_object" "ignition" {
  bucket  = aws_s3_bucket.ignition.id
  key     = "bootstrap.ign"
  content = var.ignition
  acl     = "private"

  server_side_encryption = "AES256"

  tags = merge(
    {
      "Name" = "${var.cluster_id}"
    },
    var.tags,
  )

  lifecycle {
    ignore_changes = all
  }
}

data "ignition_config" "redirect" {
  replace {
    source = "s3://${aws_s3_bucket.ignition.id}/bootstrap.ign"
  }
}

resource "aws_iam_instance_profile" "bootstrap" {
  name = "${var.cluster_id}-profile"

  role = aws_iam_role.bootstrap.name
}

resource "aws_iam_role" "bootstrap" {
  name = "${var.cluster_id}-role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF

  tags = merge(
    {
      "Name" = "${var.cluster_id}-role"
    },
    var.tags,
  )
}

resource "aws_iam_role_policy" "bootstrap" {
  name = "${var.cluster_id}-policy"
  role = aws_iam_role.bootstrap.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:AttachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:AuthorizeSecurityGroupIngress",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:CreateSecurityGroup",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:CreateTags",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:CreateVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DeleteSecurityGroup",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DeleteVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DetachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:ModifyInstanceAttribute",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:ModifyVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:RevokeSecurityGroupIngress",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:RevokeSecurityGroupIngress",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:AddTags",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:AttachLoadBalancerToSubnets",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:CreateListener",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:CreateLoadBalancer",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:CreateLoadBalancerPolicy",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:CreateLoadBalancerListeners",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:CreateTargetGroup",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:ConfigureHealthCheck",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:DeleteListener",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:DeleteLoadBalancer",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:DeleteLoadBalancerListeners",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:DeleteTargetGroup",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:DeregisterTargets",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:DetachLoadBalancerFromSubnets",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:ModifyListener",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:ModifyTargetGroup",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:ModifyTargetGroupAttributes",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:RegisterTargets",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "kms:DescribeKey",
      "Resource": "*"
    },
    {
      "Action" : [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::*",
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_instance" "bootstrap" {
  ami = var.ami

  iam_instance_profile        = aws_iam_instance_profile.bootstrap.name
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  user_data                   = replace(data.ignition_config.redirect.rendered, "2.1.0", "3.1.0")
  # data.ignition_config.redirect.rendered
  vpc_security_group_ids      = var.vpc_security_group_ids
  associate_public_ip_address = local.public_endpoints

  lifecycle {
    # Ignore changes in the AMI which force recreation of the resource. This
    # avoids accidental deletion of nodes whenever a new OS release comes out.
    ignore_changes = [ami]
  }

  tags = merge(
    {
    "Name" = "${var.cluster_id}"
    },
    var.tags,
  )

  # TODO: Use aws_ebs_volume / aws_volume_attachment to be able to swap those via terraform
  root_block_device {
    volume_type = var.volume_type
    volume_size = var.volume_size
    iops        = var.volume_type == "io1" ? var.volume_iops : 0
    tags        = merge(
      {
      "Name" = "${var.cluster_id}-bootstrap-vol"
      },
      var.tags,
    )
  }
}

resource "aws_lb_target_group_attachment" "bootstrap" {
  // Because of the issue https://github.com/hashicorp/terraform/issues/12570, the consumers cannot use a dynamic list for count
  // and therefore are force to implicitly assume that the list is of aws_lb_target_group_arns_length - 1, in case there is no api_external
  count = local.public_endpoints ? var.target_group_arns_length : var.target_group_arns_length - 1

  target_group_arn = var.target_group_arns[count.index]
  target_id        = aws_instance.bootstrap.private_ip
}
