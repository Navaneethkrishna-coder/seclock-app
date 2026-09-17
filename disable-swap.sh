#!/bin/bash
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
