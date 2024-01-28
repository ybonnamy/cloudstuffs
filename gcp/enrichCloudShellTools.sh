#!/bin/bash
sudo apt install -y awscli ansible python3-boto3
pip install requests "urllib3<2"  "Jinja2<3.1"
ansible-galaxy install -r ansible/requirements.yml
