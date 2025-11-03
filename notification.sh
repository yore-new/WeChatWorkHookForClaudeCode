#!/usr/bin/env bash

# ============================================================================
# WeChat Work Notification Sender
# ============================================================================
#
# This script sends formatted notifications to WeChat Work (企业微信) via webhook.
#
# INPUT (via STDIN):
#   JSON object with fields:
#     - session_id: Claude session identifier
#     - project_name: Name of the project
#     - task_name: Name of the task
#     - git_branch: Current git branch
#     - task_status: Status (SUCCESS/COMPLETED/DONE/FAILED/ERROR/IN_PROGRESS/etc.)
#     - event_device: Device identifier (user@hostname)
#     - task_details: Detailed task description
#     - notification_template: Template filename (default: "notification.md")
#       This template must exist in templates/ directory and can contain
#       placeholders like {SESSION_ID}, {PROJECT_NAME}, {TASK_NAME}, etc.
#     - notification_url: WeChat Work webhook URL (required)
#
# OUTPUT:
#   Sends markdown-formatted message to WeChat Work webhook.
#   Returns 0 on success, 1 on failure.
#
# STATUS CONVERSION:
#   Task status is converted to display format:
#     SUCCESS/COMPLETED/DONE → "Success" with ✅ emoji and info color
#     FAILED/ERROR → "Failed" with ❌ emoji and warning color
#     IN_PROGRESS/RUNNING → "In Progress" with ⏳ emoji and comment color
#     Others → "Unknown" with ❓ emoji
#
# TEMPLATE PLACEHOLDERS:
#   {SESSION_ID} - Claude session identifier
#   {PROJECT_NAME} - Project name
#   {TASK_NAME} - Task name
#   {GIT_BRANCH} - Git branch
#   {TASK_STATUS} - Converted status text
#   {STATUS_COLOR_EMOJI} - Status emoji
#   {EVENT_DEVICE} - Device identifier
#   {EVENT_TIME} - Timestamp (auto-generated)
#   {TASK_DETAILS} - Task details
#
# ============================================================================

set -euo pipefail

# ============================================================================
# Constants
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
TEMP_RESPONSE_FILE="/tmp/wechat_response_$$.json"

# ============================================================================
# Helper Functions
# ============================================================================

# Print error message and exit
error_exit() {
    local message="$1"
    echo "Error: ${message}" >&2
    rm -f "${TEMP_RESPONSE_FILE}"
    exit 1
}

# Cleanup temporary files on exit
cleanup() {
    rm -f "${TEMP_RESPONSE_FILE}"
}

trap cleanup EXIT

# ============================================================================
# Input Processing
# ============================================================================

# Read JSON from STDIN
INPUT_JSON=$(cat)

# Validate JSON input
if [[ -z "${INPUT_JSON}" ]]; then
    error_exit "No input received from STDIN"
fi

# Parse JSON fields using jq
SESSION_ID=$(echo "${INPUT_JSON}" | jq -r '.session_id // ""')
PROJECT_NAME=$(echo "${INPUT_JSON}" | jq -r '.project_name // ""')
TASK_NAME=$(echo "${INPUT_JSON}" | jq -r '.task_name // ""')
GIT_BRANCH=$(echo "${INPUT_JSON}" | jq -r '.git_branch // ""')
TASK_STATUS=$(echo "${INPUT_JSON}" | jq -r '.task_status // ""')
EVENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
EVENT_DEVICE=$(echo "${INPUT_JSON}" | jq -r '.event_device // ""')
TASK_DETAILS=$(echo "${INPUT_JSON}" | jq -r '.task_details // ""')
NOTIFICATION_TEMPLATE=$(echo "${INPUT_JSON}" | jq -r '.notification_template // "notification.md"')
NOTIFICATION_URL=$(echo "${INPUT_JSON}" | jq -r '.notification_url // ""')

# Validate required fields
if [[ -z "${NOTIFICATION_URL}" ]]; then
    error_exit "notification_url cannot be empty"
fi

# ============================================================================
# Template Processing
# ============================================================================

