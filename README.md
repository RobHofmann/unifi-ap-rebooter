# Unifi AP Rebooter

This project provides a PowerShell-based tool to schedule and reboot Unifi Access Points (APs) via the Unifi Controller API. The script runs in a Docker container and is designed to run on Linux.

> **Security Note:**  
> All sensitive credentials (controller URL, username, and password) are passed via environment variables. This project logs minimal sensitive information. In particular, login details are redacted in logs.

## Features

- **Scheduled Reboots:** Reboots APs based on a configurable schedule.
- **Automatic Session Refresh:** If the session cookie expires, the script automatically re-authenticates with the controller.
- **Linux Compatible:** Built to run in a Linux container using PowerShell Core.
- **Dockerized:** Easily deployed using Docker or Docker Compose.

## Configuration

Create a configuration file (e.g., `config.example.json`) to define your AP reboot schedule:

```json
{
  "00:11:22:33:44:55": {
    "name": "ExampleAP",
    "time": "12:00",
    "days": ["monday", "wednesday", "friday"]
  },
  "66:77:88:99:AA:BB": {
    "name": "AnotherAP",
    "time": "18:30",
    "days": ["tuesday", "thursday"]
  }
}
```

## Docker compose

Use the `docker-compose.yml` to run this project with docker compose.

## Docker Run

Use this command to run the container:

```bash
docker run -d \
  --name unifi-ap-rebooter \
  -e REBOOT_CONFIG_PATH=/config/config.example.json \
  -e UNIFI_CONTROLLER_URL=https://unifi.example.com \
  -e UNIFI_CONTROLLER_USER=YourUsername \
  -e UNIFI_CONTROLLER_PASSWORD=YourPassword \
  -e IGNORE_SSL_ERRORS=true \
  -v /path/to/your/config:/config \
  robhofmann/unifi-ap-rebooter:latest
```

## Liability

Use this software at your own risk. I take no responsibility.
