#!/bin/bash

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print error message
print_error() {
  echo -e "${RED}$1${NC}" >&2
}

# Function to print success message
print_success() {
  echo -e "${GREEN}$1${NC}"
}

# Function to print info message
print_info() {
  echo -e "${CYAN}$1${NC}"
}

# X architecture detection function
x_architecture() {
  local arch
  case "$(uname -m)" in
    'i386' | 'i686') arch='32' ;;
    'amd64' | 'x86_64') arch='64' ;;
    'armv5tel') arch='arm32-v5' ;;
    'armv6l')
      arch='arm32-v6'
      grep Features /proc/cpuinfo | grep -qw 'vfp' || arch='arm32-v5'
      ;;
    'armv7' | 'armv7l')
      arch='arm32-v7a'
      grep Features /proc/cpuinfo | grep -qw 'vfp' || arch='arm32-v5'
      ;;
    'armv8' | 'aarch64') arch='arm64-v8a' ;;
    'mips') arch='mips32' ;;
    'mipsle') arch='mips32le' ;;
    'mips64')
      arch='mips64'
      lscpu | grep -q "Little Endian" && arch='mips64le'
      ;;
    'mips64le') arch='mips64le' ;;
    'ppc64') arch='ppc64' ;;
    'ppc64le') arch='ppc64le' ;;
    'riscv64') arch='riscv64' ;;
    's390x') arch='s390x' ;;
    *)
      print_error "Error: The architecture is not supported."
      return 1
      ;;
  esac
  echo "$arch"
}

# Hysteria architecture detection
hys_architecture() {
    case "$(uname -m)" in
        i386 | i686) echo "386" ;;
        x86_64) grep -q avx /proc/cpuinfo && echo "amd64-avx" || echo "amd64" ;;
        armv5*) echo "armv5" ;;
        armv7* | arm) echo "arm" ;;
        aarch64) echo "arm64" ;;
        mips) echo "mipsle" ;;
        riscv64) echo "riscv64" ;;
        s390x) echo "s390x" ;;
        *) echo "Unsupported architecture: $(uname -m)";;
    esac
}

# Update Xray core for an existing node
update_xray() {
    print_info "Enter the node directory name:" && read -r node_directory
    if [ ! -d "/opt/marznode/$node_directory/xray" ]; then
        print_error "Node directory not found: /opt/marznode/$node_directory"
        return 1
    fi
    print_info "Which version of Xray-core do you want? (e.g., 1.8.24) (leave blank for latest): "
    read -r version
    version=${version:-latest}
    arch=$(x_architecture)
    cd "/opt/marznode/$node_directory/xray" || return 1
    if [[ $version == "latest" ]]; then
        wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$arch.zip"
    else
        wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/v$version/Xray-linux-$arch.zip"
    fi
    if unzip -o xray.zip; then
        rm xray.zip
        mv -v xray "$node_directory-core"
        print_success "Xray core updated to $version"
        docker compose -f "/opt/marznode/$node_directory/docker-compose.yml" restart -t 0
    else
        print_error "Failed to update Xray core."
    fi
}

# Remove an existing node completely
remove_node() {
    print_info "Enter the node directory name to remove:" && read -r node_directory
    if [ -d "/opt/marznode/$node_directory" ]; then
        docker compose -f "/opt/marznode/$node_directory/docker-compose.yml" down -t 0
        rm -rf "/opt/marznode/$node_directory"
        print_success "Node $node_directory removed."
    else
        print_error "Directory not found: /opt/marznode/$node_directory"
    fi
}

# Select desired action
print_info "Select an action:" && \
echo "1) Install new node" && \
echo "2) Update/downgrade Xray version of an existing node" && \
echo "3) Remove a node" && \
read -rp "Enter choice [1-3]: " action

case "$action" in
    1) print_info "Proceeding with new node installation." ;;
    2) update_xray; exit ;;
    3) remove_node; exit ;;
    *) print_error "Invalid choice"; exit 1 ;;
esac

# Installing necessary packages
print_info "Installing necessary packages..."
print_info "DON'T PANIC IF IT LOOKS STUCK!"
sudo apt-get update
sudo apt-get install curl socat git wget unzip make golang -y

