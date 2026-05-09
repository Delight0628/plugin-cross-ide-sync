# Plugin Configuration Mappings

This document provides ready-to-use sync configurations for popular VS Code extensions.

## Roo Code (rooveterinaryinc.roo-cline)

**Purpose**: AI coding assistant with MCP support

```yaml
- pluginId: "rooveterinaryinc.roo-cline"
  share:
    - "globalStorage/settings/"
    - "globalStorage/cache/"
    - "globalStorage/tasks/"
    - "globalStorage/modes/"
  isolate: []
```

**Directory Structure**:
```
globalStorage/rooveterinaryinc.roo-cline/
├── settings/
│   ├── mcp_settings.json        # MCP server configuration
│   └── custom_modes.yaml        # Custom mode definitions
├── cache/
│   ├── openrouter_models.json   # Model list cache
│   ├── requesty_models.json
│   └── roo_models.json
└── tasks/
    ├── _index.json              # Task index
    └── <task-id>/
        ├── api_conversation_history.json
        ├── history_item.json
        ├── task_metadata.json
        └── ui_messages.json
```

## GitHub Copilot (github.copilot)

**Purpose**: AI pair programmer

```yaml
- pluginId: "github.copilot"
  share:
    - "globalStorage/github.copilot/settings/"
  isolate:
    - "globalStorage/github.copilot/chat/"
    - "globalStorage/github.copilot-sessions/"
```

**Note**: Chat history is IDE-specific to maintain context separation.

## Cursor-Specific (cursor)

**Purpose**: AI-first editor (built-in, no extension needed)

```yaml
- pluginId: "cursor-built-in"
  share:
    - "globalStorage/ai-settings/"
  isolate:
    - "globalStorage/project-history/"
    - "globalStorage/cursor-id/"
```

## Tabnine (tabnine)

**Purpose**: AI code completion

```yaml
- pluginId: "tabnine.tabnine-vscode"
  share:
    - "globalStorage/config.json"
  isolate:
    - "globalStorage/user-data/"
```

## Prettier (esbenp.prettier-vscode)

**Purpose**: Code formatter

```yaml
- pluginId: "esbenp.prettier-vscode"
  share:
    - "globalStorage/prettier/"
  isolate: []
```

## ESLint (dbaeumer.vscode-eslint)

**Purpose**: JavaScript/TypeScript linter

```yaml
- pluginId: "dbaeumer.vscode-eslint"
  share:
    - "globalStorage/eslint/"
  isolate: []
```

## GitLens (eamodio.gitlens)

**Purpose**: Git superpower

```yaml
- pluginId: "eamodio.gitlens"
  share: []
  isolate:
    - "globalStorage/gitlens/"
```

**Note**: GitLens stores per-repository data that should remain IDE-specific.

## Docker (ms-azuretools.vscode-docker)

**Purpose**: Container management

```yaml
- pluginId: "ms-azuretools.vscode-docker"
  share:
    - "globalStorage/docker-settings/"
  isolate:
    - "globalStorage/docker-commands/"
```

## Python (ms-python.python)

**Purpose**: Python language support

```yaml
- pluginId: "ms-python.python"
  share:
    - "globalStorage/python-env/"
  isolate:
    - "globalStorage/python-terminal/"
```

## Rust Analyzer (rust-lang.rust-analyzer)

**Purpose**: Rust language server

```yaml
- pluginId: "rust-lang.rust-analyzer"
  share: []
  isolate:
    - "globalStorage/rust-analyzer/"
```

## Terraform (hashicorp.terraform)

**Purpose**: Infrastructure as code

```yaml
- pluginId: "hashicorp.terraform"
  share:
    - "globalStorage/terraform-settings/"
  isolate:
    - "globalStorage/terraform-state/"
```

## VS Code Settings Sync

For VS Code's own settings, use this pattern:

```yaml
- pluginId: "vscode-settings"
  share:
    - "settings.json"
    - "keybindings.json"
    - "snippets/"
  isolate:
    - "globalStorage/workspaceStorage/"
```

## Custom Plugin Pattern

For any custom plugin, use this template:

```yaml
- pluginId: "<your-extension-id>"
  share:
    - "globalStorage/<shared-dir>/"
    - "workspaceState/<shared-key>/"
  isolate:
    - "globalStorage/<private-dir>/"
    - "workspaceState/<private-key>/"
  notes: |
    Description of what is shared and why.
    Any special considerations.
```

## Finding Plugin Storage Paths

Use the config scanner to discover paths:

```powershell
.\scripts\config-scanner.ps1 -Action ListPlugins
```

Or manually check:

```powershell
# Windows
Get-ChildItem "$env:APPDATA\<IDE>\User\globalStorage" -Directory

# macOS
Get-ChildItem "$HOME/Library/Application Support/<IDE>/Global/storageState" -Directory

# Linux
Get-ChildItem "$HOME/.config/<IDE>/storageState" -Directory
```
