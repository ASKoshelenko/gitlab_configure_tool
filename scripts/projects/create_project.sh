#!/bin/bash
source "$(dirname "$0")/../utils/helpers.sh"

function create_project() {
    local name="$1"
    local group_id="$2"
    local description="$3"
    
    if [[ -z "$name" || -z "$group_id" || -z "$description" ]]; then
        log_error "One of the required parameters is empty."
        exit 1
    fi
    
    local json_payload=$(jq -n \
        --arg name "$name" \
        --arg path "$name" \
        --arg ns_id "$group_id" \
        --arg desc "$description" \
        '{name: $name, path: $path, namespace_id: $ns_id, description: $desc, visibility: "private"}')
    
    echo "Generated JSON payload:"
    echo "$json_payload"
    
    local response=$(curl -s -H "Content-Type: application/json" -H "PRIVATE-TOKEN: $TOKEN" -d "$json_payload" "$API_URL_PROJECTS")
    
    if [[ $(echo "$response" | jq -e '.message') == "null" ]]; then
        echo "Response from GitLab API:"
        echo "$response" | jq '{id: .id, name: .name, description: .description, web_url: .web_url}'
        echo "Response from GitLab API:" >> project_creation.log
        echo "$response" >> project_creation.log
        echo "Project created successfully."
    else
        local error_message
        error_message=$(echo "$response" | jq -r '.message')
        echo "Error: $error_message"
        return 1
    fi
}

create_project "$@"
