#!/bin/bash

# Log function
log_event() {
    local message=$1
    local logfile=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$logfile"
}

# Imports Environment Variables
if [ -f .env.urls ]; then
    export $(cat .env.urls | xargs)
fi

# Starts Traefik container
function start {
    log_event "Function start called." "traefikznx.log"
    docker compose up --force-recreate
    log_event "Traefik container started." "traefikznx.log"
}

# Stops Traefik container
function stop {
    log_event "Function stop called." "traefikznx.log"
    docker compose down
    log_event "Traefik container stopped." "traefikznx.log"
}

# Restarts Traefik container (Update/Refresh)
function restart {
    log_event "Function restart called." "traefikznx.log"
    docker compose restart traefik
    log_event "Traefik container restarted." "traefikznx.log"
}

# Adds a new service to the stack
# Args: <service_name> <domain> <backend_url>
# Eg.: ./traefikznx add_service example https://example.com https://192.168.0.100:8080
function add_service {
    log_event "Function add_service called." "traefikznx.log"
    local service_name=$1
    local domain=$2
    local backend_url=$3
    backup
    yq e ".http.services.${service_name}.loadBalancer.servers[+].url = \"$backend_url\"" -i ./data/config.yml
    yq e ".http.routers.${service_name}.entryPoints[0] = \"https\"" -i ./data/config.yml
    yq e ".http.routers.${service_name}.rule = \"Host(\`${domain}\`)\"" -i ./data/config.yml
    yq e ".http.routers.${service_name}.middlewares[0] = \"https-redirectscheme\"" -i ./data/config.yml
    yq e ".http.routers.${service_name}.tls = {}" -i ./data/config.yml
    yq e ".http.routers.${service_name}.service = \"$service_name\"" -i ./data/config.yml
    echo "Service ${service_name} added."
    log_event "Added service: $service_name with domain $domain and backend URL $backend_url." "traefikznx.log"
    restart
    log_event "Traefik container restarted." "traefikznx.log"
}

# Removes a service from the stack if it exists
# Args: <service_name>
# Eg.: ./traefikznx rm_service example
function rm_service {
    log_event "Function rm_service called." "traefikznx.log"
    local service_name=$1
    
    # Check if the service exists in the configuration
    local service_exists=$(yq e ".http.services.${service_name}" ./data/config.yml)
    local router_exists=$(yq e ".http.routers.${service_name}" ./data/config.yml)
    
    if [[ -z "$service_exists" && -z "$router_exists" ]]; then
        echo "Service ${service_name} does not exist. No changes made."
        log_event "Service $service_name does not exist. No changes made." "traefikznx.log"
        return 1  # Exit the function with an error status
    fi

    backup
    log_event "Backup created." "traefikznx.log"
    yq d -i ./data/config.yml "http.services.${service_name}"
    yq d -i ./data/config.yml "http.routers.${service_name}"
    echo "Service ${service_name} removed."
    log_event "Removed service: $service_name." "traefikznx.log"
    restart
    log_event "Traefik container restarted." "traefikznx.log"
}

# Toggles the environment between staging and production
# Args: <env>
# Eg.: ./traefikznx set_server production
function set_server {
    log_event "Function set_server called." "traefikznx.log"
    local env=$1
    local ca_server_url
    backup

    case "$env" in
        production)
            ca_server_url=$LE_PRODUCTION_URL
            ;;
        staging)
            ca_server_url=$LE_STAGING_URL
            ;;
        *)
            echo "Invalid server environment. Use 'production' or 'staging'."
            log_event "Invalid server URL argument entered: $env." "traefikznx.log"
            exit 1
            ;;
    esac

    if [[ -z "$ca_server_url" ]]; then
        echo "CA server URL not defined for $env."
        log_event "Server URL not defined." "traefikznx.log"
        exit 1
    fi

    yq e ".certificatesResolvers.cloudflare.acme.caServer = \"$ca_server_url\"" -i ./data/traefik.yml
    echo "Environment set to $env with CA server: $ca_server_url"
    log_event "Environment set to $env with CA server: $ca_server_url" "traefikznx.log"
    reset_acme_json
    restart
    log_event "Traefik container restarted." "traefikznx.log"
}


