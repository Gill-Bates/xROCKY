![xROCKY Logo](./images/xrocky-logo_small.png)

# 🚀 xROCKY - A lightweight VPN with DNS Blocker 🛡️

![Docker](https://img.shields.io/badge/Docker-✓-blue?logo=docker)
![Alpine](https://img.shields.io/badge/Alpine_Linux-✓-brightgreen?logo=alpine-linux)
![Xray](https://img.shields.io/badge/Xray_Core-✓-success)
![Blocky](https://img.shields.io/badge/Blocky_DNS-✓-important)

A lightweight VPN solution with DNS blocking capabilities based on **Xray-core** and **Blocky**, running on Alpine Linux. 🏔️

> *xray* + *blocky* = `xROCKY`


## ✨ Features
- 🛡️ VPN with Xray-core: *Secure, private, and ultra-fast.*
- 🔐 Invisible to Detect: *Using Xray + VLESS + Reality + xtls-rprx-vision*
- 🚫 DNS blocking with Blocky: *Prevents tracking, ads, and malicious DNS queries.*
- 🪶 **Lightweight**: Built on Alpine Linux for minimal size and resource consumption.
- ⚙️ **xROCKY Manager**: A handy shell script to manage your users and configurations.

## 🎯 **Overview**
`xROCKY` combines the power of:
- [**Xray**](https://github.com/XTLS/Xray-core): A revolutionary VPN technology built to bypass firewalls and protect privacy.
- [**Blocky**](https://github.com/0xERR0R/blocky): A flexible DNS blocker for improved DNS security and filtering.

By leveraging the minimal **Alpine Linux** as the base image, xROCKY ensures that you get a **small, fast, and secure** image for deployment.

## 🛠️ Installation

1. Clone this repository
   ```bash
   git clone https://github.com/Gill-Bates/xROCKY.git
   cd xROCKY
   ```
2. Build the Docker Container:
   ```bash
   docker compose up -
   ```

## 🏗️ **Requirements**
- **Docker**: Ensure `docker` and `docker compose` is installed on your system.
- **Ports Open**: Port `443` (TCP) for the VPN must be available. You can choose a different port, but this is not recommenend.

---

## 📦 **Image Contents**
This project includes:
1. **Xray**: Installed from the [latest release](https://github.com/XTLS/Xray-core/releases).
2. **Blocky**: Installed from the [latest release](https://github.com/0xERR0R/blocky/releases).
3. **Utilities**:
   - `bash`, `curl`, `jq`, `nano`, `supervisor`, and others.
4. **Configurations**:
   - `blocky.yml` for DNS blocking.
   - `xray.json` for the VPN.
   - `supervisord.conf` to manage running processes.

## ⚙️ **xROCKY Manager**

> ⚠️ **Warning**: The setup is delivered with a default user and default secret. You must change this with the Manager before starting!

You call up the user manager from your Docker host as follows:

   ```bash
   docker exec -it xrocky-vpn xrocky-manager
   ```
> ℹ️ **Info**: Don't forget to restart your container after every change on the User Management!
> 
![xrocky-manager](./images/manager.gif)


## 👨‍💻 Maintainer
`giiibates` (aka GiIIBates)