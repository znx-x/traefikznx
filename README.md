# TraefikZNX

Welcome to the **TraefikZNX** open source repository. This repository helps you setting up Wildcard SSL Certificates for your local area network using Cloudflare for domain management, Traefik, and Let's Encrypt. These certificates are free and auto-renewing. This repository was based on the tutorial released by [Techno Tim](https://www.youtube.com/@TechnoTim) and is meant to automate the process described on such tutorial, as well as to add some built-in advanced management scripts for Traefik.

## Pre Requisites
- Ubuntu 22.04+
- cUrl Installed
- Docker.io Installed
- Internal DNS Server (*tested with Pi-Hole*)
- Cloudflare API Token (*Linked to a domain*)

*This tool was developed and tested on a Proxmox VM running a Ubuntu 22.04 container. Will not work on Windows, and it hasn't been tested on macOS or any other Linux flavours.*

### Cloudflare API Token

Please make sure your API token is set up so it can **READ** your domain Zone and **EDIT** your domain DNS records. These are required for domain validation by Let's Encrypt and if not set up properly will mean that your certificates won't be issued.

## Installation

The installation process has been automated and can be called by using:
```shell
sudo bash install.sh
```
*Requires SUDO to work.*

The script will ask for your **Username**, **Password** (at the end), **Cloudflare API Token**, **Wildcard Domain**, and a **CA Server URL**. You can leave the **CA Server URL** if you don't know what it is or if you just want to use the default *Let's Encrypt* servers defined on `.env.urls`.

- **Username** - Your Traefik username
- **Password** - Your Traefik password
- **Cloudflare API Token** - API token to validate your domain with Cloudflare
- **Wildcard Domain** - The main domain you want the wildcard certificate issued to
- **CA Server URL** - The URL of the Certificate Authority server *leave blank if you don't know!*

After the installation is complete, the script will display your hashed password on the screen, and you will need to manually copy it into your `.env` file. You can edit your `.env` file by using `nano` or any other text editor:
```shell
nano .env
```

Place the hashed password in front of the `TRAEFIK_DASHBOARD_CREDENTIALS` variable. Your `.env` file should look something like this:
```shell
TRAEFIK_DASHBOARD_CREDENTIALS=user:$$2y$$05$$lSaEi.G.aIygyXRdiFpt7OqmUMW9QUG5I1N.j0bXoXxIjxQmoGOWu
```

### Setting Up Internal DNS Server

Once installed and running you will need to set up your internal DNS server to point to Traefik so you can make use of the SSL certificates. This process will change depending on the DNS server you are using, but if you are using **Pi-Hole** the process should look something like this:

**Step 1:** Go to your dashboard and look for the option **Local DNS** on your main menu, and under that, click on **DNS Records**.

**Step 2:** Create a new DNS [A/AAA] record with your wildcard domain used during the installation and the IP of the machine that your Traefik server is being hosted. Eg.:
```
Domain: local.example.com
IP Address: 192.168.0.100
```

**Step 3:** Now navigate to `Local DNS > CNAME Records` and create a new CNAME record using `traefik-dashboard` as a subdomain for your wildcard domain, and set the target domain as your A/AAA record above. Eg.:
```
Domain: traefik-dashboard.local.example.com
Target Domain: local.example.com
```

**Step 4:** By now you should be able to access your Traefik Dashboard via the https://traefik-dashboard.[YOUR-DOMAIN]/.

## Usage

If the installation went well, you should be able to call the `./traefikznx.sh` script as an executable script. All calls have arguments, so you will need to specify what script you want to execute when running `./traefikznx.sh`, for example:
```shell
./traefikznx.sh start
```

You can also use `./traefikznx.sh start-d` to start a detached container.

You have the following available commands:

- `start` - Builds and starts the Traefik container.
- `start-d` - Builds and starts a detached Traefik container.
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

To add a new service you will need to specify the `service_name`, the `domain` you want to use as your entry point, and the `backend_url` that given domain will point to. You will need to use just the domain string to describe the `domain`, but you will **NEED** to use the protocol, eg. `https://192.168.0.100:8080`, with the `backend_url`.

```shell
./traefikznx.sh add_service [service_name] [domain] [backend_url]
```

Example:
```shell
./traefikznx.sh add_service example local.example.com https://192.168.0.100:8080
```

### Remove Service

You can remove services by specifying the `service_name` with your call.

```shell
./traefikznx.sh rm_service example
```

This should remove the entry from your Traefik configuration file.

## Traefik Dashboard

By default, the installation will require a `traefik-dashboard` subdomain to be set up on your local DNS provider, but you can change that by modifying the `docker-compose.yml` file.

If no changes are made, once the DNS is configured, you should be able to access your Traefik Dashboard via the https://traefik-dashboard.[YOUR-DOMAIN]/.

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