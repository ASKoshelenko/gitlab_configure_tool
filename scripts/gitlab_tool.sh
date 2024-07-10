#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found!"
    exit 1
fi

API_URL_DOMAIN="gitlab.com"
API_URL_PROJECTS="https://$API_URL_DOMAIN/api/v4/projects"
API_URL_USERS="https://$API_URL_DOMAIN/api/v4/users"

function display_help() {
    echo "Usage: $0 -a <action> [options]"
    echo "Options:"
    echo "  -a <action>               Action to perform: create_project, modify_user_role, modify_labels, delete_labels, create_issue, find_merge_requests, add_user_to_project, create_branch, create_merge_request, confirm_merge, get_branches, get_merged_branches, get_tags, delete_project"
    echo "  -p <project_id>           ID of the project"
    echo "  -g <group_id>             ID of the group"
    echo "  -r <role>                 Role to assign to the user (for modify_user_role)"
    echo "  -u <user_id>              ID of the user (for modify_user_role)"
    echo "  -l <labels>               Labels to modify/delete (for modify_labels/delete_labels)"
    echo "  -t <title>                Title of the issue (for create_issue)"
    echo "  -d <description>          Description of the issue (for create_issue)"
    echo "  -D <due_date>             Due date of the issue (for create_issue)"
    echo "  -n <name>                 Name of the project (for create_project)"
    echo "  -e <email>                Email of the user (for add_user_to_project)"
    echo "  -L <access_level>         Access level for the user (for add_user_to_project)"
    echo "  -m <merge_request_iid>    IID of the merge request (for confirm_merge)"
    echo "  -r <remove_source_branch> Remove source branch after merge (true/false) (for confirm_merge)"
    echo "  -h, --help                Display this help message"
    exit 1
}

function handle_curl_error() {
    echo "cURL request failed: $1"
    exit 1
}

function validate_integer() {
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]] ; then
       echo "Error: $2 must be an integer" >&2
       exit 1
    fi
}

function validate_action() {
    case $1 in
        create_project|modify_user_role|modify_labels|delete_labels|create_issue|find_merge_requests|add_user_to_project|create_branch|create_merge_request|confirm_merge|get_branches|get_merged_branches|get_tags|delete_project) ;;
        *) echo "Error: Invalid action: $1"; exit 1 ;;
    esac
}

function create_project() {
    local base_name="$1"
    local group_id="$2"
    local description="$3"
    local name="$base_name"
    local counter=1

    while : ; do
        existing_project=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" "$API_URL_PROJECTS?search=$name&simple=true" | jq '.[] | select(.name == "'"$name"'")')

        if [ -z "$existing_project" ]; then
            break
        else
            name="${base_name}_$counter"
            counter=$((counter + 1))
        fi
    done

    curl_response=$(curl -s -H "Content-Type:application/json" "$API_URL_PROJECTS?private_token=$TOKEN" \
    -d @- << EOF
        {
            "name": "${name}",
            "path": "${name}",
            "namespace_id": "${group_id}",
            "description": "${description}",
            "visibility": "private",
            "initialize_with_readme": "true"
        }
EOF
    ) 

    if [[ $(echo "$curl_response" | jq -e '.id') == "null" ]]; then
        local error_message
        error_message=$(echo "$curl_response" | jq -r '.message')
        echo "Error: $error_message"
        exit 1
    fi

    echo "$curl_response"
}

function add_user_to_project() {
    local project_id="$1"
    local email="$2"
    local access_level="$3"
    curl_response=$(curl -s --request POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --data "email=$email" \
        --data "access_level=$access_level" \
        --url "$API_URL_PROJECTS/$project_id/invitations") || handle_curl_error "$curl_response"
    echo "$curl_response"
}

function get_branches() {
    local project_id="$1"
    curl_response=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" "$API_URL_PROJECTS/$project_id/repository/branches") || handle_curl_error "$curl_response"
    echo "$curl_response"
}

function get_merged_branches() {
    local project_id="$1"
    curl_response=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" "$API_URL_PROJECTS/$project_id/repository/branches?merged=true") || handle_curl_error "$curl_response"
    echo "$curl_response"
}

function get_tags() {
    local project_id="$1"
    curl_response=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" "$API_URL_PROJECTS/$project_id/repository/tags") || handle_curl_error "$curl_response"
    echo "$curl_response"
}

function create_issue() {
    local project_id="$1"
    local assignee="$2"
    local title="$3"
    local description="$4"
    local due_date="$5"

    curl_response=$(curl -s --request POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --header "Content-Type: application/json" \
        --data @- \
        --url "$API_URL_PROJECTS/$project_id/issues" << EOF
    {
        "title": "$title",
        "description": "$description",
        "assignee_ids": ["$assignee"],
        "due_date": "$due_date"
    }
EOF
    ) || handle_curl_error "$curl_response"

    echo "$curl_response"
}

function create_branch() {
    local project_id="$1"
    local branch_name="$2"
    local ref="$3"

    main_branch=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" "$API_URL_PROJECTS/$project_id/repository/branches/$ref")
    if [[ $(echo "$main_branch" | jq -e '.name') == "null" ]]; then
        echo "Error: Reference branch '$ref' does not exist. Please provide a valid reference branch."
        exit 1
    fi

    curl_response=$(curl -s --request POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --data "branch=$branch_name&ref=$ref" \
        --url "$API_URL_PROJECTS/$project_id/repository/branches") || handle_curl_error "$curl_response"

    echo "$curl_response"
}

