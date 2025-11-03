# 企业微信 Hook for Claude Code

[English](README.md) | 简体中文

一个用于 Claude Code 的 Hook 脚本，当 Claude Code 会话结束或停止时自动发送企业微信通知。

## 功能特性

- 🔔 会话结束时自动发送通知
- 📊 使用 Claude CLI 智能总结任务信息
- 🎯 自动提取项目名称、任务状态和执行详情
- 📱 通过企业微信机器人发送通知
- ⏰ 自动记录时间和设备信息

## 前置要求

- `jq` - JSON 处理工具
- `claude` CLI - Claude 命令行工具（可选，用于智能任务总结）
- Git 仓库（用于提取项目名称）
- 企业微信机器人 Webhook URL

## 环境变量

### 必需配置

- `CLAUDE_HOOK_WECHAT_URL` - 企业微信 Webhook URL

### 可选配置

- `CLAUDE_HOOK_DISABLE` - 设置为 `1` 可临时禁用通知（适合日常工作，只在长时间任务时才需要通知）
- `CLAUDE_HOOK_TIMEOUT` - Claude CLI 超时时间，单位秒（默认：30）
- `CLAUDE_HOOK_LOG_LINES` - 提取并分析的 session log 行数（默认：10）

## 安装配置

### 1. 克隆项目

将本项目克隆到 Claude Code 的 hooks 目录：

```bash
# 如果 hooks 目录不存在，先创建
mkdir -p ~/.claude/hooks

# 克隆仓库
cd ~/.claude/hooks
git clone https://github.com/yore-new/WeChatWorkHookForClaudeCode.git
cd WeChatWorkHookForClaudeCode
```

> **注意**：本 README 中的 hook 配置示例假设项目位于 `~/.claude/hooks/WeChatWorkHookForClaudeCode/`。如果你安装在其他位置，请相应调整路径。

### 2. 配置环境变量

复制示例配置文件：

```bash
cp .env.example .env
```

编辑 `.env` 文件，设置你的企业微信 Webhook URL：

```bash
CLAUDE_HOOK_WECHAT_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
```

加载环境变量：

```bash
source .env
```

或者添加到你的 shell 配置文件（`~/.bashrc` / `~/.zshrc`）：

```bash
# Claude Hook 通知配置
export CLAUDE_HOOK_WECHAT_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
```

### 3. 安装依赖

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# 安装 Claude CLI（如果尚未安装）
# 访问 https://docs.claude.com/en/docs/claude-code/overview 查看安装说明
```

### 4. 配置 Claude Code Hooks

在 Claude Code 配置文件（`~/.claude/settings.json`）中添加 hook：

#### 推荐配置：使用 Stop 事件（用于长时间任务通知）

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

> **为什么用 Stop 而不是 SessionEnd？**
> - **Stop** 在 Claude 每次完成回答时触发 - 适合长时间任务完成通知
> - **SessionEnd** 只在你主动执行 `/clear` 或退出时触发 - 在正常开发流程中很少发生
> - 实际使用中，你通常是：启动长任务 → 收到完成通知 → 继续对话，而不会结束会话

#### 备选配置：使用 SessionEnd（用于会话总结）

只有在需要会话结束时才收到通知时使用此配置：

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

## 使用方法

### 自动触发

配置完成后，以下情况会自动发送通知：

- **Stop** - 当 Claude 完成任务响应时（注意：如果是用户中断，此 hook 不会触发）
- **SessionEnd** - 当会话终止时，包括：
  - 通过 `/clear` 命令清除会话
  - 用户注销
  - 用户退出
  - 其他会话结束原因

> 更多关于 hooks 的信息，请参考 [Claude Code Hooks 官方文档](https://docs.claude.com/en/docs/claude-code/hooks)

### 实际使用场景最佳实践

#### 场景 1：日常开发（快速交互）

对于正常的、快速的开发会话，不需要通知时：

```bash
# 在 ~/.zshrc 或 ~/.bashrc 中添加，默认禁用通知
export CLAUDE_HOOK_DISABLE=1
```

这样可以避免在日常编码时被通知打扰。

#### 场景 2：长时间运行的任务

当启动一个需要较长时间的任务时（重构、大型分析等）：

**方式 A：为当前 shell 会话启用**
```bash
# 临时启用通知
unset CLAUDE_HOOK_DISABLE

# 使用 Claude 工作...
# 任务完成时会收到通知

# 完成后再次禁用
export CLAUDE_HOOK_DISABLE=1
```

**方式 B：仅为单次命令启用**
```bash
# 只为这个特定会话启用通知
CLAUDE_HOOK_DISABLE=0 claude
```

#### 场景 3：推荐工作流

```bash
# 1. 在 shell 配置文件中默认禁用通知
export CLAUDE_HOOK_DISABLE=1

# 2. 当需要长时间任务通知时
unset CLAUDE_HOOK_DISABLE

# 3. 在 Claude Code 中启动任务
# "请分析整个代码库并重构认证模块"

# 4. 去做其他事情（喝咖啡、开会、处理其他工作）

# 5. Claude 完成时收到企业微信通知 → Stop 事件触发

# 6. 回来查看结果

