#!/bin/bash
# Codex Home – Änderungen speichern
# Einfach doppelklicken – kein Vorwissen nötig.
# Falls Apple das Ausführen nicht erlaubt:
# xattr -d com.apple.quarantine $HOME/Library/Mobile Documents/com~apple~CloudDocs/codexhome/30_Vorlagen/HA/codexhomehub.command

# ── Konfiguration ────────────────────────────────────────────────────────────
REPO_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/codexhome/30_Vorlagen/HA"
# Falls das Repo woanders liegt, diesen Pfad anpassen ↑
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Hilfsfunktion: Fehlermeldung als Dialog anzeigen und beenden
error() {
  osascript -e "display dialog \"❌ Fehler:\n\n$1\" buttons {\"OK\"} default button \"OK\" with icon stop with title \"Codex Home\""
  exit 1
}

# Hilfsfunktion: Erfolgsmeldung
success() {
  osascript -e "display dialog \"$1\" buttons {\"OK\"} default button \"OK\" with icon note with title \"Codex Home\""
}

# ── Schritt 1: Repo-Ordner prüfen ────────────────────────────────────────────
if [ ! -d "$REPO_DIR/.git" ]; then
  error "Ordner nicht gefunden oder kein Codex-Projekt:\n$REPO_DIR\n\nBitte den Pfad im Skript anpassen."
fi

cd "$REPO_DIR"

# ── Schritt 2: Gibt es überhaupt Änderungen? ─────────────────────────────────
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  success "✅ Alles aktuell – keine neuen Änderungen gefunden."
  exit 0
fi

# ── Schritt 3: Beschreibung abfragen ─────────────────────────────────────────
BESCHREIBUNG=$(osascript -e '
tell application "System Events"
  set antwort to display dialog "Was hast du geändert?\n\n(Kurze Beschreibung, z. B. \"Licht Wohnzimmer angepasst\")" ¬
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
') || true

# Abbruch
if [ -z "$BESCHREIBUNG" ]; then
  exit 0
fi

# Leere Beschreibung abfangen
if [ -z "$(echo "$BESCHREIBUNG" | tr -d '[:space:]')" ]; then
  error "Bitte eine kurze Beschreibung eingeben."
fi

# ── Schritt 4: Änderungen einpacken und hochladen ────────────────────────────
git add -A
git commit -m "$BESCHREIBUNG" --author="Codex Home <home@codexhome.de>"
git push origin master 2>&1 || error "Hochladen fehlgeschlagen.\n\nBitte prüfe deine Internetverbindung oder frage den Administrator."

# ── Fertig ────────────────────────────────────────────────────────────────────
success "✅ Gespeichert!\n\n\"$BESCHREIBUNG\"\n\nDeine Änderungen wurden erfolgreich übertragen.\n\nHA aktualisieren: 'cd /config/codexhomehub && git pull'"
