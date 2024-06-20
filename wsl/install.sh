#!/bin/bash

set -euo pipefail

Port="${1:-22}"
ztarget='$HOME/.zsh'
export ZDOTDIR=$(eval echo $ztarget)

function step(){
  echo "$(tput setaf 10)$1$(tput sgr0)"
}

function info(){
  echo "$(tput setaf 14)$1$(tput sgr0)"
}

info "Running ubuntu script"

step "Create \$ZDOTDIR"
[ -d $ZDOTDIR ] || mkdir -p $ZDOTDIR
cat << EOF | tee -a $HOME/.zshenv
export ZDOTDIR="$ztarget"
skip_global_compinit=1
EOF
ln -sf $HOME/.zshenv $ZDOTDIR

step "Set locale"
sudo locale-gen en_US.UTF-8
sudo locale-gen zh_TW.UTF-8
export LC_ALL=en_US.UTF-8

step "Update all packages"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

step "Stop unattended upgrade"
sudo sed -E 's;APT::Periodic::Unattended-Upgrade "1"\;;APT::Periodic::Unattended-Upgrade "0"\;;g' -i /etc/apt/apt.conf.d/20auto-upgrades

step "Get useful commands"
sudo apt update
sudo apt install -y build-essential
sudo apt install -y gh curl zsh wget htop vim tree openssh-server lm-sensors \
                    cmake tmux python3-pip python3-venv python-is-python3 clang clang-tools

step "Set ssh port&key"
sudo sed -E 's;#?(Port ).*;\1'"$Port"';g' -i /etc/ssh/sshd_config
sudo service ssh restart
[ -d ~/.ssh ] || mkdir ~/.ssh
ssh-keygen -b 4096 -t rsa -f ~/.ssh/id_rsa -q -N "" <<< y
echo "" # newline

step "Change default shell"
sudo chsh -s /usr/bin/zsh ${USER}

step "Install chezmoi"
export PATH=$HOME/.local/bin:$PATH
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
chezmoi init zxkyjimmy --apply --force

step "Get Oh my tmux"
cd $HOME
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cd -

step "Set Time Zone"
sudo timedatectl set-timezone Asia/Taipei

step "Get Miniconda3"
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
bash miniconda.sh -b -u -p $HOME/.miniconda
# eval "$(${HOME}/.miniconda/bin/conda shell.bash hook)"
# conda init zsh
# conda config --set auto_activate_base false

step "Install Podman"
sudo apt update
sudo apt upgrade -y
sudo apt install -y podman
sudo sed -E 's;# unqualified-search-registries = \["example.com"\];unqualified-search-registries = \["docker.io"\];1' -i /etc/containers/registries.conf

if command -v nvidia-smi &> /dev/null; then
  info "Nvidia GPU is present!"
  step "Install CUDA and nvidia-container-toolkit"
  wsl/nvidia-container-toolkit.sh
else
  info "Nvidia GPU is not present...skip"
fi

step "clean up"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
sudo apt autoclean