# Build template file path
TEMPLATE_FILE="${TEMPLATES_DIR}/${NOTIFICATION_TEMPLATE}"

# Check if template file exists
if [[ ! -f "${TEMPLATE_FILE}" ]]; then
    error_exit "Template file not found: ${TEMPLATE_FILE}"
fi

# Read template content
TEMPLATE_CONTENT=$(cat "${TEMPLATE_FILE}")

# ============================================================================
# Status Conversion
# ============================================================================

# Convert status to WeChat Work format with emoji and color
STATUS_COLOR_OPEN=""
STATUS_COLOR_CLOSE=""
STATUS_EMOJI=""

case "${TASK_STATUS}" in
    SUCCESS|COMPLETED|DONE|success|completed|done)
        STATUS_COLOR_OPEN='<font color="info">'
        STATUS_COLOR_CLOSE='</font>'
        STATUS_EMOJI='✅'
        TASK_STATUS='Success'
        ;;
    FAILED|ERROR|failed|error)
        STATUS_COLOR_OPEN='<font color="warning">'
        STATUS_COLOR_CLOSE='</font>'
        STATUS_EMOJI='❌'
        TASK_STATUS='Failed'
        ;;
    RUNNING|IN_PROGRESS|running|in_progress)
        STATUS_COLOR_OPEN='<font color="comment">'
        STATUS_COLOR_CLOSE='</font>'
        STATUS_EMOJI='⏳'
        TASK_STATUS='In Progress'
        ;;
    *)
        STATUS_COLOR_OPEN=""
        STATUS_COLOR_CLOSE=""
        STATUS_EMOJI='❓'
        TASK_STATUS='Unknown'
        ;;
esac

# ============================================================================
# Template Rendering
# ============================================================================

# Replace placeholders in template
RENDERED_CONTENT="${TEMPLATE_CONTENT}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{SESSION_ID\}/${SESSION_ID}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{PROJECT_NAME\}/${PROJECT_NAME}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{TASK_NAME\}/${TASK_NAME}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{GIT_BRANCH\}/${GIT_BRANCH}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{STATUS_COLOR_OPEN\}/${STATUS_COLOR_OPEN}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{TASK_STATUS\}/${TASK_STATUS}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{STATUS_COLOR_CLOSE\}/${STATUS_COLOR_CLOSE}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{STATUS_COLOR_EMOJI\}/${STATUS_EMOJI}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{EVENT_DEVICE\}/${EVENT_DEVICE}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{EVENT_TIME\}/${EVENT_TIME}}"
RENDERED_CONTENT="${RENDERED_CONTENT//\{TASK_DETAILS\}/${TASK_DETAILS}}"

# ============================================================================
# Send Notification
# ============================================================================

# Build WeChat Work robot request body
REQUEST_BODY=$(jq -n \
    --arg content "${RENDERED_CONTENT}" \
    '{
        "msgtype": "markdown",
        "markdown": {
            "content": $content
        }
    }')

# Send request to WeChat Work robot
HTTP_CODE=$(curl -s -o "${TEMP_RESPONSE_FILE}" -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "${REQUEST_BODY}" \
    "${NOTIFICATION_URL}")

# ============================================================================
# Response Handling
# ============================================================================

# Check HTTP response status
if [[ "${HTTP_CODE}" -eq 200 ]]; then
    # Parse response
    ERRCODE=$(jq -r '.errcode // -1' "${TEMP_RESPONSE_FILE}")
    ERRMSG=$(jq -r '.errmsg // "Unknown error"' "${TEMP_RESPONSE_FILE}")

    if [[ "${ERRCODE}" -eq 0 ]]; then
        echo "Success: Notification sent"
        exit 0
    else
        echo "Failed: Notification rejected [${ERRCODE}] ${ERRMSG}" >&2
        exit 1
    fi
else
    echo "Failed: HTTP request failed with status code: ${HTTP_CODE}" >&2
    if [[ -f "${TEMP_RESPONSE_FILE}" ]]; then
        echo "Response:" >&2
        cat "${TEMP_RESPONSE_FILE}" >&2
    fi
    exit 1
fi
