# WeChat Work Hook for Claude Code

English | [简体中文](README_zh.md)

A hook script for Claude Code that automatically sends WeChat Work (企业微信) notifications when Claude Code sessions end or are stopped.

## Features

- 🔔 Automatic notifications on session end
- 📊 Intelligent task summarization using Claude CLI
- 🎯 Extracts project name, task status, and execution details
- 📱 Sends notifications via WeChat Work robot
- ⏰ Automatic time and device tracking

## Prerequisites

- `jq` - JSON processing tool
- `claude` CLI - Claude command line tool (optional, for intelligent task summarization)
- Git repository (for project name extraction)
- WeChat Work robot webhook URL

## Environment Variables

### Required

- `CLAUDE_HOOK_WECHAT_URL` - WeChat Work webhook URL

### Optional

- `CLAUDE_HOOK_DISABLE` - Set to `1` to temporarily disable notifications (useful for daily work when you only need notifications for long-running tasks)
- `CLAUDE_HOOK_TIMEOUT` - Claude CLI timeout in seconds (default: 30)
- `CLAUDE_HOOK_LOG_LINES` - Number of session log lines to extract and analyze (default: 10)

## Installation

### 1. Clone the Repository

Clone this project to Claude Code's hooks directory:

```bash
# Create hooks directory if it doesn't exist
mkdir -p ~/.claude/hooks

# Clone the repository
cd ~/.claude/hooks
git clone https://github.com/yore-new/WeChatWorkHookForClaudeCode.git
cd WeChatWorkHookForClaudeCode
```

> **Note**: The hook configuration examples in this README assume the project is located at `~/.claude/hooks/WeChatWorkHookForClaudeCode/`. If you install it elsewhere, adjust the paths accordingly.

### 2. Configure Environment Variables

Copy the example configuration file:

```bash
cp .env.example .env
```

Edit `.env` and set your WeChat Work webhook URL:

```bash
CLAUDE_HOOK_WECHAT_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
```

Load the environment variables:

```bash
source .env
```

Or add to your shell profile (`~/.bashrc` / `~/.zshrc`):

```bash
# Claude Hook notification configuration
export CLAUDE_HOOK_WECHAT_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
```

### 3. Install Dependencies

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Install Claude CLI (if not already installed)
# Follow instructions at https://docs.claude.com/en/docs/claude-code/overview
```

### 4. Configure Claude Code Hooks

Add the hook to your Claude Code configuration file (`~/.claude/settings.json`):

#### Recommended: Use Stop Event (for long-running tasks)

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/WeChatWorkHookForClaudeCode/hook.sh"
          }
        ]
      }
    ]
  }
}
```

> **Why Stop instead of SessionEnd?**
> - **Stop** triggers when Claude completes each response - perfect for long-running task notifications
> - **SessionEnd** only triggers when you explicitly `/clear` or exit - rarely happens during normal development workflow
> - For real-world usage, you typically start a long task, get notified when it's done, then continue working without ending the session

#### Alternative: Use SessionEnd (for session summaries)

Only use this if you want notifications when explicitly ending sessions:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/WeChatWorkHookForClaudeCode/hook.sh"
          }
        ]
      }
    ]
  }
}
```

## Usage

### Automatic Triggering

After configuration, notifications will be automatically sent when:

- **Stop** - When Claude completes a task response (Note: This hook does NOT run if stopped by user interruption)
- **SessionEnd** - When a session terminates, including:
  - Clearing session via `/clear` command
  - User logout
  - User exit
  - Other session end reasons

> For more information about hooks, see the [Claude Code Hooks Documentation](https://docs.claude.com/en/docs/claude-code/hooks)

### Best Practices for Real-World Usage

#### Scenario 1: Daily Development (Quick Interactions)

For normal, quick development sessions where you don't need notifications:

```bash
# Add to your ~/.zshrc or ~/.bashrc to disable by default
export CLAUDE_HOOK_DISABLE=1
```

This prevents notification spam during regular coding sessions.

#### Scenario 2: Long-Running Tasks

When starting a task that will take significant time (refactoring, large analysis, etc.):

**Option A: Enable for current shell session**
```bash
# Temporarily enable notifications
unset CLAUDE_HOOK_DISABLE

# Work with Claude...
# You'll get notified when task completes

# Disable again when done
export CLAUDE_HOOK_DISABLE=1
```

**Option B: Enable for single command**
```bash
# Only enable for this specific session
CLAUDE_HOOK_DISABLE=0 claude
```

#### Scenario 3: Recommended Workflow

```bash
# 1. Start your day with notifications disabled (in your shell profile)
export CLAUDE_HOOK_DISABLE=1

# 2. When you need a long-running task notification
unset CLAUDE_HOOK_DISABLE

# 3. Start the task in Claude Code
# "Please analyze this entire codebase and refactor the authentication module"

# 4. Go do something else (coffee, meetings, other work)

# 5. Get WeChat Work notification when Claude completes → Stop event triggers

# 6. Come back and review the results

