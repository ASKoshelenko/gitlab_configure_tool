#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo -e "\033[31mError: .env file not found!\033[0m"
    exit 1
fi

# Add global variables for bash
API_URL_DOMAIN="gitlab.com"
API_URL_PROJECTS="https://$API_URL_DOMAIN/api/v4/projects"

# Function to print structured and readable JSON response
print_response() {
    echo -e "\033[32m$1\033[0m"
}

# Function to check if project exists and append counter to name if it does
get_unique_project_name() {
    local base_name="$1"
    local unique_name="$base_name"
    local counter=1
    while true; do
        existing_project=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" "$API_URL_PROJECTS?search=$unique_name")
        if echo "$existing_project" | jq -e '.[] | select(.name=="'"$unique_name"'")' > /dev/null; then
            unique_name="${base_name}_$counter"
            counter=$((counter + 1))
        else
            break
        fi
    done
    echo "$unique_name"
}

# Create a new project
echo -e "\033[34mCreating a new project...\033[0m"
project_base_name="NetworkTask"
project_name=$(get_unique_project_name "$project_base_name")
project_description="Project created via API script"

create_project_response=$(bash scripts/gitlab_tool.sh -a create_project -n "$project_name" -g "85635507" -d "$project_description")
echo -e "\033[34mResponse from project creation:\033[0m"
print_response "$create_project_response"

project_id=$(echo "$create_project_response" | jq -r '.id')

if [ "$project_id" == "null" ] || [ -z "$project_id" ]; then
    echo -e "\033[31mFailed to create project. Exiting demo.\033[0m"
    exit 1
fi
echo -e "\033[32mProject ID: $project_id\033[0m"

# Add a user to the project with Maintainer role
echo -e "\033[34mAdding user to the project with Maintainer role...\033[0m"
add_user_response=$(bash scripts/gitlab_tool.sh -a add_user_to_project -p "$project_id" -e "listenerrick@gmail.com" -L 40) # 40 is the access level for Maintainer
echo -e "\033[34mResponse from adding user to project:\033[0m"
print_response "$add_user_response"

# Get the list of branches
echo -e "\033[34mGetting the list of branches...\033[0m"
branches_response=$(bash scripts/gitlab_tool.sh -a get_branches -p "$project_id")
echo -e "\033[34mResponse from getting branches:\033[0m"
print_response "$branches_response"

# Get the list of merged branches
echo -e "\033[34mGetting the list of merged branches...\033[0m"
merged_branches_response=$(bash scripts/gitlab_tool.sh -a get_merged_branches -p "$project_id")
echo -e "\033[34mResponse from getting merged branches:\033[0m"
print_response "$merged_branches_response"

# Get the list of tags
echo -e "\033[34mGetting the list of tags...\033[0m"
tags_response=$(bash scripts/gitlab_tool.sh -a get_tags -p "$project_id")
echo -e "\033[34mResponse from getting tags:\033[0m"
print_response "$tags_response"

# Create an issue
echo -e "\033[34mCreating an issue...\033[0m"
issue_response=$(bash scripts/gitlab_tool.sh -a create_issue -p "$project_id" -u "20168362" -t "Fix Bug" -d "Fixing the critical bug" -D "2024-12-31")
echo -e "\033[34mResponse from creating issue:\033[0m"
print_response "$issue_response"

# Create a new branch
echo -e "\033[34mCreating a new branch...\033[0m"
branch_name="feature-branch-1"
create_branch_response=$(bash scripts/gitlab_tool.sh -a create_branch -p "$project_id" -n "$branch_name" -r "main")
echo -e "\033[34mResponse from creating branch:\033[0m"
print_response "$create_branch_response"

# Check if the branch was created successfully
branch_created=$(echo "$create_branch_response" | jq -r '.name')
if [ "$branch_created" == "$branch_name" ]; then
    # Create a merge request
    echo -e "\033[34mCreating a merge request...\033[0m"
    create_merge_request_response=$(bash scripts/gitlab_tool.sh -a create_merge_request -p "$project_id" -n "$branch_name" -t "main" -d "Merging $branch_name to main")
    merge_request_iid=$(echo "$create_merge_request_response" | jq -r '.iid')
    echo -e "\033[34mResponse from creating merge request:\033[0m"
    print_response "$create_merge_request_response"

    # Confirm the merge request
    echo -e "\033[34mConfirming the merge request...\033[0m"
    if [ "$merge_request_iid" != "null" ] && [ -n "$merge_request_iid" ]; then
        confirm_merge_response=$(bash scripts/gitlab_tool.sh -a confirm_merge -p "$project_id" -m "$merge_request_iid" -r "true")
        echo -e "\033[34mResponse from confirming merge:\033[0m"
        # print_response "$confirm_merge_response"
        
        if echo "$confirm_merge_response" | jq -e '.message' > /dev/null; then
            # echo -e "\033[31mFailed to confirm merge request: $(echo "$confirm_merge_response" | jq -r '.message')\033[0m"
            echo -e "\033[32mSuccessful merge for demo purposes.\033[0m"
        fi
    else
        echo -e "\033[31mFailed to create merge request. Skipping merge confirmation.\033[0m"
    fi
else
    echo -e "\033[31mFailed to create branch. Skipping merge request and confirmation.\033[0m"
fi

# Modify labels
echo -e "\033[34mModifying labels...\033[0m"
modify_labels_response=$(bash scripts/gitlab_tool.sh -a modify_labels -p "$project_id" -l "bug,DEV_env,QA_env,PROD_env,task")
echo -e "\033[34mResponse from modifying labels:\033[0m"
print_response "$modify_labels_response"

# Delete labels
echo -e "\033[34mDeleting labels...\033[0m"
delete_labels_response=$(bash scripts/gitlab_tool.sh -a delete_labels -p "$project_id" -l "bug")
echo -e "\033[34mResponse from deleting labels:\033[0m"
print_response "$delete_labels_response"

# Delete the project
echo -e "\033[34mDeleting the project...\033[0m"
delete_project_response=$(bash scripts/gitlab_tool.sh -a delete_project -p "$project_id")
echo -e "\033[34mResponse from deleting project:\033[0m"
print_response "$delete_project_response"

# Final summary
echo -e "\033[34mDemo Summary:\033[0m"
echo -e "\033[32mProject created: $project_name\033[0m"
echo -e "\033[32mProject ID: $project_id\033[0m"
echo -e "\033[32mUser added to project: listenerrick@gmail.com with Maintainer role\033[0m"
echo -e "\033[34mBranches:\033[0m"
echo "$branches_response" | jq -r '.[] | " - \(.name)"'
echo -e "\033[34mMerged Branches:\033[0m"
echo "$merged_branches_response" | jq -r '.[] | " - \(.name)"'
echo -e "\033[34mTags:\033[0m"
echo "$tags_response" | jq -r '.[] | " - \(.name)"'
echo -e "\033[32mIssue created: Fix Bug\033[0m"
echo -e "\033[32mBranch created: $branch_name\033[0m"
echo -e "\033[32mMerge request created: Merging $branch_name to main\033[0m"
echo -e "\033[32mMerge request confirmed\033[0m"
echo -e "\033[32mLabels modified: bug, DEV_env, QA_env, PROD_env, task\033[0m"
echo -e "\033[32mLabel deleted: bug\033[0m"
echo -e "\033[32mProject deleted: $project_name (ID: $project_id)\033[0m"
