#!/bin/bash

# Log function
log_event() {
    local message=$1
    local logfile=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$logfile"
}

log_event "Start: Installation script." "traefikznx_installation.log"

# Welcome message
echo -e "Welcome to Traefik Cert Scripts\nThis will install and run Traefik on your computer and set up an auto-renewing SSL certificate using Let's Encrypt and Cloudflare for your local network applications.\n"
echo -e "You will be prompted to type your password during the installation process.\n"

# Necessary user inputs
echo "Configuration Parameters"
echo "---------------------------------------------------------------------"

# Function to ask for a required input
ask_required() {
    local input
    local prompt=$1
    while true; do
        read -p "$prompt" input
        if [[ -z "$input" ]]; then
            echo "This field is required. Please enter a value."
        else
            break
        fi
    done
    echo "$input"
}

username=$(ask_required "Username*: ")
log_event "Installation Username: $username" "traefikznx_installation.log"
email=$(ask_required "E-Mail (Cloudflare)*: ")
log_event "Installation E-Mail: $email" "traefikznx_installation.log"
cloudflare_api=$(ask_required "Your Cloudflare API Token*: ")
log_event "Cloudflare API Token: $cloudflare_api" "traefikznx_installation.log"
wildcard_domain=$(ask_required "Wildcard Domain*: ")
log_event "Wildcard Domain: $wildcard_domain" "traefikznx_installation.log"
# Optional CA server input
read -p "CA Server URL (Leave Blank If Unsure): " ca_server
log_event "CA Server URL: $ca_server" "traefikznx_installation.log"
echo "---------------------------------------------------------------------"

# General system updates
log_event "Start: System update." "traefikznx_installation.log"
if sudo apt update && sudo apt upgrade -y; then
    log_event "Finish: System update." "traefikznx_installation.log"
else
    log_event "Error: System update failed." "traefikznx_installation.log"
    exit 1
fi

# Installs Docker
log_event "Start: Install Docker." "traefikznx_installation.log"
if sudo apt install -y docker.io; then
    log_event "Finish: Install Docker." "traefikznx_installation.log"
else
    log_event "Error: Installation of Docker failed." "traefikznx_installation.log"
    exit 1
fi

# Installs Docker Compose
log_event "Start: Install Docker Compose." "traefikznx_installation.log"
if sudo apt install -y docker-compose; then
    log_event "Finish: Install Docker Compose." "traefikznx_installation.log"
else
    log_event "Error: Installation of Docker Compose failed." "traefikznx_installation.log"
    exit 1
fi

# Installs Apache2 Utils
log_event "Start: Install Apache2-utils." "traefikznx_installation.log"
if sudo apt install -y apache2-utils; then
    log_event "Finish: Install Apache2-utils." "traefikznx_installation.log"
else
    log_event "Error: Installation of Apache2-utils failed." "traefikznx_installation.log"
    exit 1
fi

# Installs yq for managing services and routers inside /data/config.yml
log_event "Start: Install yq." "traefikznx_installation.log"
log_event "Start: Download yq." "traefikznx_installation.log"
sudo wget https://github.com/mikefarah/yq/releases/download/v4.43.1/yq_linux_amd64
log_event "Start: Move yq to /usr/bin/yq." "traefikznx_installation.log"
sudo mv yq_linux_amd64 /usr/bin/yq
log_event "Start: Chmod yq." "traefikznx_installation.log"
sudo chmod +x /usr/bin/yq
log_event "Finish: Install yq." "traefikznx_installation.log"

# Setup permissions for acme.json and traefikznx.sh
log_event "Start: Set file permissions for acme.json and traefikznx.sh." "traefikznx_installation.log"
if [ -f ./data/acme.json ] && [ -f traefikznx.sh ]; then
    sudo chmod 600 ./data/acme.json
    sudo chmod u+x traefikznx.sh
    log_event "Finish: Set file permissions for acme.json and traefikznx.sh." "traefikznx_installation.log"