# 7. Continue working or disable notifications again
export CLAUDE_HOOK_DISABLE=1
```

#### Why This Approach Works

- ✅ **Stop event** catches task completion without requiring `/clear` or exit
- ✅ Typical workflow: start task → Claude finishes → you continue the conversation
- ✅ **SessionEnd** would miss this completely (only triggers on explicit session termination)
- ✅ Use `CLAUDE_HOOK_DISABLE` to control when you want notifications

### Manual Testing

Run the self-contained test script (creates mock session data):

```bash
./test_hook.sh
```

The test script creates its own mock session data, so you can run it immediately after installation.

Or manually construct test input with a real session log:

```bash
cat <<EOF | ./hook.sh
{
  "session_id": "test-session",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "$(pwd)",
  "hook_event_name": "SessionEnd"
}
EOF
```

## How It Works

1. **Receive Hook Event** - Reads Claude hook input from stdin
2. **Filter Event Type** - Only processes Stop and SessionEnd events
3. **Extract Session Info** - Gets last N log records from session
4. **Get Project Info** - Extracts project name from git repository
5. **Intelligent Summary** - Uses Claude CLI to analyze and summarize task information
6. **Send Notification** - Sends formatted notification via WeChat Work robot

## Notification Content

The notification message includes:

- 📦 **Project Name** - Automatically extracted from git repository
- 📋 **Task Name** - Intelligently summarized by Claude
- ✅ **Task Status** - SUCCESS/FAILED/IN_PROGRESS
- 💻 **Device Info** - Execution device (user@hostname)
- ⏰ **Time** - Automatically recorded timestamp
- 🔖 **Session ID** - Claude session identifier
- 📝 **Task Details** - Detailed description (~100 words)

## Configuration

### Adjust Log Lines to Extract

Set the environment variable to extract more context:

```bash
export CLAUDE_HOOK_LOG_LINES=20  # Extract last 20 lines (default: 10)
```

### Temporarily Disable Notifications

For daily work sessions where you don't need notifications:

```bash
export CLAUDE_HOOK_DISABLE=1
# Now all sessions will run without sending notifications

# To re-enable, unset the variable
unset CLAUDE_HOOK_DISABLE
```

Or disable for just one session:

```bash
CLAUDE_HOOK_DISABLE=1 claude <your-command>
```

### Adjust Claude CLI Timeout

If Claude CLI takes longer to analyze:

```bash
export CLAUDE_HOOK_TIMEOUT=45  # Increase timeout to 45 seconds (default: 30)
```

> ⚠️ **Warning**: Claude Code hooks have a total timeout of 60 seconds. Ensure `CLAUDE_HOOK_TIMEOUT` is set to less than 60 seconds to allow time for other operations (such as sending notifications). Maximum recommended value is 45 seconds.

### Customize Notification Template

Edit `templates/notification.md` to customize the message format.

### Customize Claude Prompt

Edit `templates/task_info_prompt.txt` to adjust summarization requirements.

### Save Hook Logs

Hook logs are output to both stdout and stderr. To save them for debugging:

#### Option 1: Redirect to a log file

Modify your Claude Code hook configuration:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/wechat-bot/hook.sh >> /path/to/hook.log 2>&1"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/wechat-bot/hook.sh >> /path/to/hook.log 2>&1"
          }
        ]
      }
    ]
  }
}
```

#### Option 2: Use a wrapper script (daily rotation)

Create `hook_with_logging.sh`:

```bash
#!/usr/bin/env bash
LOG_DIR="${HOME}/.claude/hook-logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/hook-$(date +%Y%m%d).log"

/path/to/wechat-bot/hook.sh >> "${LOG_FILE}" 2>&1
```

Make it executable and use it in your Claude Code configuration:

```bash
chmod +x hook_with_logging.sh
```

#### Option 3: Per-session logs with live output

```bash
#!/usr/bin/env bash
LOG_DIR="${HOME}/.claude/hook-logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/hook-$(date +%Y%m%d-%H%M%S).log"

/path/to/wechat-bot/hook.sh 2>&1 | tee -a "${LOG_FILE}"
```

This method allows you to see the output in real-time while also saving to file.

The log file will contain:

- Hook execution timestamps
- Session IDs
- Project and branch information
- Claude CLI output and errors
- Notification send results

## File Structure

```text
wechat-bot/
├── hook.sh                      # Main hook script
├── notification.sh              # Notification sender
├── test_hook.sh                 # Test script (self-contained, creates mock data)
├── templates/
│   ├── notification.md          # Notification template
│   └── task_info_prompt.txt     # Claude prompt for task summarization
├── .env.example                 # Environment configuration template
├── .gitignore                   # Git ignore rules
├── CHANGELOG.md                 # Version history
├── LICENSE                      # MIT License
├── README.md                    # English documentation
└── README_zh.md                 # Chinese documentation
```

## Troubleshooting

### Claude CLI Not Installed

If Claude CLI is not installed or configured, the script will use default values:

- TaskName: "Claude Session"
- TaskStatus: "COMPLETED"
- TaskDetails: "Session ended. Please check session log for details."

### Notification URL Not Configured

If `CLAUDE_HOOK_WECHAT_URL` is not set, the script will output notification content but skip sending:

```bash
[ERROR] Warning: CLAUDE_HOOK_WECHAT_URL not configured, skipping notification
[INFO] Notification content:
{...}
```

### View Detailed Logs

Hook script logs are output to stdout and stderr. By default, you can view them in Claude Code logs. To save logs persistently, see the [Save Hook Logs](#save-hook-logs) section in Configuration.

## Extending

You can extend this project to:

- Support more notification channels (DingTalk, Slack, etc.)
- Add support for more event types
- Customize task status detection logic
- Integrate more project information extraction methods

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

Created for Claude Code users who want automated session notifications.