# Docker installation
if ! command -v docker &> /dev/null; then
    trap 'echo "Ctrl+C was pressed but the script will continue."' SIGINT
    curl -fsSL https://get.docker.com | sh || { print_error "Something went wrong! Did you interrupt the Docker update? If so, no problem. Are you trying to install Docker on an IR server? Try setting DNS."; }
    trap - SIGINT
    clear
fi

print_info "Checking if Docker is installed..."
if ! command -v docker &> /dev/null; then
  print_error "Docker could not be found, please install Docker."
  exit 1
else
  print_success "Docker installation found!"
fi

# Folder name
print_info "Set a name for node directory (leave blank for a random name - not recommended): "
read -r node_directory
node_directory=${node_directory:-node$(openssl rand -hex 1)}

# clean up 
print_info "directory set to: $node_directory"
print_info "Removing existing directories and files..."
rm -rf "/opt/marznode/$node_directory" &> /dev/null

# Setting path
sudo mkdir -p /opt/marznode/$node_directory
sudo mkdir -p /opt/marznode/$node_directory/xray
sudo mkdir -p /opt/marznode/$node_directory/sing-box
sudo mkdir -p /opt/marznode/$node_directory/hysteria

# Port setup
while true; do
  print_info "Enter the SERVICE PORT value (default 53042): "
  read -r service
  service=${service:-53042}
  break
done

# Certificate setup
print_info "Please paste the content of the Client Certificate, press ENTER on a new line when finished: "

cert=""
while IFS= read -r line; do
  if [[ -z $line ]]; then
    break
  fi
  cert+="$line\n"
done

echo -e "$cert" | sudo tee /opt/marznode/$node_directory/client.pem > /dev/null

# xray
print_info "Which version of xray core do you want? (e.g., 1.8.24) (leave blank for latest): "
read -r version
xversion=${version:-latest}

# sing box
print_info "Which version of sing-box core do you want? (e.g., 1.10.3) (leave blank for latest): "
read -r version
latest=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep '"tag_name"' | cut -d '"' -f 4)
sversion=${version:-$latest}

