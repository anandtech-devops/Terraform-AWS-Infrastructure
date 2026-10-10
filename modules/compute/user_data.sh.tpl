#!/bin/bash
dnf install -y nginx
echo "<h1>Hello from ${env} - provisioned by Terraform</h1>" > /usr/share/nginx/html/index.html
systemctl enable --now nginx
