#!/bin/bash

#VERSION="1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HA_DIR="$(dirname "$SCRIPT_DIR")"

PACKAGES_DIR="$HA_DIR/packages"
AUTOMATIONS_DIR="$HA_DIR/automations"
SENSORS_DIR="$SCRIPT_DIR/sensors"

# --- Load config
CFG_FILE="$SCRIPT_DIR/codexhome.cfg"
if [ ! -f "$CFG_FILE" ]; then
  echo "Error: codexhome.cfg not found at $CFG_FILE"
  exit 1
fi
source "$CFG_FILE"

# --- Mode parameter (optional, default: all)
MODE="${1:-all}"
if [ "$MODE" != "all" ] && [ "$MODE" != "motion" ] && [ "$MODE" != "system" ]; then
  echo "Usage: $0 [all|motion|system]"
  exit 1
fi

# --- Validate LANG from config
if [ -z "$LANG" ]; then
  echo "Error: LANG is not set in codexhome.cfg — set it to DE or EN"
  exit 1
fi
if [ "$LANG" != "DE" ] && [ "$LANG" != "EN" ]; then
  echo "Error: LANG=\"$LANG\" is invalid in codexhome.cfg — must be DE or EN"
  exit 1
fi

# --- Localized entity names
if [ "$LANG" = "DE" ]; then
  NAME_DAY_MODE="Tagesmodus"
  NAME_DAY="Tag"
  NAME_EVENING="Abend"
  NAME_NIGHT="Nacht"
  NAME_MOTION_DAY="Bewegung Tag"
  NAME_MOTION_EVENING="Bewegung Abend"
  NAME_MOTION_NIGHT="Bewegung Nacht"
  NAME_MOTION="Bewegung"
  NAME_REMINDER_ALARM="Alarm Erinnerung"
  NAME_REMINDER="Erinnerung"
  NAME_REMINDER_SENSOR="Erinnerung"
else
  NAME_DAY_MODE="Day Mode"
  NAME_DAY="Day"
  NAME_EVENING="Evening"
  NAME_NIGHT="Night"
  NAME_MOTION_DAY="Motion Day"
  NAME_MOTION_EVENING="Motion Evening"
  NAME_MOTION_NIGHT="Motion Night"
  NAME_MOTION="Motion"
  NAME_REMINDER_ALARM="Reminder Alarm"
  NAME_REMINDER="Reminder"
  NAME_REMINDER_SENSOR="Reminder"
fi

DEPLOY_DATE=$(date +%Y%m%d)

mkdir -p "$PACKAGES_DIR" "$AUTOMATIONS_DIR" "$SENSORS_DIR"

# ---------------------------------------------------------------------------
deploy_system() {
  echo "Deploying system (day mode + reminder)..."

  # Day mode package
  cp "$SCRIPT_DIR/template_package_day_mode.yaml" "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i 's/#VERSION="\([^"]*\)"/#VERSION="\1" - deployed '"${DEPLOY_DATE}"'/g' "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_DAY_MODE_PLACEHOLDER/$NAME_DAY_MODE/g" "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_DAY_PLACEHOLDER/$NAME_DAY/g"           "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_EVENING_PLACEHOLDER/$NAME_EVENING/g"   "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_NIGHT_PLACEHOLDER/$NAME_NIGHT/g"       "$PACKAGES_DIR/tech_day_mode.yaml"

  # Day mode automation
  cp "$SCRIPT_DIR/template_automation_day_mode.yaml" "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i 's/#VERSION="\([^"]*\)"/#VERSION="\1" - deployed '"${DEPLOY_DATE}"'/g' "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_DAY_PLACEHOLDER/$NAME_DAY/g"               "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_EVENING_PLACEHOLDER/$NAME_EVENING/g"       "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_NIGHT_PLACEHOLDER/$NAME_NIGHT/g"           "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/SUNRISE_OFFSET_PLACEHOLDER/$SUNRISE_OFFSET/g"   "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NIGHT_TIME_PLACEHOLDER/$NIGHT_TIME/g"           "$AUTOMATIONS_DIR/tech_day_mode.yaml"

  # Reminder package
  cp "$SCRIPT_DIR/template_package_reminder.yaml" "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i 's/#VERSION="\([^"]*\)"/#VERSION="\1" - deployed '"${DEPLOY_DATE}"'/g' "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s/NAME_REMINDER_ALARM_PLACEHOLDER/$NAME_REMINDER_ALARM/g"   "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s/NAME_REMINDER_PLACEHOLDER/$NAME_REMINDER/g"               "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s/NAME_REMINDER_SENSOR_PLACEHOLDER/$NAME_REMINDER_SENSOR/g" "$PACKAGES_DIR/tech_reminder.yaml"

  echo "Done: system"
}

# ---------------------------------------------------------------------------
deploy_motion() {
  ROOMS_FILE="$SCRIPT_DIR/rooms.cfg"
  if [ ! -f "$ROOMS_FILE" ]; then
    echo "Error: rooms.cfg not found at $ROOMS_FILE"
    exit 1
  fi
  readarray -t ROOMS < "$ROOMS_FILE"

  echo "Deploying motion for ${#ROOMS[@]} room(s)..."

  for room in "${ROOMS[@]}"; do
    ROOM_UPPER="$room"
    ROOM_LOWER=$(echo "$room" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '-' '_')

    # Package
    cp "$SCRIPT_DIR/template_package_motion.yaml" "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i 's/#VERSION="\([^"]*\)"/#VERSION="\1" - deployed '"${DEPLOY_DATE}"'/g' "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/Room/${ROOM_UPPER}/g"                                                          "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/room/${ROOM_LOWER}/g"                                                          "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_DAY_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION_DAY}/g"               "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_EVENING_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION_EVENING}/g"       "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_NIGHT_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION_NIGHT}/g"           "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION}/g"                       "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"

    # Automation
    cp "$SCRIPT_DIR/template_automation_motion.yaml" "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i 's/#VERSION="\([^"]*\)"/#VERSION="\1" - deployed '"${DEPLOY_DATE}"'/g' "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/Room/${ROOM_UPPER}/g"                                                          "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/room/${ROOM_LOWER}/g"                                                          "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_DAY_PLACEHOLDER/${NAME_DAY}/g"                                            "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_EVENING_PLACEHOLDER/${NAME_EVENING}/g"                                    "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_NIGHT_PLACEHOLDER/${NAME_NIGHT}/g"                                        "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"

    # Sensor stub
    SENSOR_FILE="$SENSORS_DIR/${ROOM_LOWER}_sensors.yaml"
    if [ ! -f "$SENSOR_FILE" ]; then
      cat > "$SENSOR_FILE" <<EOF
# Sensor list for ${ROOM_UPPER}
# Add your binary_sensor entity IDs here

- binary_sensor.${ROOM_LOWER}_presence_a
EOF
      echo "Created sensor stub: $SENSOR_FILE"
    else
      echo "Skipped sensor stub (exists): $SENSOR_FILE"
    fi

    echo "Deployed: $ROOM_UPPER"
  done

  echo "Done: motion"
}

# ---------------------------------------------------------------------------
case "$MODE" in
  all)
    deploy_system
    deploy_motion
    ;;
  system)
    deploy_system
    ;;
  motion)
    deploy_motion
    ;;
esac

echo "Restarting HA..."
ha core restart
