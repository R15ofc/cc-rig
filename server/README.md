# RIG Server Scripts

These scripts are for the real server PC/Mac/Linux host that runs RIG Hub.

## Install

```sh
mkdir -p ~/cc-rig-server
cd ~/cc-rig-server
curl -fsSLO https://raw.githubusercontent.com/R15ofc/cc-rig/main/server/install-rig-server.sh
curl -fsSLO https://raw.githubusercontent.com/R15ofc/cc-rig/main/server/startup-rig-hub.sh
chmod +x install-rig-server.sh startup-rig-hub.sh
./install-rig-server.sh
```

## Start

```sh
./startup-rig-hub.sh
```

The script prints the exact local and LAN URLs. On the current server machine:

```text
http://192.168.31.21:8000
```

If port `8000` is already used by an existing healthy RIG Hub, the script exits successfully and prints the same URLs instead of starting a second copy.
