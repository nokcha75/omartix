#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/home"
export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$HOME/.config"
export TEST_LOG="$tmp_dir/log"

cat >"$tmp_dir/bin/dinitctl" <<'SCRIPT'
#!/bin/bash
printf 'dinitctl:%s\n' "$*" >>"$TEST_LOG"
exit 0
SCRIPT
cat >"$tmp_dir/bin/omarchy-pkg-add" <<'SCRIPT'
#!/bin/bash
printf 'add:%s\n' "$*" >>"$TEST_LOG"
SCRIPT
cat >"$tmp_dir/bin/omarchy-pkg-drop" <<'SCRIPT'
#!/bin/bash
printf 'drop:%s\n' "$*" >>"$TEST_LOG"
SCRIPT
cat >"$tmp_dir/bin/omarchy-cmd-present" <<'SCRIPT'
#!/bin/bash
[[ ${1:-} == nvidia-smi ]]
SCRIPT
chmod +x "$tmp_dir/bin/"*
export PATH="$tmp_dir/bin:$ROOT/bin:$PATH"

"$ROOT/bin/omarchy-install-ai-ollama" >/dev/null

service_file="$XDG_CONFIG_HOME/dinit.d/ollama"
boot_link="$XDG_CONFIG_HOME/dinit.d/boot.d/ollama"
[[ -f $service_file && -L $boot_link ]] ||
  fail "Ollama installs a persistent dinit user service"
grep -qx 'command = /usr/bin/ollama serve' "$service_file" ||
  fail "Ollama dinit service runs the server directly"
grep -qx 'add:ollama-cuda' "$TEST_LOG" ||
  fail "Ollama installer retains NVIDIA package selection"
grep -qx 'dinitctl:--user start ollama' "$TEST_LOG" ||
  fail "Ollama starts through dinit after installation"
pass "Ollama installation uses Artix packages and dinit"

mkdir -p "$HOME/.ollama"
touch "$HOME/.ollama/model"
"$ROOT/bin/omarchy-remove-ai-ollama" >/dev/null
[[ ! -e $service_file && ! -L $boot_link ]] ||
  fail "Ollama removal deletes its dinit user service"
[[ ! -e $HOME/.ollama ]] || fail "Ollama removal deletes the user's model store"
grep -qx 'dinitctl:--user stop ollama' "$TEST_LOG" ||
  fail "Ollama removal stops the dinit service before package removal"
grep -qx 'drop:ollama ollama-cuda ollama-rocm ollama-vulkan' "$TEST_LOG" ||
  fail "Ollama removal drops every acceleration provider"
pass "Ollama removal is dinit-native"

menu="$ROOT/default/omarchy/omarchy-menu.jsonc"
ollama_row=$(grep '^  "install.ai.ollama":' "$menu")
[[ $ollama_row == *'omarchy-install-ai-ollama'* ]] ||
  fail "Ollama menu uses the Omartix dinit-aware installer"
! rg -q '\b(systemctl|systemd-run|systemd-inhibit)\b' \
  "$ROOT/bin/omarchy-install-ai-ollama" "$ROOT/bin/omarchy-remove-ai-ollama" "$ROOT/bin/omarchy-ollama-service" ||
  fail "Ollama lifecycle has no systemd runtime path"
pass "Ollama menu and lifecycle avoid systemd"
