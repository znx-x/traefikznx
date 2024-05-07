# TraefikZNX

Welcome to the **TraefikZNX** open source repository. This repository helps you setting up Wildcard SSL Certificates for your local area network using Cloudflare for domain management, Traefik, and Let's Encrypt. These certificates are free and auto-renewing. This repository was based on the tutorial released by [Techno Tim](https://www.youtube.com/@TechnoTim) and is meant to automate the process described on such tutorial, as well as to add some built-in advanced management scripts for Traefik.

## Pre Requisites
- Ubuntu 22.04+
- cUrl Installed
- Docker.io Installed
- Cloudflare API Token (Linked to a Domain)

## Installation

The installation process has been automated and can be called by using:
```shell
sudo bash install.sh
```
*Requires SUDO to work.*

The script will ask for your **Username**, **Password**, **Cloudflare API Token**, **Wildcard Domain**, and a **CA Server URL**. You can leave the **CA Server URL** if you don't know what it is or if you just want to use the default *Let's Encrypt* servers defined on `.env.urls`.

- **Username** - Your Traefik username
- **Password** - Your Traefik password
- **Cloudflare API Token** - API token to validate your domain with Cloudflare
- **Wildcard Domain** - The main domain you want the wildcard certificate issued to
- **CA Server URL** - The URL of the Certificate Authority server *leave blank if you don't know!*

## Usage

If the installation went well, you should be able to call the `./traefikznx.sh` script as an executable script. All calls have arguments, so you will need to specify what script you want to execute when running `./traefikznx.sh`, for example:
```shell
./traefikznx.sh start
```

You have the following available commands:

- `start` - Builds and starts the Traefik container.
- `stop` - Stops the Traefik container.
- `restart` - Restarts the Traefik container. Can be used to refresh or reload if new configs aren't being applied automatically.
- `add_service [service_name] [domain] [backend_url]` - Adds a new service to the stack. Further information below.
- `rm_service [service_name]` - Removes an existing service from the stack.
- `set_server [production]/[staging]` - Toggles between the default production and staging servers.
- `set_custom_server [url]` - Sets a custom CA server URL.
- `backup` - Backup current settings and certificates.
- `backup_restore` - Retores settings and certificates using latest backup.
- `backup_clean` - Wipes any existing backup files.
- `rm_certificate` - Removes the existing certificate without restarting the container.

### Add/Remove Services

You can add and remove Name Services by using the `add_service` and `rm_service` commands. This will create a DNS bond between a specific **https** entry point and a service located in your local area network.

#### Add Service

To add a new service you will need to specify the `service_name`, the `domain` you want to use as your entry point, and the `backend_url` that given domain will point to. You will need to use the protocol, eg. `https://`, with both the `domain` and the `backend_url`.

```shell
./traefikznx.sh add_service [service_name] [domain] [backend_url]
```

Example:
```shell
./traefikznx.sh add_service example https://example.com https://192.168.0.100:8080
```

### Remove Service

You can remove services by specifying the `service_name` with your call.

```shell
./traefikznx.sh rm_service example
```

This should remove the entry from your Traefik configuration file.

## Logs & Debugging

The scripts will log events for debugging, and you can access them by using the commands below:

*General Events*
```shell
cat traefikznx.log
```

*Installation Evens*
```shell
cat traefikznx_installation.log
```

## Credits

This entire repository was based on the [tutorial](https://technotim.live/posts/traefik-3-docker-certificates/) published by [Techno Tim](https://www.youtube.com/@TechnoTim), and I have used some of the unaltered files provided in such tutorial. Thanks [Techno Tim](https://www.youtube.com/@TechnoTim)!