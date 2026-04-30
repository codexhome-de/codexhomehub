#!/bin/bash

#VERSION="1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HA_DIR="$(dirname "$SCRIPT_DIR")"

PACKAGES_DIR="$HA_DIR/packages"
AUTOMATIONS_DIR="$HA_DIR/automations"

# --- Load config
CFG_FILE="$SCRIPT_DIR/codexhome.cfg"
if [ ! -f "$CFG_FILE" ]; then
  echo "Error: codexhome.cfg not found at $CFG_FILE"
  exit 1
fi
source "$CFG_FILE"

# --- Validate LANG from config
if [ "$LANG" != "DE" ] && [ "$LANG" != "EN" ]; then
  echo "Error: LANG=\"$LANG\" is invalid in codexhome.cfg — must be DE or EN"
  echo "Error: LANG=\"$LANG\" is invalid in codexhome.cfg — must be DE or EN"
  exit 1
fi

mkdir -p "$PACKAGES_DIR" "$AUTOMATIONS_DIR"

# --- Update configuration.yaml
CONFIG="$HA_DIR/configuration.yaml"
CONFIG="$HA_DIR/configuration.yaml"

if [ -f "$CONFIG" ]; then
  echo "Updating $CONFIG..."

  # Replace automation line with dir merge list
  sed -i 's|^automation:.*|automation: !include_dir_merge_list automations/|' "$CONFIG"

  # Append blocks if not already present
  if ! grep -q "packages:" "$CONFIG"; then
    cat >> "$CONFIG" << 'EOF'

homeassistant:
  packages: !include_dir_named packages

homekit:
  - name: Codex Home
    filter:
      include_entity_globs:
        - "*_hk"
EOF
  fi
else
  echo "Warning: $CONFIG not found, skipping."
else
  echo "Warning: $CONFIG not found, skipping."
fi

# --- Add alias to .bash_profile
PROFILE="/data/.bash_profile"
touch "$PROFILE"
if ! grep -q "alias cu" "$PROFILE"; then
  cat >> "$PROFILE" << 'EOF'
alias cu='cd /homeassistant/codexhomehub && git pull'
EOF
fi

echo "Init done. Run ./deploy.sh to deploy templates."