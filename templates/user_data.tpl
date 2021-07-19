#!/bin/bash
sudo mkfs -t xfs ${docker_storage_device_name}
sudo mkdir -p /var/lib/docker
sudo mount -o prjquota ${docker_storage_device_name} /var/lib/docker

echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config
echo ECS_ENGINE_AUTH_TYPE=dockercfg >> /etc/ecs/ecs.config
echo 'ECS_ENGINE_AUTH_DATA={"https://index.docker.io/v1/": { "auth": "${dockerhub_token}", "email": "${dockerhub_email}"}}' >> /etc/ecs/ecs.config

sed -i s/OPTIONS/#OPTIONS/ /etc/sysconfig/docker
echo 'OPTIONS="--default-ulimit nofile=1024:4096 --storage-opt overlay2.size=${docker_storage_size}G"' >> /etc/sysconfig/docker
sudo service docker restart

# Append addition user-data script
${additional_user_data_script}
