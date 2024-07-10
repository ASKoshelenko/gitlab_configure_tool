#!/bin/bash

# Подключение файла helpers.sh
source scripts/utils/helpers.sh

function create_project() {
    local name="$1"
    local group_id="$2"
    local description="$3"
    echo "Generated JSON payload:"
    curl_response=$(curl -s -H "Content-Type:application/json" "https://gitlab.com/api/v4/projects?private_token=$TOKEN" \
    -d @- << EOF
        {
            "name": "${name}",
            "path": "${name}",
            "namespace_id": "${group_id}",
            "description": "${description}",
            "visibility": "private"
        }
EOF
    )

    # Проверка результата выполнения
    if [[ $(echo "$curl_response" | jq -e '.id') != "null" ]]; then
        echo "Response from GitLab API:"
        echo "$curl_response" | jq '{id: .id, name: .name, description: .description, web_url: .web_url}'
        echo "Project created successfully."
    else
        handle_curl_error "$curl_response"
    fi
}