# 7. 继续工作或再次禁用通知
export CLAUDE_HOOK_DISABLE=1
```

#### 为什么这种方式有效

- ✅ **Stop 事件**无需 `/clear` 或退出即可捕获任务完成
- ✅ 典型工作流：启动任务 → Claude 完成 → 你继续对话
- ✅ **SessionEnd** 会完全错过这种场景（只在明确终止会话时触发）
- ✅ 使用 `CLAUDE_HOOK_DISABLE` 控制何时需要通知

### 手动测试

运行自包含的测试脚本（会创建模拟会话数据）：

```bash
./test_hook.sh
```

测试脚本会自动创建模拟数据，安装后即可立即运行。

或者使用真实的 session log 手动构造测试输入：

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

## 工作原理

1. **接收 Hook 事件** - 从 stdin 读取 Claude hook 输入
2. **过滤事件类型** - 仅处理 Stop 和 SessionEnd 事件
3. **提取会话信息** - 获取最后 N 条 log 记录
4. **获取项目信息** - 从 git 仓库提取项目名称
5. **智能总结** - 使用 Claude CLI 分析并总结任务信息
6. **发送通知** - 通过企业微信机器人发送格式化通知

## 通知内容

通知消息包含以下信息：

- 📦 **项目名称** - 自动从 git 仓库提取
- 📋 **任务名称** - 由 Claude 智能总结
- ✅ **任务状态** - SUCCESS/FAILED/IN_PROGRESS
- 💻 **设备信息** - 执行设备（用户@主机名）
- ⏰ **时间** - 自动记录的时间戳
- 🔖 **会话 ID** - Claude 会话标识符
- 📝 **任务详情** - 详细描述（约 100 字）

## 配置选项

### 调整提取的日志行数

设置环境变量以提取更多上下文：

```bash
export CLAUDE_HOOK_LOG_LINES=20  # 提取最后 20 行（默认：10）
```

### 临时禁用通知

日常工作时不需要通知的情况：

```bash
export CLAUDE_HOOK_DISABLE=1
# 现在所有会话都不会发送通知

# 重新启用通知
unset CLAUDE_HOOK_DISABLE
```

或者只针对单次会话禁用：

```bash
CLAUDE_HOOK_DISABLE=1 claude <你的命令>
```

### 调整 Claude CLI 超时时间

如果 Claude CLI 分析需要更长时间：

```bash
export CLAUDE_HOOK_TIMEOUT=45  # 增加超时到 45 秒（默认：30）
```

> ⚠️ **注意**：Claude Code 的 hook 总超时时间为 60 秒。请确保 `CLAUDE_HOOK_TIMEOUT` 设置的值小于 60 秒，以留出时间给其他操作（如发送通知等）。建议最大值不超过 45 秒。

### 自定义通知模板

编辑 `templates/notification.md` 以自定义消息格式。

### 自定义 Claude Prompt

编辑 `templates/task_info_prompt.txt` 以调整总结要求。

### 保存 Hook 日志

Hook 日志同时输出到 stdout 和 stderr。保存日志用于调试：

#### 方式 1：重定向到日志文件

修改 Claude Code hook 配置：

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

#### 方式 2：使用包装脚本（按日期轮转）

创建 `hook_with_logging.sh`：

```bash
#!/usr/bin/env bash
LOG_DIR="${HOME}/.claude/hook-logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/hook-$(date +%Y%m%d).log"

/path/to/wechat-bot/hook.sh >> "${LOG_FILE}" 2>&1
```

设置可执行权限并在 Claude Code 配置中使用：

```bash
chmod +x hook_with_logging.sh
```

#### 方式 3：按会话轮转日志并实时查看

```bash
#!/usr/bin/env bash
LOG_DIR="${HOME}/.claude/hook-logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/hook-$(date +%Y%m%d-%H%M%S).log"

/path/to/wechat-bot/hook.sh 2>&1 | tee -a "${LOG_FILE}"
```

这种方式可以在保存到文件的同时实时查看输出。

日志文件包含：

- Hook 执行时间戳
- Session ID
- 项目和分支信息
- Claude CLI 输出和错误
- 通知发送结果

## 文件结构

```text
wechat-bot/
├── hook.sh                      # 主 Hook 脚本
├── notification.sh              # 通知发送器
├── test_hook.sh                 # 测试脚本（自包含，创建模拟数据）
├── templates/
│   ├── notification.md          # 通知模板
│   └── task_info_prompt.txt     # Claude 任务总结 prompt
├── .env.example                 # 环境配置模板
├── .gitignore                   # Git 忽略规则
├── CHANGELOG.md                 # 版本历史
├── LICENSE                      # MIT 许可证
├── README.md                    # 英文文档
└── README_zh.md                 # 中文文档（本文件）
```

## 故障排查

### Claude CLI 未安装

如果 Claude CLI 未安装或配置，脚本会使用默认值：

- TaskName: "Claude Session"
- TaskStatus: "COMPLETED"
- TaskDetails: "Session ended. Please check session log for details."

### 通知 URL 未配置

如果 `CLAUDE_HOOK_WECHAT_URL` 未设置，脚本会输出通知内容但跳过发送：

```bash
[ERROR] Warning: CLAUDE_HOOK_WECHAT_URL not configured, skipping notification
[INFO] Notification content:
{...}
```

### 查看详细日志

Hook 脚本的日志输出到 stdout 和 stderr。默认情况下可以在 Claude Code 日志中查看。要持久化保存日志，请参考配置选项中的[保存 Hook 日志](#保存-hook-日志)部分。

## 扩展功能

你可以扩展此项目以支持：

- 更多通知渠道（钉钉、Slack 等）
- 更多事件类型支持
- 自定义任务状态检测逻辑
- 集成更多项目信息提取方式

## 许可证

MIT License

## 贡献

欢迎贡献！请随时提交 Pull Request。

## 作者

为希望自动化会话通知的 Claude Code 用户创建。
