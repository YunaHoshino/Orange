# 🍊 Orange

<div align="center">

A lightweight, real-time system monitoring tool written in Bash

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)](https://www.gnu.org/software/bash/)

</div>

Orange provides a Terminal User Interface (TUI) to visualize critical system metrics, resource utilization, and service health without the overhead of complex monitoring frameworks.

## ✨ Features

- **📊 Real-time Resource Tracking** - Monitors CPU, RAM, Swap, and Disk usage with visual progress bars
- **🌐 Network Monitoring** - Calculates real-time RX/TX speeds and tracks total data transferred
- **🐳 Service Awareness** - Automatically detects Docker and common hosting panels (Pterodactyl, Pelican, cPanel)
- **🏥 Health Assessment** - Evaluates system state against thresholds to provide immediate status alerts
- **💻 System Information** - Displays hostname, OS, kernel, CPU model, cores, IP address, users, processes, TCP connections, uptime, and CPU temperature

## 📋 Requirements

### Required
- **Bash 4+**
- **awk** - for parsing `/proc` files
- **iproute2** - for the `ip` command to get network info

### Optional
- **sensors** (lm-sensors) - for CPU temperature monitoring
- **docker** - for Docker service status
- **ss** (iproute2) - for TCP connection counting

## 🚀 Installation

### Clone the repository

```bash
git clone https://github.com/YunaHoshino/Orange.git
cd Orange
```

### Make the script executable

```bash
chmod +x orange.sh
```

## 🎯 Usage

Run the script:

```bash
./orange.sh
```

The script will:
- Hide the terminal cursor
- Display a real-time TUI dashboard with system metrics
- Update every 5 seconds
- Clean up and restore cursor on exit (Ctrl+C)

## 🏥 Health Monitoring

Orange performs automated health checks during every iteration:
- **CPU**: Alert if usage exceeds 85%
- **RAM**: Alert if usage exceeds 85%
- **Disk**: Alert if root partition exceeds 90%
- **Docker**: Alert if the service is installed but stopped

## 📄 License

Orange is released under the **GNU General Public License Version 3 (GPLv3)**.

## 👩🏻‍💻 Credits

Created by [YunaHoshino](https://github.com/YunaHoshino)