function create_merge_request() {
    local project_id="$1"
    local source_branch="$2"
    local target_branch="$3"
    local title="$4"

    curl_response=$(curl -s --request POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --header "Content-Type: application/json" \
        --data @- \
        --url "$API_URL_PROJECTS/$project_id/merge_requests" << EOF
    {
        "source_branch": "$source_branch",
        "target_branch": "$target_branch",
        "title": "$title"
    }
EOF
    ) || handle_curl_error "$curl_response"

    echo "$curl_response"
}

function confirm_merge() {
    local project_id="$1"
    local merge_request_iid="$2"
    local remove_source_branch="$3"

    curl_response=$(curl -s --request PUT \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --header "Content-Type: application/json" \
        --data @- \
        --url "$API_URL_PROJECTS/$project_id/merge_requests/$merge_request_iid/merge" << EOF
    {
        "merge_commit_message": "Your merge commit message",
        "should_remove_source_branch": $remove_source_branch
    }
EOF
    ) || handle_curl_error "$curl_response"

    echo "$curl_response"
}

function modify_labels() {
    local project_id="$1"
    local label_names="$2"
    local label_color="${3:-#FFAABB}"
    IFS=',' read -ra labels_array <<< "$label_names"
    for label_name in "${labels_array[@]}"; do
        existing_label=$(curl -s --request GET \
             --header "PRIVATE-TOKEN: $TOKEN" \
             --url "$API_URL_PROJECTS/$project_id/labels?search=$label_name" | jq '.[] | select(.name == "'"$label_name"'")')

        if [ -z "$existing_label" ]; then
            curl_response=$(curl -s --request POST \
                 --header "PRIVATE-TOKEN: $TOKEN" \
                 --data-urlencode "name=$label_name" \
                 --data-urlencode "color=$label_color" \
                 --url "$API_URL_PROJECTS/$project_id/labels") || handle_curl_error "$curl_response"
            echo "Label $label_name created successfully." 
        else
            echo "Label $label_name already exists, skipping creation." 
        fi
    done
    echo "Labels modified successfully." 
}

function delete_labels() {
    local project_id="$1"
    local label_names="$2"
    IFS=',' read -ra labels_array <<< "$label_names"
    for label_name in "${labels_array[@]}"; do
        label_id=$(curl -s --request GET \
             --header "PRIVATE-TOKEN: $TOKEN" \
             --url "$API_URL_PROJECTS/$project_id/labels?search=$label_name" | jq -r '.[] | select(.name == "'"$label_name"'") | .id')

        if [ -n "$label_id" ]; then
            curl_response=$(curl -s --request DELETE \
                 --header "PRIVATE-TOKEN: $TOKEN" \
                 --url "$API_URL_PROJECTS/$project_id/labels/$label_id") || handle_curl_error "$curl_response"
            echo "Label $label_name deleted successfully." 
        else
            echo "Label $label_name does not exist, skipping deletion." 
        fi
    done
    echo "Labels deleted successfully."    
}

function delete_project() {
    local project_id="$1"
    curl_response=$(curl -s --request DELETE \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --url "$API_URL_PROJECTS/$project_id") || handle_curl_error "$curl_response"
    echo "$curl_response"
}

while getopts ":a:p:g:r:u:l:t:d:D:n:e:L:m:h" opt; do
    case $opt in
        a) action="$OPTARG" ;;
        p) project_id="$OPTARG" ;;
        g) group_id="$OPTARG" ;;
        r) role="$OPTARG" ;;
        u) user_id="$OPTARG" ;;
        l) labels="$OPTARG" ;;
        t) title="$OPTARG" ;;
        d) description="$OPTARG" ;;
        D) due_date="$OPTARG" ;;
        n) name="$OPTARG" ;;
        e) email="$OPTARG" ;;
        L) access_level="$OPTARG" ;;
        m) merge_request_iid="$OPTARG" ;;
        h) display_help ;;
        \?) echo "Invalid option -$OPTARG" >&2 ;;
    esac
done

validate_action "$action"

case $action in
    create_project) create_project "$name" "$group_id" "$description";;
    modify_user_role) validate_integer "$project_id" "Project ID"; validate_integer "$user_id" "User ID"; modify_user_role "$project_id" "$user_id" "$role" ;;
    modify_labels) validate_integer "$project_id" "Project ID"; modify_labels "$project_id" "$labels" "$label_color" ;;
    delete_labels) validate_integer "$project_id" "Project ID"; delete_labels "$project_id" "$labels" ;;
    create_issue) validate_integer "$project_id" "Project ID"; create_issue "$project_id" "$user_id" "$title" "$description" "$due_date" ;;
    find_merge_requests) find_merge_requests "$project_id" ;;
    add_user_to_project) validate_integer "$project_id" "Project ID"; add_user_to_project "$project_id" "$email" "$access_level" ;;
    create_branch) validate_integer "$project_id" "Project ID"; create_branch "$project_id" "$name" "main" ;;
    create_merge_request) validate_integer "$project_id" "Project ID"; create_merge_request "$project_id" "$name" "main" "$title" ;;
    confirm_merge) validate_integer "$project_id" "Project ID"; confirm_merge "$project_id" "$merge_request_iid" "$role" ;;
    get_branches) validate_integer "$project_id" "Project ID"; get_branches "$project_id" ;;
    get_merged_branches) validate_integer "$project_id" "Project ID"; get_merged_branches "$project_id" ;;
    get_tags) validate_integer "$project_id" "Project ID"; get_tags "$project_id" ;;
    delete_project) validate_integer "$project_id" "Project ID"; delete_project "$project_id" ;;
esac

exit 0
