# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-03

### Breaking Changes

- **Environment Variables Renamed**:
  - `NOTIFICATION_URL` → `CLAUDE_HOOK_WECHAT_URL`
  - `NO_CLAUDE_HOOK` → `CLAUDE_HOOK_DISABLE`
  - New configurable options: `CLAUDE_HOOK_TIMEOUT`, `CLAUDE_HOOK_LOG_LINES`
  - **Action required**: Update your environment configuration before upgrading

### Added

- Comprehensive header comments in all scripts explaining:
  - Purpose and functionality
  - Required/optional environment variables
  - Input/output format
  - Template system and placeholder usage
- `.env.example` file with all configurable environment variables
- Self-contained test script that creates mock session data
- Chinese documentation (README_zh.md) with language switcher
- Session ID in notification messages for tracking
- MIT License file
- Enhanced `.gitignore` for better security (including `.env` file)
- CHANGELOG.md to track version history
- Configurable timeout and log lines via environment variables

### Changed

- All code comments converted to English
- Code structure refactored following Shell script best practices
- Error handling enhanced across all scripts
- README completely rewritten in English with improved structure
- Better module separation and function organization

### Security

- Removed hardcoded sensitive webhook URLs
- All sensitive data now loaded from environment variables
- Added `.gitignore` rules to prevent accidental commits of secrets

### Removed

- `templates/notification.json` (contained sensitive data)
- `templates/notification.json.example` (unused example file for internal API)
