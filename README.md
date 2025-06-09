# NOTICE

This is script is under developement so issues and problems are common - if you had any problems kindly issue it

# Easy Node

This script sets up nodes for the Marzneshin and Marzban panels.

## Features

- Supports a variety of CPU architectures
- Allows for custom core versions for Sing-box Hysteria Xray
- Provides a control script for managing nodes (start, stop, restart)
- Uses a single directory for easier management

## Installation

**Run the script as root:**

For Marzneshin (replace `YOUR_GITHUB_USERNAME` with your actual username):
```bash
bash <(curl -Ls https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/ez-node/main/marznode.sh)
```

For Marzban (replace `YOUR_GITHUB_USERNAME` with your actual username):
```bash
bash <(curl -Ls https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/ez-node/main/marzban-node.sh)
```

## Directory Structure

**Marznode:**
```
/opt/marznode
        └── your-node-name
                ├── .env
                ├── docker-compose.yml
                ├── client.pem
                |
                ├── sing-box
                │    └── sing-box core
                ├── xray
                │    ├── xray core
                │    └── xray assets
                └── hysteria
                    └── hysteria core
```

**Marzban-node:**
```
/opt/marzban-node
        └── your-node-name
                ├── .env
                ├── docker-compose.yml
                ├── client.pem
                |
                └── xray core
```

## Control Script

This script also installs a control script in your system's PATH.

### Usage:

For Marznode:
```bash
marznode <node-name> restart | start | stop
```

For Marzban-node:
```bash
marzban-node <node-name> restart | start | stop
```
## Donation

If you'd like to show your appreciation, please donate $5 to someone in need.
