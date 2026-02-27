#!/usr/bin/env bash

set -u -o pipefail
FAILED=false
ERROR_MSG=""

CYAN='\033[0:36m'

NC='\033[0m' # No Color

OWNER="$1"
REPO="$2"
ISSUE_NUMBER=$3

PROJECT_ID="PVT_kwHOBh_Zsc4BMeio"
STATUS_FIELD_ID="PVTSSF_lAHOBh_Zsc4BMeiozg7v4es"
AWAITING_PO_APPROVAL_OPTION_ID="b79f21be"

echo -e "${CYAN}INFO: Moving issue #${ISSUE_NUMBER} to 'Awaiting PO Approval' column${NC}"

echo "Getting current PR's associated issue's subissues..."

RESPONSE=$(gh api graphql -f query="$(cat ../graphql/get_subissue.graphql)" -F parent_number=${ISSUE_NUMBER} -F owner="${OWNER}" -F repo="${REPO}")

SUB_ISSUE_COUNT=$(echo "$RESPONSE" | jq '.data.repository.issue.subIssues.nodes | length')

GRAPHQL_ERROS=$(echo "$RESPONSE" | jq '.errors')
if [ "$GRAPHQL_ERRORS" != "null" ]; then
    ERROR_MSG=$(echo "$GRAPHQL_ERRORS" | jq -r '.[0].message')
    echo "::error title=GraphQL Error::$ERROR_MSG"
    exit 1 # Exit with error if GraphQL query failed
fi

if [[ $SUB_ISSUE_COUNT -eq 0 ]]; then
  echo "::warning title=No subissues found::No subissues found for issue #${ISSUE_NUMBER}. Exiting."
  exit 0 # No subissues to move, but not an error condition so exit with success
fi

echo "Found ${SUB_ISSUE_COUNT} subissue(s). Getting the Acceptance Test subissue (if any) and moving it..."

AT_SUB_ISSUES=$(echo "$RESPONSE" | jq '
  .data.repository.issue.subIssues.nodes
  | map(
      select(
        (.labels.nodes // [] | any(.name == "acceptance-test"))
      )
    )
')

AT_SUB_ISSUE_COUNT=$(echo "$AT_SUB_ISSUES" | jq 'length')
