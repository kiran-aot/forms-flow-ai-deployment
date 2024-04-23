#!/bin/bash

## Common Properties ##
set_common_properties() {
    WEBSOCKET_ENCRYPT_KEY="giert989jkwrgb@DR55"
    KEYCLOAK_BPM_CLIENT_SECRET="e4bdbd25-1467-4f7f-b993-bc4b1944c943"
    export WEBSOCKET_ENCRYPT_KEY
    export KEYCLOAK_BPM_CLIENT_SECRET
}

## Set the compose file for docker ##
set_docker_compose_file() {
    docker_compose_file='docker-compose.yml'
    if [ "$(uname -m)" == "arm64" ]; then
        docker_compose_file='docker-compose-arm64.yml'
    fi
}

## Get the Public IP of AMI ##
get_ip_address() {
    ipadd=$(curl ifconfig.me)
    ip_add=$ipadd
    export ip_add
}

## Keycloak Installation ##
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
    docker exec -i keycloak /bin/bash -c 'cd /opt/keycloak/bin/ && ./kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin <<< "changeme" && ./kcadm.sh update realms/master -s sslRequired=NONE'
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d forms-flow-bpm

    sleep 6
}

# Function to start forms-flow-webapi
forms_flow_api() {
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d forms-flow-webapi
}

# Function to start forms-flow-documents-api
forms_flow_documents() {
    DOCUMENT_SERVICE_URL="http://$ip_add:5006"
    echo "DOCUMENT_SERVICE_URL=$DOCUMENT_SERVICE_URL" >> "$1/.env"
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d forms-flow-documents-api
    sleep 5
}

# Function to start forms-flow-web
forms_flow_web() {
    BPM_API_URL="http://$ip_add:8000/camunda"
    echo "BPM_API_URL=$BPM_API_URL" >> "$1/.env"
    docker-compose -p formsflow-ai -f "$1/$docker_compose_file" up --build -d forms-flow-web
}

main() {
    set_common_properties
    set_docker_compose_file
    get_ip_address
    keycloak "$1"
    forms_flow_forms "$1"
    forms_flow_bpm "$1"
    forms_flow_api "$1"
    forms_flow_documents "$1"
    forms_flow_web "$1"
    exit 0
}
main
