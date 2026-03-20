#!/usr/bin/env bash

set -u -o pipefail
ERROR_MSG=""

PR_NUMBER=$1

OWNER="C0dingViking"
REPO="soen390-mini-capstone"

PROJECT_ID="PVT_kwHOBh_Zsc4BMeio"
STATUS_FIELD_ID="PVTSSF_lAHOBh_Zsc4BMeiozg7v4es"
AWAITING_PO_APPROVAL_OPTION_ID="b79f21be"

echo -e "INFO: Moving issue associated ATs to 'Awaiting PO Approval' column"

echo "Getting current PR's associated issue's number..."

RESPONSE=$(gh api graphql \
  -f query="$(cat queries/get_pr_issue_number.graphql)" \
  -F prNb=${PR_NUMBER} \
  -F owner="${OWNER}" \
  -F repo="${REPO}")

echo "Response from GitHub API for PR #${PR_NUMBER}: $RESPONSE"

mapfile -t USER_STORY_ISSUES < <(
  jq -r '
  .data.repository.pullRequest.closingIssuesReferences.nodes[]
  | select(.labels.nodes // [] | any(.name == "user story"))
  | .number
  ' <<< "$RESPONSE"
)

if [[ ${#USER_STORY_ISSUES[@]} -eq 0 ]]; then
  echo "::warning title=No User Story Issues Found::No user story issues linked to this PR."
  exit 0
fi

for ISSUE_NUMBER in "${USER_STORY_ISSUES[@]}"; do
  echo "Getting ${ISSUE_NUMBER} associated subissues..."

  RESPONSE=$(gh api graphql \
    -f query="$(cat queries/get_subissue.graphql)" \
    -F issueNb=${ISSUE_NUMBER} \
    -F owner="${OWNER}" \
    -F repo="${REPO}")

  GRAPHQL_ERRORS=$(jq '.errors // empty' <<< "$RESPONSE")
  if [[ -n "$GRAPHQL_ERRORS" ]]; then
      ERROR_MSG=$(echo "$GRAPHQL_ERRORS" | jq -r '.[0].message')
      echo "::error title=GraphQL Error::$ERROR_MSG"
      continue # Exit with error if GraphQL query failed
  fi

  SUB_ISSUE_COUNT=$(echo "$RESPONSE" | jq '.data.repository.issue.subIssues.nodes | length')

  if [[ $SUB_ISSUE_COUNT -eq 0 ]]; then
    echo "::warning title=No subissues found::No subissues found for issue #${ISSUE_NUMBER}. Exiting."
    continue # No subissues to move, but not an error condition so exit with success
  fi

  echo "Found ${SUB_ISSUE_COUNT} subissue(s). Getting the Acceptance Test subissue (if any) and moving it..."

  AT_SUB_ISSUES=$(jq '
    .data.repository.issue.subIssues.nodes
    | map(select(.labels.nodes // [] | any(.name == "acceptance test")))
  ' <<< "$RESPONSE")

  NB_AT_SUB_ISSUES=$(jq 'length' <<< "$AT_SUB_ISSUES")

  if [[ $NB_AT_SUB_ISSUES -eq 0 ]]; then
    echo "::warning title=No Acceptance Test subissue found::No subissue with 'acceptance test' label found for issue #${ISSUE_NUMBER}. Exiting."
    continue # No AT subissue to move, but not an error condition so exit with success
  fi

  AT_PROJECT_CARD_ID=$(jq -r '.[0].projectItems.nodes[0].id' <<< "$AT_SUB_ISSUES")

  RESPONSE=$(gh api graphql \
    -f query="$(cat queries/mutate_project_card.graphql)" \
    -F projectId="${PROJECT_ID}" \
    -F itemId="${AT_PROJECT_CARD_ID}" \
    -F fieldId="${STATUS_FIELD_ID}" \
    -F newOptionId="${AWAITING_PO_APPROVAL_OPTION_ID}")

  ERRORS=$(jq -r '.errors // empty' <<< "$RESPONSE")

  if [[ -n "$ERRORS" ]]; then
    echo "::warning title=Project Card Mutation Failed::An error occurred while updating the project card: $(jq -c '.' <<< "$ERRORS")"
    continue
  fi

  echo "✅ Project card updated successfully for item ID ${AT_PROJECT_CARD_ID}"
done
