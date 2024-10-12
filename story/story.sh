#!/bin/bash

# Load and print logo
source <(curl -s https://raw.githubusercontent.com/enyaselessar/logo/refs/heads/main/common.sh)
printLogo

# Step 1: Update and Upgrade VPS
printGreen "Updating and upgrading VPS..." && sleep 1
sudo apt update && sudo apt upgrade -y

# Step 2: Install Required Packages
printGreen "Installing required packages..." && sleep 1
sudo apt install -y wget curl lz4 jq

# Step 3: Install Go
printGreen "Installing Go..." && sleep 1
cd $HOME
ver="1.22.0"
wget "https://go.dev/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
go version

# Step 4: Download and Install Story Story-Geth Binary
printGreen "Downloading and installing Story Story-Geth binaries..." && sleep 1
cd $HOME
rm -rf bin
mkdir bin
cd bin
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3-b224fdf.tar.gz
tar -xvzf geth-linux-amd64-0.9.3-b224fdf.tar.gz
mv ~/bin/geth-linux-amd64-0.9.3-b224fdf/geth ~/go/bin/
[ ! -d "$HOME/.story/story" ] && mkdir -p "$HOME/.story/story"
[ ! -d "$HOME/.story/geth" ] && mkdir -p "$HOME/.story/geth"

# Step 5: Install Story
printGreen "Installing Story..." && sleep 1
cd $HOME
rm -rf story
git clone https://github.com/piplabs/story
cd story
git checkout v0.11.0
go build -o story ./client 
mv $HOME/story/story $HOME/go/bin/

# Step 6: Initialize the Iliad Network Node
printGreen "Initializing Iliad network node..." && sleep 1
$HOME/go/bin/story init --network iliad

# Step 7: Create and Configure systemd Service for Story-Geth
printGreen "Creating systemd service for Story-Geth..." && sleep 1
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=root
ExecStart=$HOME/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Step 8: Create and Configure systemd Service for Story
printGreen "Creating systemd service for Story..." && sleep 1
sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User=root
ExecStart=$HOME/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Step 9: Ask for Moniker and Update config.toml
printGreen "Please enter the moniker for your node (e.g., your node's name):" && sleep 1
read -r moniker

# Step 10: Update Ports in config.toml Based on User Input
printGreen "Please enter the starting port number (between 11 and 64). Default is 26:" && sleep 1
read -r start_port

# Default value check for port
if [ -z "$start_port" ]; then
  start_port=26
elif ! [[ "$start_port" =~ ^[0-9]+$ ]] || [ "$start_port" -lt 11 ] || [ "$start_port" -gt 64 ]; then
  printGreen "Invalid input. Please enter a number between 11 and 64."
  exit 1
fi

# Calculate new ports based on start_port
rpc_port=$((start_port * 1000 + 657))
p2p_port=$((start_port * 1000 + 656))
proxy_app_port=$((start_port * 1000 + 658))
prometheus_port=$((start_port * 1000 + 660))

# Update config.toml with new port values and moniker
config_path="/root/.story/story/config/config.toml"

# Update ports
sed -i "s|laddr = \"tcp://127.0.0.1:26657\"|laddr = \"tcp://127.0.0.1:$rpc_port\"|g" "$config_path"
sed -i "s|laddr = \"tcp://0.0.0.0:26656\"|laddr = \"tcp://0.0.0.0:$p2p_port\"|g" "$config_path"
sed -i "s|proxy_app = \"tcp://127.0.0.1:26658\"|proxy_app = \"tcp://127.0.0.1:$proxy_app_port\"|g" "$config_path"
sed -i "s|prometheus_listen_addr = \":26660\"|prometheus_listen_addr = \":$prometheus_port\"|g" "$config_path"

# Update moniker
sed -i "s|moniker = \"[^\"]*\"|moniker = \"$moniker\"|g" "$config_path"

printBlue "Configuration updated successfully in config.toml:" && sleep 1

printLine
echo -e "Moniker:        \e[1m\e[32m$moniker\e[0m"
echo -e "RPC Port:         \e[1m\e[32m$rpc_port\e[0m"
echo -e "P2P Port:       \e[1m\e[32m$p2p_port\e[0m"
echo -e "Proxy App Port:  \e[1m\e[32m$proxy_app_port\e[0m"
echo -e "Prometheus Port:  \e[1m\e[32m$prometheus_port\e[0m"
printLine
sleep 1


# Step 11: Update Persistent Peers and Seed in config.toml
printGreen "Fetching peers-seed and updating persistent_peers in config.toml..." && sleep 1
SEEDS="51ff395354c13fab493a03268249a74860b5f9cc@story-testnet-seed.itrocket.net:26656"
PEERS="2f372238bf86835e8ad68c0db12351833c40e8ad@story-testnet-peer.itrocket.net:26656,fa58ccd87f82aec19746b8908c30fd2a712122c3@212.192.222.42:26656,a932908520c8bf2514b0eadd1952e97b04e02813@194.163.167.132:26656,4e159edf6e7affa518bba93c0e25a2d7bd36e187@185.197.251.19:26656,3833efddd6665ffaf20950abad7c8bb4918c0161@65.109.111.234:26656,67630373dd14bd9cd2a5beb42d3ad3255b370aa3@194.163.133.213:26656,fcd591a5462974bf684ae596a87796ab56d7a64e@212.192.222.59:26656,3e0cde7382067bc449ec1ad979e136d5de774732@202.61.201.53:26656,2415dfb9dbf3b3ee77824697127aecab87d18598@176.9.54.69:26656,90161a7f82ce5dbfbed1a2a9d40d4103730cff0f@5.9.87.231:26656,1f4c8031c89661f214678ea5b6157a7a000d994f@109.199.100.6:26656"
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" $HOME/.story/story/config/config.toml

echo "Persistent peers and seed updated in $CONFIG_PATH."

# Step 12: Download genesis and addrbook
printGreen "Downloading genesis and addrbook..." && sleep 1
wget -O $HOME/.story/story/config/genesis.json https://server-3.itrocket.net/testnet/story/genesis.json
wget -O $HOME/.story/story/config/addrbook.json  https://server-3.itrocket.net/testnet/story/addrbook.json


# Step 13: Reload systemd, Enable, and Start Services
printGreen "Reloading systemd, enabling, and starting Story-Geth and Story services..." && sleep 1
sudo systemctl daemon-reload
sudo systemctl enable story-geth story
sudo systemctl start story-geth story

printGreen "Installation and setup complete!" && sleep 1
