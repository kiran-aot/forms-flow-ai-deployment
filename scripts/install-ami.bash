#!/bin/bash

# Function to determine the IP address
get_ip_address() {
    ipadd=$(hostname -I | awk '{print $1}')
    if [ "$(uname)" == "Darwin" ]; then
        ipadd=$(ipconfig getifaddr en0)
    fi
}

# Function to set the appropriate Docker Compose file based on the architecture
set_docker_compose_file() {
    docker_compose_file='docker-compose.yml'
    if [ "$(uname -m)" == "arm64" ]; then
        docker_compose_file='docker-compose-arm64.yml'
    fi
}

# Define the array of valid Docker versions
validVersions=("25.0.3" "25.0.2" "25.0.1" "25.0.0" "24.0.9" "24.0.8" "24.0.7" "24.0.6" "24.0.5" "24.0.4" "24.0.3" "24.0.2" "24.0.1" "24.0.0" "23.0.6" "23.0.5" "23.0.4" "23.0.3" "23.0.2" "23.0.1" "23.0.0" "20.10.24" "20.10.23")

# Run the docker -v command and capture its output
docker_info=$(docker -v 2>&1)

# Extract the Docker version using string manipulation
docker_version=$(echo "$docker_info" | awk '{print $3}' | tr -d ,)

# Display the extracted Docker version
echo "Docker version: $docker_version"

# Check if the user's version is in the list
versionFound=false
for version in "${validVersions[@]}"; do
    if [ "$docker_version" == "$version" ]; then
        versionFound=true
        break
    fi
done

# If the user's version is not found, display a warning but skip prompting for continuation
if [ "$versionFound" == false ]; then
    echo "This Docker version is not tested! Proceeding anyway."
fi

# Function to check if the web API is up
isUp() {
    while true; do
        HTTP=$(curl -LI "http://$ip_add:5001" -o /dev/null -w "%{http_code}" -s)
        if [ "$HTTP" == "200" ]; then
            echo "formsflow.ai is successfully installed."
            exit 0
        else
            echo "Finishing setup."
            sleep 6
        fi
    done
}

# Function to find the IPv4 address
find_my_ip() {
    ipadd=$(hostname -I | awk '{print $1}')
    if [ "$(uname)" == "Darwin" ]; then
        ipadd=$(ipconfig getifaddr en0)
    fi
    ip_add=$ipadd
    echo "Using detected IPv4 address: $ip_add"
}

# Function to set common properties
set_common_properties() {
    WEBSOCKET_ENCRYPT_KEY="giert989jkwrgb@DR55"
    KEYCLOAK_BPM_CLIENT_SECRET="e4bdbd25-1467-4f7f-b993-bc4b1944c943"
    export WEBSOCKET_ENCRYPT_KEY
    export KEYCLOAK_BPM_CLIENT_SECRET
}

# Function to start Keycloak
keycloak() {
    cd ../docker-compose/
    if [ -f "$1/.env" ]; then
        rm "$1/.env"
    fi
    echo KEYCLOAK_START_MODE=start-dev >> .env
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d keycloak
    sleep 5
    KEYCLOAK_URL="http://$ip_add:8080"
    export KEYCLOAK_URL
}

# Function to start forms-flow-forms
forms_flow_forms() {
    FORMIO_DEFAULT_PROJECT_URL="http://$ip_add:3001"
    echo "FORMIO_DEFAULT_PROJECT_URL=$FORMIO_DEFAULT_PROJECT_URL" >> "$1/.env"
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d forms-flow-forms
    sleep 5
}

# Function to start forms-flow-web
forms_flow_web() {
    BPM_API_URL="http://$ip_add:8000/camunda"
    echo "BPM_API_URL=$BPM_API_URL" >> "$1/.env"
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d forms-flow-web
}

# Function to start forms-flow-bpm
forms_flow_bpm() {
    FORMSFLOW_API_URL="http://$ip_add:5001"
    WEBSOCKET_SECURITY_ORIGIN="http://$ip_add:3000"
    SESSION_COOKIE_SECURE="false"
    KEYCLOAK_WEB_CLIENTID="forms-flow-web"
    REDIS_URL="redis://$ip_add:6379/0"

    echo "FORMSFLOW_API_URL=$FORMSFLOW_API_URL" >> "$1/.env"
    echo "WEBSOCKET_SECURITY_ORIGIN=$WEBSOCKET_SECURITY_ORIGIN" >> "$1/.env"
    echo "SESSION_COOKIE_SECURE=$SESSION_COOKIE_SECURE" >> "$1/.env"
    echo "KEYCLOAK_WEB_CLIENTID=$KEYCLOAK_WEB_CLIENTID" >> "$1/.env"
    echo "REDIS_URL=$REDIS_URL" >> "$1/.env"
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d forms-flow-bpm
    sleep 6
}