else
    log_event "Error: Files for setting permissions not found." "traefikznx_installation.log"
    exit 1
fi

# Creates Docker network if not already created
log_event "Start: Create Docker network." "traefikznx_installation.log"
if docker network inspect proxy >/dev/null 2>&1 || docker network create proxy; then
    log_event "Finish: Create Docker network." "traefikznx_installation.log"
else
    log_event "Error: Docker network creation failed." "traefikznx_installation.log"
    exit 1
fi

# Creates .env file and adds the user-password pair variable
log_event "Start: Creates .env file with user-password pair." "traefikznx_installation.log"
echo "TRAEFIK_DASHBOARD_CREDENTIALS=$password_hash" > .env
log_event "Finish: Creates .env file with user-password pair." "traefikznx_installation.log"

# Write the Cloudflare token to cf_api_token.txt
log_event "Start: Write Cloudflare token file." "traefikznx_installation.log"
echo "$cloudflare_api" > ./cf_api_token.txt
log_event "Finish: Write Cloudflare token file." "traefikznx_installation.log"

# Check if a custom CA server was provided and update it
log_event "Start: Check and update CA Server URL." "traefikznx_installation.log"
if [[ -n "$ca_server" ]]; then
    if ./traefikznx.sh set_ca_server "$ca_server"; then
        log_event "Finish: Check and update CA Server URL." "traefikznx_installation.log"
    else
        log_event "Error: Failed to update CA Server URL." "traefikznx_installation.log"
        exit 1
    fi
else
    log_event "No CA server URL provided; skipping update." "traefikznx_installation.log"
fi

# Update email in traefik.yml
yq e -i ".certificatesResolvers.cloudflare.acme.email = \"$email\"" data/traefik.yml
log_event "Modified traefik.yml with email: $email" "traefikznx_installation.log"

# Update domains and rules in docker-compose.yml using yq for each label
yq e -i "(.services.traefik.labels[] | select(. == \"traefik.http.routers.traefik.rule=Host(\`traefik-dashboard.example.com\`)\") ) |= sub(\"example.com\", \"$wildcard_domain\")" docker-compose.yml
yq e -i "(.services.traefik.labels[] | select(. == \"traefik.http.routers.traefik-secure.rule=Host(\`traefik-dashboard.example.com\`)\") ) |= sub(\"example.com\", \"$wildcard_domain\")" docker-compose.yml
yq e -i "(.services.traefik.labels[] | select(. == \"traefik.http.routers.traefik-secure.tls.domains[0].main=example.com\") ) |= sub(\"example.com\", \"$wildcard_domain\")" docker-compose.yml
yq e -i ".services.traefik.labels[] |= (select(. == \"traefik.http.routers.traefik-secure.tls.domains[0].sans=*.example.com\") = \"traefik.http.routers.traefik-secure.tls.domains[0].sans=*.$wildcard_domain\")" docker-compose.yml
log_event "Modified docker-compose.yml with wildcard domain: $wildcard_domain" "traefikznx_installation.log"

# Generates user-password pair
echo ""
echo "Traefik Dashboard Password Generator"
echo "---------------------------------------------------------------------"
echo "Please type a password to use with your username on the Traefik"
echo "Dashboard. For security reasons, this step is not automated by this"
echo "script, and you will need to manually copy the output into your .env"
echo "file, placing it after TRAEFIK_DASHBOARD_CREDENTIALS=". You can use
echo "the 'nano .env' command or any other available text editor for that."
echo "---------------------------------------------------------------------"
echo $(htpasswd -nB $username) | sed -e s/\\$/\\$\\$/g
echo "---------------------------------------------------------------------"
echo ""
log_event "Encrypted password generated." "traefikznx_installation.log"

echo -e "Installation completed. Please don't forget to add the hashed password to your .env file before starting the service.\nYou can start Traefik by running ./traefikznx.sh start"
log_event "Finish: Installation script." "traefikznx_installation.log"
