#!/bin/bash

set -e

BOOTSTRAP_DIR="/mnt/gpu-miner-bootstrap/"
mkdir -p $BOOTSTRAP_DIR

# has to run under root

function install_docker {
    if [[ $(which docker) && $(docker --version) ]]; then
        echo "docker is already installed"
    else
        apt-get update -y > /dev/null
        apt-get install -y ca-certificates apt-transport-https gnupg2 software-properties-common
        apt-get install -y unzip gcc make git net-tools vim tmux lshw jq wget curl  build-essential

        # install docker
        curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian buster stable"
        apt-get update -y  > /dev/null
        apt-get install -y docker-ce docker-ce-cli containerd.io
    fi
}

function install_nvdia_cuda {
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y install linux-headers-$(uname -r)

    cd $BOOTSTRAP_DIR;
    if [ ! -f "$BOOTSTRAP_DIR/NVIDIA-Linux-x86_64-440.33.01.run" ]; then
        wget http://us.download.nvidia.com/tesla/440.33.01/NVIDIA-Linux-x86_64-440.33.01.run
    fi
    chmod +x NVIDIA-Linux-x86_64-440.33.01.run

    if [[ $(which nvidia-smi) && $(nvidia-smi -L) ]]; then
        echo "nvidia cuda driver is already installed"
        nvidia-smi -L
    else
        ./NVIDIA-Linux-x86_64-440.33.01.run -s
    fi
}

function install_nvdia_docker_toolkit {
    if [[ $(which nvidia-container-toolkit) ]]; then
        echo "nvidia-container-toolkit is already installed"
    else
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list

        apt-get update && apt-get install -y nvidia-container-toolkit
    fi
}

function ensure_os_version {
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)

    if [ $distribution != "debian10" ]; then
        echo "OS has to be Debian GNU/Linux 10 (buster)"
        exit 1
    fi
}


function test_run_nvidia_cuda {
    docker run --gpus all nvidia/cuda:10.0-base nvidia-smi
}


function provision_gpu_docker {
    install_docker

    systemctl start docker

    install_nvdia_cuda

    install_nvdia_docker_toolkit

    reboot
}

ensure_os_version

if [[ $(which docker) && $(docker --version) && $(test_run_nvidia_cuda) ]]; then
    cd $BOOTSTRAP_DIR
    if [ ! -d "$BOOTSTRAP_DIR/bcnode-gpu-docker" ]; then
        git clone --depth 1 https://github.com/trick77/bcnode-gpu-docker bcnode-gpu-docker
    fi
    cd bcnode-gpu-docker
    time ./build-images.sh # 18 minutes

    time wget https://bc-ephemeral.s3.amazonaws.com/_easysync_db.zip -O /tmp/_easysync_db.zip # 10 minutes
    echo "yy" | ./import-db.sh /tmp/_easysync_db.zip

    # TODO: 1. inject the miner key in ./config
    #       2. start the miner

else
    provision_gpu_docker
fi