# Function to start forms-flow-analytics
forms_flow_analytics() {
    REDASH_HOST="http://$ip_add:7001"
    PYTHONUNBUFFERED="0"
    REDASH_LOG_LEVEL="INFO"
    REDASH_REDIS_URL="redis://redis:6379/0"
    POSTGRES_USER="postgres"
    POSTGRES_PASSWORD="changeme"
    POSTGRES_DB="postgres"
    REDASH_COOKIE_SECRET="redash-selfhosted"
    REDASH_SECRET_KEY="redash-selfhosted"
    REDASH_DATABASE_URL="postgresql://postgres:changeme@postgres/postgres"
    REDASH_CORS_ACCESS_CONTROL_ALLOW_ORIGIN="*"
    REDASH_REFERRER_POLICY="no-referrer-when-downgrade"
    REDASH_CORS_ACCESS_CONTROL_ALLOW_HEADERS="Content-Type, Authorization"
    echo "REDASH_HOST=$REDASH_HOST" >> "$1/.env"
    echo "PYTHONUNBUFFERED=$PYTHONUNBUFFERED" >> "$1/.env"
    echo "REDASH_LOG_LEVEL=$REDASH_LOG_LEVEL" >> "$1/.env"
    echo "REDASH_REDIS_URL=$REDASH_REDIS_URL" >> "$1/.env"
    echo "POSTGRES_USER=$POSTGRES_USER" >> "$1/.env"
    echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> "$1/.env"
    echo "POSTGRES_DB=$POSTGRES_DB" >> "$1/.env"
    echo "REDASH_COOKIE_SECRET=$REDASH_COOKIE_SECRET" >> "$1/.env"
    echo "REDASH_SECRET_KEY=$REDASH_SECRET_KEY" >> "$1/.env"
    echo "REDASH_DATABASE_URL=$REDASH_DATABASE_URL" >> "$1/.env"
    echo "REDASH_CORS_ACCESS_CONTROL_ALLOW_ORIGIN=$REDASH_CORS_ACCESS_CONTROL_ALLOW_ORIGIN" >> "$1/.env"
    echo "REDASH_REFERRER_POLICY=$REDASH_REFERRER_POLICY" >> "$1/.env"
    echo "REDASH_CORS_ACCESS_CONTROL_ALLOW_HEADERS=$REDASH_CORS_ACCESS_CONTROL_ALLOW_HEADERS" >> "$1/.env"
    docker-compose -p formsflow-ai -f "$1/analytics-docker-compose.yml" run --rm server create_db
    docker-compose -p formsflow-ai -f "$1/analytics-docker-compose.yml" up --build -d
    sleep 5
}

# Function to start forms-flow-webapi
forms_flow_api() {
    if [ "$2" == "1" ]; then
        INSIGHT_API_KEY="default-api-key"  # Assuming default for the API key
        INSIGHT_API_URL="http://$ip_add:7001"
        echo "INSIGHT_API_URL=$INSIGHT_API_URL" >> "$1/.env"
        echo "INSIGHT_API_KEY=$INSIGHT_API_KEY" >> "$1/.env"
    fi
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d forms-flow-webapi
}

# Function to start forms-flow-documents-api
forms_flow_documents() {
    DOCUMENT_SERVICE_URL="http://$ip_add:5006"
    echo "DOCUMENT_SERVICE_URL=$DOCUMENT_SERVICE_URL" >> "$1/.env"
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d forms-flow-documents-api
    sleep 5
}

# Function to start forms-flow-data-analysis-api
forms_flow_data_analysis() {
    echo "Skipping forms-flow-data-analysis-api installation."  # Always skip this
}

# Main function
main() {
    set_common_properties
    set_docker_compose_file
    find_my_ip
    keycloak "$PWD"
    forms_flow_forms "$PWD"
    forms_flow_web "$PWD"
    forms_flow_bpm "$PWD"
    forms_flow_analytics "$PWD"
    forms_flow_api "$PWD" 1
    forms_flow_documents "$PWD"
    forms_flow_data_analysis "$PWD"
    isUp
}

# Start the installation
main