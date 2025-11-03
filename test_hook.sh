#!/usr/bin/env bash

# ============================================================================
# Test Script for Claude Hook Notification
# ============================================================================
#
# This script tests the Claude Code hook notification system by:
#   1. Creating a temporary mock session log file
#   2. Constructing a test hook input JSON
#   3. Executing hook.sh with the test input
#
# REQUIRED ENVIRONMENT VARIABLES:
#   CLAUDE_HOOK_WECHAT_URL - WeChat Work webhook URL (for actual sending)
#     If not set, notification will be skipped but other processing continues
#
# USAGE:
#   ./test_hook.sh
#
# This script is fully self-contained and doesn't require existing Claude
# session logs. It creates mock data for testing purposes.
#
# ============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Testing Claude Hook Notification Script ==="
echo ""

# Create a temporary directory for test files
TEST_DIR=$(mktemp -d)
trap "rm -rf ${TEST_DIR}" EXIT

# Create a mock session log file with sample data
MOCK_LOG="${TEST_DIR}/test_session.jsonl"
cat > "${MOCK_LOG}" << 'EOF'
{"type":"user_message","timestamp":"2025-11-03T10:00:00Z","content":"Create a simple Python script to calculate fibonacci numbers"}
{"type":"assistant_message","timestamp":"2025-11-03T10:00:05Z","content":"I'll create a Python script for calculating Fibonacci numbers."}
{"type":"tool_call","timestamp":"2025-11-03T10:00:06Z","tool":"write_file","args":{"path":"fibonacci.py","content":"def fibonacci(n):\n    if n <= 1:\n        return n\n    return fibonacci(n-1) + fibonacci(n-2)\n\nif __name__ == '__main__':\n    for i in range(10):\n        print(f'F({i}) = {fibonacci(i)}')"}}
{"type":"tool_result","timestamp":"2025-11-03T10:00:07Z","tool":"write_file","result":"success"}
{"type":"assistant_message","timestamp":"2025-11-03T10:00:08Z","content":"I've created fibonacci.py with a recursive implementation."}
{"type":"user_message","timestamp":"2025-11-03T10:01:00Z","content":"Add error handling and optimize it"}
{"type":"assistant_message","timestamp":"2025-11-03T10:01:05Z","content":"I'll optimize it using memoization."}
{"type":"tool_call","timestamp":"2025-11-03T10:01:06Z","tool":"edit_file","args":{"path":"fibonacci.py"}}
{"type":"tool_result","timestamp":"2025-11-03T10:01:07Z","tool":"edit_file","result":"success"}
{"type":"assistant_message","timestamp":"2025-11-03T10:01:08Z","content":"Done! The script now uses memoization for better performance and includes error handling."}
EOF

echo "Created mock session log: ${MOCK_LOG}"
echo ""

# Construct test hook input
TEST_INPUT=$(jq -n \
    --arg session_id "test-session-$(date +%s)" \
    --arg transcript_path "${MOCK_LOG}" \
    --arg cwd "$(pwd)" \
    --arg hook_event_name "SessionEnd" \
    '{
        "session_id": $session_id,
        "transcript_path": $transcript_path,
        "cwd": $cwd,
        "hook_event_name": $hook_event_name,
        "permission_mode": "default"
    }')

echo "Hook input JSON:"
echo "${TEST_INPUT}" | jq .
echo ""

# Check if notification URL is set
if [[ -n "${CLAUDE_HOOK_WECHAT_URL:-}" ]]; then
    echo "✓ Notification URL configured: ${CLAUDE_HOOK_WECHAT_URL}"
    echo "  → Notification will be sent to WeChat Work"
else
    echo "⚠ Warning: CLAUDE_HOOK_WECHAT_URL not set"
    echo "  → Notification will be skipped, but hook processing will continue"
    echo "  → To test actual notification, set: export CLAUDE_HOOK_WECHAT_URL='your_webhook_url'"
fi
echo ""

# Execute hook script
echo "=== Executing hook.sh ==="
echo ""

if echo "${TEST_INPUT}" | "${SCRIPT_DIR}/hook.sh" 2>&1; then
    echo ""
    echo "=== ✓ Test Complete - Hook executed successfully ==="
else
    echo ""
    echo "=== ✗ Test Failed - Hook execution failed ==="
    exit 1
fi
