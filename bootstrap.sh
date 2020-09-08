

sudo su root

msg=$(cat /etc/os-release | grep PRETTY_NAME | grep 'Linux 10')

if [ -z $msg ]; then
    echo "OS has to be Debian GNU/Linux 10 (buster)"
    exit 1
fi


if [[ $(which docker) && $(docker --version) ]]; then
    docker run --gpus all nvidia/cuda:10.0-base nvidia-smi

    # build gpu bcnode image
    cd /tmp
    git clone https://github.com/trick77/bcnode-gpu-docker bcnode-gpu-docker && cd $_
    ./build-images.sh

    wget https://bc-ephemeral.s3.amazonaws.com/_easysync_db.zip && ./import-db.sh ./_easysync_db.zip

else
    echo "Install docker and nvidia-docker"

    apt update -y
    apt install -y git net-tools vim tmux lshw jq wget curl ca-certificates apt-transport-https gnupg2 software-properties-common unzip

    # install docker
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian buster stable"
    apt update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io
    systemctl start docker
    # end install docker

    # install nvidia driver
    apt install -y linux-headers-4.19.0-10-cloud-amd64

    export DEBIAN_FRONTEND=noninteractive
    cd /tmp; wget http://us.download.nvidia.com/tesla/440.33.01/NVIDIA-Linux-x86_64-440.33.01.run
    chmod +x NVIDIA-Linux-x86_64-440.33.01.run

    ./NVIDIA-Linux-x86_64-440.33.01.run -s

    ## nvidia-docker
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list

    apt-get update && apt-get install -y nvidia-container-toolkit
    systemctl restart docker

    # end install nvidia driver
    reboot # to pick up changes
fi
