# install docker
echo "----------------------------------------------"
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo chmod 666 /var/run/docker.sock
sudo usermod -aG docker ${USER}

# install docker-compose
sudo apt-get update
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

mkdir openvpn
cd openvpn

# create docker-compose file
touch docker-compose.yaml
cat <<EOT >> docker-compose.yaml
version: '2'
services:
  openvpn:
    cap_add:
     - NET_ADMIN
    image: kylemanna/openvpn:2.4
    container_name: openvpn
    ports:
     - "1194:1194/udp"
    restart: always
    volumes:
     - ./openvpn-data/conf:/etc/openvpn
EOT

# initialize config and certificates (one-time)
docker-compose run --rm openvpn ovpn_genconfig -u udp://VPN.SERVERNAME.COM
docker-compose run --rm openvpn ovpn_initpki
# run openvpn server
docker-compose up -d openvpn

export CLIENTNAME="yashraj"
docker-compose run --rm openvpn easyrsa build-client-full $CLIENTNAME

# get ovpn file for user
docker-compose run --rm openvpn ovpn_getclient $CLIENTNAME > $CLIENTNAME.ovpn