# Sets a custom CA server using the environment variable directly
function set_custom_server {
    log_event "Function set_custom_server called." "traefikznx.log"
    local ca_server_url=$1
    if [[ -z "$ca_server_url" ]]; then
        echo "No CA server URL provided."
        log_event "Server URL not defined." "traefikznx.log"
        exit 1
    fi
    backup
    yq e ".certificatesResolvers.cloudflare.acme.caServer = \"$ca_server_url\"" -i ./data/traefik.yml
    echo "CA server updated to $ca_server_url."
    log_event "CA server updated to $ca_server_url." "traefikznx.log"
    reset_acme_json
    restart
    log_event "Traefik container restarted." "traefikznx.log"
}


# Creates a backup of relevant files
function backup {
    log_event "Function backup called." "traefikznx.log"
    echo "Backing up all configurations..."
    cp ./data/config.yml ./data/config.yml.backup
    cp ./data/traefik.yml ./data/traefik.yml.backup
    cp ./data/acme.json ./data/acme.json.backup
    cp ./cf_api_token ./cf_api_token.backup
    echo "All configurations backed up."
    log_event "All configurations backed up." "traefikznx.log"
}

# Restores and restarts the application using the latest backup files
function backup_restore {
    log_event "Function backup_restore called." "traefikznx.log"
    echo "Checking for backup files..."
    if [[ -f ./data/config.yml.backup && -f ./data/traefik.yml.backup && -f ./data/acme.json.backup && -f ./cf_api_token.backup ]]; then
        echo "Restoring configurations from backup..."
        cp ./data/config.yml.backup ./data/config.yml
        cp ./data/traefik.yml.backup ./data/traefik.yml
        cp ./data/acme.json.backup ./data/acme.json
        cp ./cf_api_token.backup ./cf_api_token
        echo "Configurations restored."
        log_event "Backup: Configurations restored." "traefikznx.log"
        restart
        log_event "Traefik container restarted." "traefikznx.log"
    else
        echo "Failed to restore: one or more backup files are missing."
    fi
}

# Removes any backup files in the system
function backup_clean {
    log_event "Function backup_clean called." "traefikznx.log"
    echo "This will permanently delete all backup files."
    read -p "Are you sure you want to proceed? (yes/no): " confirmation
    if [[ "$confirmation" =~ ^[Yy]es$ ]]; then
        # Check for the existence of backup files before deleting
        if [[ -f ./data/config.yml.backup || -f ./data/traefik.yml.backup || -f ./data/acme.json.backup || -f ./cf_api_token.backup ]]; then
            echo "Deleting backup files..."
            rm -f ./data/config.yml.backup
            rm -f ./data/traefik.yml.backup
            rm -f ./data/acme.json.backup
            rm -f ./cf_api_token.backup
            echo "Backup files deleted."
            log_event "Backup: Files deleted." "traefikznx.log"
        else
            echo "No backup files found to delete."
            log_event "Backup: Couldn't find backup files." "traefikznx.log"
        fi
    else
        echo "Backup deletion canceled."
        log_event "Backup: User cancelled operation." "traefikznx.log"
    fi
}

# Removes the contents of acme.json to wipe out any current certificates
function rm_certificate {
    log_event "Function rm_certificate called." "traefikznx.log"
    echo "Removing all current certificates..."
    echo "{}" > ./data/acme.json
    log_event "Current Certificate have been removed." "traefikznx.log"
}

# Main switch case to handle operations
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    add_service)
        add_service "$2" "$3" "$4"
        ;;
    rm_service)
        rm_service "$2"
        ;;
    set_environment)
        set_environment "$2"
        ;;
    set_ca_server)
        set_ca_server "${!2}"
        ;;
    backup)
        backup
        ;;
    backup_restore)
        backup_restore
        ;;
    backup_clean)
        backup_clean
        ;;
    *)
        echo "Usage: $0 {start|stop|add_service|rm_service|set_environment|set_ca_server|backup|backup_restore|backup_clean}"
        exit 1
esac