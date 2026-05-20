# Awesome Claude Plugins — Claude Code Setup

This guide walks through installing the Awesome Statusline plugin from start to finish. The steps below are ordered and meant to be followed sequentially.

---

## Prerequisites

`jq` is required for JSON parsing in the statusline script.

```bash
# macOS
which jq || brew install jq

# Linux (Debian/Ubuntu) / WSL
which jq || sudo apt-get install -y jq

# Windows (PowerShell — winget, choco, or scoop)
# winget install jqlang.jq
# choco install jq
# scoop install jq
```

Verify:
```bash
jq --version
```

---

## Step 1: Add the Marketplace

Run this command inside Claude Code (not in a regular terminal):

```
/plugin marketplace add awesomejun/awesome-claude-plugins
```

If already added, this step will be skipped automatically.

### Enable Auto-Update

Third-party marketplaces have auto-update **disabled by default**. Enable it so the plugin stays up to date automatically.

**Option A — UI:** Go to `/plugin` → **Marketplaces** tab → select `awesome-claude-plugins` → **Enable auto-update**.

**Option B — Edit `~/.claude/settings.json` manually.** Find the `extraKnownMarketplaces` → `awesome-claude-plugins` entry and set `"autoUpdate": true`, preserving all other existing settings. The relevant shape looks like this:

```json
{
  "extraKnownMarketplaces": {
    "awesome-claude-plugins": {
      "source": { "source": "github", "repo": "awesomejun/awesome-claude-plugins" },
      "autoUpdate": true
    }
  }
}
```

If `autoUpdate` is already `true`, this step is already done.

---

## Step 2: Install the Plugin

```
/plugin install awesome-statusline@awesome-claude-plugins
```

This installs:
- Statusline shell scripts (Compact, Default, Full, Legacy modes)
- Slash commands (`/awesome-statusline-start`, `/awesome-statusline-mode`, `/awesome-statusline-remove`)

---

## Step 3: Run the Setup Wizard

```
/awesome-statusline-start
```

The wizard guides you through:
1. **Version selection** — v2.1.1 (latest) or Legacy
2. **Mode selection** — Compact (2 lines) / Default (2 lines) / Full (5 lines)
3. **Installation** — Copies script to `~/.claude/awesome-statusline.sh` and configures `settings.json`

---

## Step 4: Verify

Restart Claude Code. You should see the Catppuccin-themed statusline at the top of your terminal showing:
- Model name, Git status, Context usage
- 5H / 7D API rate limit bars (if available)

---

## Star This Repository

If the statusline turns out useful, a star on the GitHub repo helps other developers discover it. From the GitHub page, click the **Star** button, or run:

```bash
gh api user/starred/awesomejun/awesome-claude-plugins -X PUT
```

---

## Quick Install (Skip Wizard)

If you already know which mode you want:

```
/awesome-statusline-start compact    # Minimal 2-line display
/awesome-statusline-start default    # Balanced 2-line display
/awesome-statusline-start full       # Detailed 5-line display
/awesome-statusline-start legacy     # Classic 4-line design
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Statusline not showing | Restart Claude Code after installation |
| `jq: command not found` | Run `brew install jq` (macOS) or `apt install jq` (Linux) |
| Bars show "N/A" | Rate limit data requires Claude Pro/Max subscription |
| Only 1 line visible | UI rendering issue — try Compact/Default mode (2 lines) |

---

## Update

The marketplace auto-updates when configured. To manually update:

```
/plugin marketplace update awesome-claude-plugins
```

---

## Uninstall

```
/awesome-statusline-remove all
```
