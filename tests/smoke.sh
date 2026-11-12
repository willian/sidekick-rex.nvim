#!/usr/bin/env sh
# Runs the backend against a fake `rex`. Needs sidekick.nvim: set SIDEKICK_PATH,
# or it is cloned into a temporary directory.
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)

# A process sidekick's claude tool matches (\<claude\>), standing in for a running CLI
sh -c 'sleep 60; :' claude &
claude_pid=$!
trap 'status=$?; kill "$claude_pid" 2>/dev/null; wait "$claude_pid" 2>/dev/null || :; rm -rf "$tmp"; exit $status' EXIT

if [ -z "${SIDEKICK_PATH:-}" ]; then
  SIDEKICK_PATH="$tmp/sidekick.nvim"
  git clone -q --depth 1 https://github.com/folke/sidekick.nvim "$SIDEKICK_PATH"
fi

# Fake rex: logs each call on one line (newlines as |) and answers split, do (process and list) and capture
cat > "$tmp/rex" <<EOF
#!/usr/bin/env sh
printf '%s' "\$*" | tr '\n' '|' >> "$tmp/log"; echo >> "$tmp/log"
case "\$3 \$4" in
  split*) printf '%s\n' '{' '  "block_ids": [' '    "block:runner"' '  ]' '}' ;;
  "do -b") printf '{"child":{"pid":$claude_pid}}\n' ;;
  "do -e") printf '[{"block_id":"block:runner","pid":$claude_pid,"fg":{"pid":$claude_pid,"name":"sh","cwd":"$repo"}}]\n' ;;
  capture*) printf 'line 1\nline 2\n' ;;
esac
EOF
chmod +x "$tmp/rex"

REPO="$repo" SIDEKICK_PATH="$SIDEKICK_PATH" FAKE_CLAUDE_PID="$claude_pid" \
  REX_SESSION=session:test REX_BLOCK=block:editor PATH="$tmp:$PATH" \
  nvim --clean --headless -l "$repo/tests/smoke.lua"

log=$tmp/log
grep -q "^-s session:test split -b block:editor --focus=false -c $repo --json --label claude --split=right --ratio 40 -- claude$" "$log"
grep -q '^-s session:test do -b block:runner com.superlogical.terminal.process --json$' "$log"
grep -q '^-s session:test send -b block:runner hello|$' "$log"
grep -q '^-s session:test send-key -b block:runner enter$' "$log"
grep -q '^-s session:test capture -b block:runner --format=vt$' "$log"
echo "ok"
