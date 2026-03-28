#!/bin/bash
#VERSION="4"
# xattr -d com.apple.quarantine $HOME/Library/Mobile Documents/com~apple~CloudDocs/codexhome/30_Vorlagen/HA/codexhomehub.command

REPO_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/codexhome/30_Vorlagen/HA"

set -euo pipefail

error() {
  osascript <<APPLESCRIPT
display dialog "❌ Fehler:\n\n$1" buttons {"OK"} default button "OK" with icon stop with title "Codex Home"
APPLESCRIPT
  exit 1
}

success() {
  osascript <<APPLESCRIPT
display dialog "$1" buttons {"OK"} default button "OK" with icon note with title "Codex Home"
APPLESCRIPT
}

if [ ! -d "$REPO_DIR/.git" ]; then
  error "Ordner nicht gefunden oder kein Codex-Projekt:\n$REPO_DIR\n\nBitte den Pfad im Skript anpassen."
fi

cd "$REPO_DIR"

if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  success "✅ Alles aktuell – keine neuen Änderungen gefunden."
  exit 0
fi

BESCHREIBUNG=$(osascript <<'APPLESCRIPT'
tell application "System Events"
  set antwort to display dialog "Was hast du geändert?" ¬
    default answer "" ¬
    buttons {"Abbrechen", "Speichern"} ¬
    default button "Speichern" ¬
    with title "Codex Home – Änderungen speichern"
  if button returned of antwort is "Abbrechen" then
    return ""
  else
    return text returned of antwort
  end if
end tell
APPLESCRIPT
) || true

if [ -z "$BESCHREIBUNG" ]; then
  exit 0
fi

if [ -z "$(echo "$BESCHREIBUNG" | tr -d '[:space:]')" ]; then
  error "Bitte eine kurze Beschreibung eingeben."
fi

git add -A
git commit -m "$BESCHREIBUNG" --author="Codex Home <home@codexhome.de>"
git push origin master 2>&1 || error "Hochladen fehlgeschlagen."

# Build message in bash to avoid quote issues inside AppleScript heredoc
MSG="✅ Gespeichert!\n\n${BESCHREIBUNG}\n\nDeine Änderungen wurden erfolgreich übertragen.\n\nHA aktualisieren: 'cd /config/codexhomehub && git pull'"

success "$MSG"
