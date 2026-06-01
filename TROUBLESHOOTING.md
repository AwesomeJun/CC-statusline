# Troubleshooting

## Windows — blank statusline and/or empty bash windows keep popping up

### Symptoms
- The statusline area is empty (no model / no bars).
- Several blank terminal windows appear, e.g.
  `/usr/bin/bash --login -i C:\Users\<you>\.claude\awesome-statusline.sh`,
  and a new one is added on every statusline refresh.

### Cause
1. **Blank windows** — `settings.json` pointed `statusLine.command` at a **bare
   `.sh` path**. On Windows a `.sh` path is launched through its *file
   association*, which is Git Bash's `bash --login -i …`. The `-i` flag opens an
   interactive window, and stdin/stdout never reach Claude Code.
2. **Blank content** — the script parses its JSON input with `jq`. If `jq` is not
   on `PATH` (common right after a `winget install`, before the PATH shim is
   active) every `jq` call fails and all values come out empty.

### Fix — automatic (recommended)
Re-run the installer. As of this version it:
- sets the command to **`bash ~/.claude/awesome-statusline.sh`** (runs the file as
  a script, so no association window is spawned), and
- copies a **`jq.exe` next to the script** in `~/.claude`. The script prepends its
  own directory to `PATH` at runtime, so that bundled `jq` is always found.

```powershell
./install.ps1            # or ./install.ps1 l   (xs/s/m/l/xl)
```

Then restart Claude Code. Any blank windows already open can be closed — no new
ones will be created.

### Fix — manual
1. `~/.claude/settings.json` →
   ```json
   "statusLine": { "type": "command", "command": "bash ~/.claude/awesome-statusline.sh" }
   ```
2. Put `jq.exe` where the script can find it — copy it into `~/.claude` (the
   script adds its own folder to `PATH`), or add `jq` to your system `PATH`.

---

## macOS / Linux — statusline characters wrap one-per-line inside tmux

### Symptoms
Inside a `tmux` session each glyph of the statusline is pushed onto its own line
(the bars and `38% / Usage / N/A` stack vertically). Outside tmux it renders fine.

### Cause
The statusline emits 24-bit **truecolor** escapes (`\033[38;2;r;g;bm`), **emoji**,
and **Unicode block glyphs** (`█`, `░`). When tmux is not configured for truecolor
(`RGB`/`Tc` capability missing), the display-width Claude Code computes for each
cell disagrees with what tmux actually draws, the cursor drifts, and cells wrap.

### Fix
Add truecolor support to `~/.tmux.conf`, then reload tmux:

```tmux
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:RGB"
```

```bash
tmux kill-server   # or: tmux source-file ~/.tmux.conf  (then restart the session)
```

If wrapping persists after enabling truecolor, the cause is emoji/wide-glyph
width rather than color — switch to a lighter mode (`compact` / `small`), which
uses fewer wide glyphs.