# hysteria
print_info "Which version of hysteria core do you want? (e.g., 2.6.0) (leave blank for latest): "
read -r version
latest=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name"' | cut -d '"' -f 4)
hversion=${version:-$latest}
hversion=${hversion#app/v}

# Fetching xray core and setting it up
arch=$(x_architecture)
cd "/opt/marznode/$node_directory/xray"

wget -O config.json "https://raw.githubusercontent.com/mikeesierrah/ez-node/main/etc/xray.json"

print_info "Fetching Xray core version $xversion..."

if [[ $xversion == "latest" ]]; then
  wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$arch.zip"
else
  wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/v$xversion/Xray-linux-$arch.zip"
fi

if unzip xray.zip; then
  rm xray.zip
  mv -v xray "$node_directory-core"
else
  print_error "Failed to unzip xray.zip."
  exit 1
fi

print_success "Success! xray installed"

# bulding sing-box
cd /opt/marznode/$node_directory/sing-box
wget -O config.json "https://raw.githubusercontent.com/mikeesierrah/ez-node/main/etc/sing-box.json"
echo $sversion
wget -O sing.zip "https://github.com/SagerNet/sing-box/archive/refs/tags/v${sversion#v}.zip"
unzip sing.zip
cd ./sing-box-${sversion#v}
# TAGS="with_gvisor,with_quic,with_dhcp,with_wireguard,with_ech,with_utls,with_reality_server,with_acme,with_clash_api,with_v2ray_api,with_grpc" make
go build -v -trimpath -ldflags "-X github.com/sagernet/sing-box/constant.Version=${sversion#v} -s -w -buildid=" -tags with_gvisor,with_dhcp,with_wireguard,with_reality_server,with_clash_api,with_quic,with_utls,with_ech,with_v2ray_api,with_grpc ./cmd/sing-box
chmod +x ./sing-box
mv sing-box /opt/marznode/$node_directory/sing-box/$node_directory-box
cd ..
rm sing.zip
rm -rf ./sing-box-${sversion#v}

print_success "Success! sing-box installed"

# Fetching hysteria core and setting it up
cd /opt/marznode/$node_directory/hysteria
wget -O config.yaml "https://raw.githubusercontent.com/mikeesierrah/ez-node/main/etc/hysteria.yaml"
arch=$(hys_architecture)
wget -O $node_directory-teria "https://github.com/apernet/hysteria/releases/download/app/v$hversion/hysteria-linux-$arch"
chmod +x ./$node_directory-teria

# Get enable status for each component
print_info "Do you want to enable xray (y/n)"
read -r answer
x_enable=$( [[ "$answer" =~ ^[Yy]$ ]] && echo "True" || echo "False" )

print_info "Do you want to enable sing-box (y/n)"
read -r answer
sing_enable=$( [[ "$answer" =~ ^[Yy]$ ]] && echo "True" || echo "False" )

print_info "Do you want to enable hysteria (y/n)"
read -r answer
hys_enable=$( [[ "$answer" =~ ^[Yy]$ ]] && echo "True" || echo "False" )

# Defining env docker path
ENV="/opt/marznode/$node_directory/.env"
DOCKER="/opt/marznode/$node_directory/docker-compose.yml"

# Setting up env
cat << EOF > "$ENV"
SERVICE_ADDRESS=0.0.0.0
SERVICE_PORT=$service
INSECURE=True

XRAY_ENABLED=$x_enable
XRAY_EXECUTABLE_PATH=/opt/marznode/$node_directory/xray/$node_directory-core
XRAY_ASSETS_PATH=/opt/marznode/$node_directory/xray
XRAY_CONFIG_PATH=/opt/marznode/$node_directory/xray/config.json
#XRAY_VLESS_REALITY_FLOW=xtls-rprx-vision
XRAY_RESTART_ON_FAILURE=True
XRAY_RESTART_ON_FAILURE_INTERVAL=0

HYSTERIA_ENABLED=$hys_enable
HYSTERIA_EXECUTABLE_PATH=/opt/marznode/$node_directory/hysteria/$node_directory-teria
HYSTERIA_CONFIG_PATH=/opt/marznode/$node_directory/hysteria/config.yaml

SING_BOX_ENABLED=$sing_enable
SING_BOX_EXECUTABLE_PATH=/opt/marznode/$node_directory/sing-box/$node_directory-box
SING_BOX_CONFIG_PATH=/opt/marznode/$node_directory/sing-box/config.json
#SING_BOX_RESTART_ON_FAILURE=True
#SING_BOX_RESTART_ON_FAILURE_INTERVAL=5

SSL_KEY_FILE=./server.key
SSL_CERT_FILE=./server.cert
SSL_CLIENT_CERT_FILE=/opt/marznode/$node_directory/client.pem

#DEBUG=True
#AUTH_GENERATION_ALGORITHM=xxh128
EOF

print_success ".env file has been created successfully."

# Setting up docker-compose.yml
cat << EOF > $DOCKER
services:
  marznode:
    image: dawsh/marznode:latest
    restart: always
    network_mode: host
    command: [ "sh", "-c", "sleep 10 && python3 marznode.py" ]
    env_file: .env
    volumes:
      - /opt/marznode/$node_directory:/opt/marznode/$node_directory
EOF
print_success "docker-compose.yml has been created successfully."

#Setting up control script 
cat << 'EOF' > /usr/local/bin/marznode
#!/bin/bash
DEFAULT_DIR="/opt/marznode"
DIR="$DEFAULT_DIR/${1:-}"
COMMAND="$2"

cd "$DIR" || { echo "Directory not found: $DIR"; echo "Usage: marznode <node-name> restart | start | stop"; exit 1; }

case "$COMMAND" in
    restart) docker compose restart -t 0 ;;
    start) docker compose up -d ;;
    stop) docker compose down -t 0 ;;
    *) echo "Usage: marznode <node-name> restart | start | stop"; exit 1 ;;
esac
EOF

sudo chmod +x /usr/local/bin/marznode

print_success "Script installed successfully at /usr/local/bin/marznode"

cd "/opt/marznode/$node_directory" || { print_error "Something went wrong! Couldn't enter $node_directory directory"; exit 1; }
docker compose up -d --remove-orphans


