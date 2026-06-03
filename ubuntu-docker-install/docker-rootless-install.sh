sudo apt install systemd-container -y
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo rm /etc/apt/keyrings/docker.gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y -d
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
sleep 3
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
wait
sudo chmod +x /usr/local/bin/docker-compose
sudo systemctl disable --now docker.service docker.socket
sudo apt-get install -y uidmap
echo 'net.ipv4.ip_unprivileged_port_start=0' |sudo tee --append /etc/sysctl.conf
nonRootUser='dev2'
sudo useradd -m $nonRootUser
sudo usermod -aG docker $nonRootUser
sudo su - $nonRootUser -c "
    nonRootUser='dev2'
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod -R 700 ~/.ssh
    chmod 600 ~/.ssh/*
    #generate .pem for above user
    #keygen creation
    mkdir ~/keys
    ssh-keygen -N '' -f ~/keys/'$nonRootUser' -C '$nonRootUser';
    mv  ~/keys/"$nonRootUser" ~/keys/."$nonRootUser".pem
    cat ~/keys/"$nonRootUser".pub>~/.ssh/authorized_keys
"
sudo -s <<EOF
    nonRootUser='dev2'
    cp /home/$nonRootUser/keys/.$nonRootUser.pem $(pwd)
    ssh -i $(pwd)/."$nonRootUser".pem -o "StrictHostKeyChecking no" $nonRootUser@localhost "
        export FORCE_ROOTLESS_INSTALL=1
        curl -fsSL https://get.docker.com/rootless | sh
        wait
        echo 'PATH=/usr/bin:$PATH' | tee --append  ~/.bashrc
        echo 'DOCKER_HOST = unix:///run/user/'$(id -u)'/docker.sock' | tee --append  ~/.bashrc
        systemctl --user start docker
        systemctl --user enable docker
        loginctl enable-linger $nonRootUser
        rm -rf /home/$nonRootUser/keys
        rm -rf /home/$nonRootUser/.ssh
    "
EOF
rm -rf ~/.$nonRootUser.pem
echo "$(tput setab 2)$(tput setaf 0)Docker rootless successfully installed. On user dev2$(tput sgr 0)"
