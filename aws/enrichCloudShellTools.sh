#!/bin/bash
sudo dnf -y install bind-utils virt-what amazon-ec2-net-utils ansible yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform

