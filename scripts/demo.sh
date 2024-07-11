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

# Add users to the project with different roles
echo -e "\033[34mAdding users to the project with different roles...\033[0m"
add_user_response_1=$(bash scripts/gitlab_tool.sh -a add_user_to_project -p "$project_id" -e "listenerrick@gmail.com" -L 40) # 40 is the access level for Maintainer
add_user_response_2=$(bash scripts/gitlab_tool.sh -a add_user_to_project -p "$project_id" -e "askoshelenko@gmail.com" -L 30) # 30 is the access level for Developer
echo -e "\033[34mResponse from adding users to project:\033[0m"
print_response "$add_user_response_1"
print_response "$add_user_response_2"

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

# Create new branches
echo -e "\033[34mCreating new branches...\033[0m"
branch_name1="feature-branch-1"
branch_name2="issue-1-fix-bug"
create_branch_response1=$(bash scripts/gitlab_tool.sh -a create_branch -p "$project_id" -n "$branch_name1" -r "main")
create_branch_response2=$(bash scripts/gitlab_tool.sh -a create_branch -p "$project_id" -n "$branch_name2" -r "main")
echo -e "\033[34mResponse from creating branches:\033[0m"
print_response "$create_branch_response1"
print_response "$create_branch_response2"

# Add changes to the feature branch
echo -e "\033[34mAdding changes to the feature branch...\033[0m"
add_commit_response=$(curl --request POST --header "PRIVATE-TOKEN: $TOKEN" --header "Content-Type: application/json" \
--data '{
  "branch": "'"$branch_name1"'",
  "commit_message": "Updated README.md with additional changes",
  "actions": [
    {
      "action": "update",
      "file_path": "README.md",
      "content": "Updated content with some changes"
    }
  ]
}' "https://gitlab.com/api/v4/projects/$project_id/repository/commits")
echo -e "\033[34mResponse from adding changes:\033[0m"
print_response "$add_commit_response"

# Create a merge request
echo -e "\033[34mCreating a merge request...\033[0m"
create_merge_request_response=$(bash scripts/gitlab_tool.sh -a create_merge_request -p "$project_id" -n "$branch_name1" -t "main" -d "Merging $branch_name1 to main")
merge_request_iid=$(echo "$create_merge_request_response" | jq -r '.iid')
echo -e "\033[34mResponse from creating merge request:\033[0m"
print_response "$create_merge_request_response"

# Add a delay before confirming the merge request
echo -e "\033[34mWaiting for 5 seconds before confirming the merge request...\033[0m"
sleep 5

# Confirm the merge request
echo -e "\033[34mConfirming the merge request...\033[0m"
if [ "$merge_request_iid" != "null" ] && [ -n "$merge_request_iid" ]; then
    confirm_merge_response=$(bash scripts/gitlab_tool.sh -a confirm_merge -p "$project_id" -m "$merge_request_iid" -r "true")
    echo -e "\033[34mResponse from confirming merge:\033[0m"
    print_response "$confirm_merge_response"
    if echo "$confirm_merge_response" | jq -e '.message' > /dev/null; then
        echo -e "\033[31mFailed to confirm merge request: $(echo "$confirm_merge_response" | jq -r '.message')\033[0m"
    else
        echo -e "\033[32mMerge request confirmed successfully.\033[0m"
    fi
else
    echo -e "\033[31mFailed to create merge request. Skipping merge confirmation.\033[0m"
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

Delete the project
echo -e "\033[34mDeleting the project...\033[0m"
delete_project_response=$(bash scripts/gitlab_tool.sh -a delete_project -p "$project_id")
echo -e "\033[34mResponse from deleting project:\033[0m"
print_response "$delete_project_response"

# Final summary
echo -e "\033[34mDemo Summary:\033[0m"
echo -e "\033[32mProject created: $project_name\033[0m"
echo -e "\033[32mProject ID: $project_id\033[0m"
echo -e "\033[32mUsers added to project with different roles\033[0m"
echo -e "\033[34mBranches:\033[0m"
echo "$branches_response" | jq -r '.[] | " - \(.name)"'
echo -e "\033[34mMerged Branches:\033[0m"
echo "$merged_branches_response" | jq -r '.[] | " - \(.name)"'
echo -e "\033[34mTags:\033[0m"
echo "$tags_response" | jq -r '.[] | " - \(.name)"'
echo -e "\033[32mIssue created: Fix Bug\033[0m"
echo -e "\033[32mBranches created: $branch_name1, $branch_name2\033[0m"
echo -e "\033[32mMerge request created: Merging $branch_name1 to main\033[0m"
echo -e "\033[32mMerge request confirmed\033[0m"
echo -e "\033[32mLabels modified: bug, DEV_env, QA_env, PROD_env, task\033[0m"
echo -e "\033[32mLabel deleted: bug\033[0m"
echo -e "\033[32mProject deleted: $project_name (ID: $project_id)\033[0m"
