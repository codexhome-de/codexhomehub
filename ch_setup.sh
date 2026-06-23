#!/bin/bash

MODE="${1}"
if [ "$MODE" != "all" ]
&& [ "$MODE" != "init" ]
&& [ "$MODE" != "motion" ]
&& [ "$MODE" != "system" ]
then
  echo "Usage: $0 [all|init|motion|system]"
  exit 1
fi

DEPLOY_DATE=$(date +%Y%m%d)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HA_DIR="$(dirname "$SCRIPT_DIR")"
PACKAGES_DIR="$HA_DIR/packages"
AUTOMATIONS_DIR="$HA_DIR/automations"
SENSORS_DIR="$SCRIPT_DIR/sensors"

# --- Load config
CH_CONFIG="ch_config.cfg"
CFG_FILE="$SCRIPT_DIR/$CH_CONFIG"
if [ ! -f "$CFG_FILE" ]; then
  echo "Error: $CH_CONFIG not found at $CFG_FILE"
  exit 1
else
  source "$CFG_FILE"
fi

# --- Validate LANGUAGE from config
if [ "$LANGUAGE" != "DE" ] && [ "$LANGUAGE" != "EN" ]; then
  echo "Error: LANGUAGE=\"$LANGUAGE\" is invalid in $CH_CONFIG — must be DE or EN"
  exit 1
else
  source "ch_lang_$LANGUAGE.cfg"
fi

ch_init() {
  echo -e "----------\nStart: init\n----------"

  mkdir -p "$PACKAGES_DIR" "$AUTOMATIONS_DIR"

  # --- Update configuration.yaml
  HA_CONFIG="$HA_DIR/configuration.yaml"

  if [ -f "$HA_CONFIG" ]; then
    echo "Updating $HA_CONFIG..."

    # Replace automation line with dir merge list
    sed -i 's|^automation:.*|automation: !include_dir_merge_list automations/|' "$HA_CONFIG"

    # Append blocks if not already present
    if ! grep -q "packages:" "$HA_CONFIG"; then
      cat >> "$HA_CONFIG" << 'EOF'

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
    echo "Error: HomeAssistant configuration file not found at: $HA_CONFIG"
    exit 1
  fi

  # --- Add alias to .bash_profile
  PROFILE="/data/.bash_profile"
  touch "$PROFILE"
  if ! grep -q "alias ch_update" "$PROFILE"; then
    cat >> "$PROFILE" << 'EOF'
alias ch_update='cd /homeassistant/codexhomehub && git pull'
EOF
  fi

  echo -e "----------\nDone: init\n----------"
}

ch_system() {
  echo -e "----------\nStart: system\n----------"

  # Day mode package
  cp "$SCRIPT_DIR/template_package_day_mode.yaml"         "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"  "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_DAY_MODE_PLACEHOLDER/$NAME_DAY_MODE/g"   "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_DAY_PLACEHOLDER/$NAME_DAY/g"             "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_EVENING_PLACEHOLDER/$NAME_EVENING/g"     "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_NIGHT_PLACEHOLDER/$NAME_NIGHT/g"         "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_PARTY_PLACEHOLDER/$NAME_PARTY/g"         "$PACKAGES_DIR/tech_day_mode.yaml"

  # Day mode automation
  cp "$SCRIPT_DIR/template_automation_day_mode.yaml"      "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"  "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_DAY_PLACEHOLDER/$NAME_DAY/g"             "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_EVENING_PLACEHOLDER/$NAME_EVENING/g"     "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_NIGHT_PLACEHOLDER/$NAME_NIGHT/g"         "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/SUNRISE_OFFSET_PLACEHOLDER/$SUNRISE_OFFSET/g" "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/SUNSET_OFFSET_PLACEHOLDER/$SUNSET_OFFSET/g"   "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NIGHT_TIME_PLACEHOLDER/$NIGHT_TIME/g"         "$AUTOMATIONS_DIR/tech_day_mode.yaml"

  # Reminder package
  cp "$SCRIPT_DIR/template_package_reminder.yaml"                     "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"              "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s/NAME_REMINDER_ALARM_PLACEHOLDER/$NAME_REMINDER_ALARM/g"   "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s/NAME_REMINDER_PLACEHOLDER/$NAME_REMINDER/g"               "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s/NAME_REMINDER_SENSOR_PLACEHOLDER/$NAME_REMINDER_SENSOR/g" "$PACKAGES_DIR/tech_reminder.yaml"

  echo -e "----------\nDone: system\n----------"
}

ch_motion() {
  echo -e "----------\nStart: motion\n----------"

  ROOMS_FILE="$SCRIPT_DIR/ch_rooms.cfg"
  ROOMS_EXAMPLE="$SCRIPT_DIR/template_rooms.cfg"
  if [ ! -f "$ROOMS_FILE" ]; then
    if [ -f "$ROOMS_EXAMPLE" ]; then
      cp "$ROOMS_EXAMPLE" "$ROOMS_FILE"
      echo "Created $ROOMS_FILE from example — edit it with your rooms, then re-run."
    else
      echo "Error: $ROOMS_FILE not found and no $ROOMS_EXAMPLE to seed from."
    fi
    exit 1
  fi
  readarray -t ROOMS < "$ROOMS_FILE"

  echo "Deploying motion for ${#ROOMS[@]} room(s)..."

  for room in "${ROOMS[@]}"; do
    ROOM_UPPER="$room"
    ROOM_LOWER=$(echo "$room" \
      | tr '[:upper:]' '[:lower:]' \
      | tr ' ' '_' | tr '-' '_' \
      | sed -e 's/Ä/ae/g; s/Ö/oe/g; s/Ü/ue/g; s/ä/ae/g; s/ö/oe/g; s/ü/ue/g; s/ß/ss/g')
    ROOM_LOWER=$(echo "$room" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '-' '_')

    # Package
    cp "$SCRIPT_DIR/template_package_motion.yaml"                                     "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"                            "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/ROOM_UPPER_PLACEHOLDER/${ROOM_UPPER}/g"                                 "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/ROOM_LOWER_PLACEHOLDER/${ROOM_LOWER}/g"                                 "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_DAY_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION_DAY}/g"         "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_EVENING_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION_EVENING}/g" "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_NIGHT_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION_NIGHT}/g"     "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION}/g"                 "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"

    # Automation
    cp "$SCRIPT_DIR/template_automation_motion.yaml"        "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"  "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/ROOM_UPPER_PLACEHOLDER/${ROOM_UPPER}/g"       "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/ROOM_LOWER_PLACEHOLDER/${ROOM_LOWER}/g"       "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_DAY_PLACEHOLDER/${NAME_DAY}/g"           "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_EVENING_PLACEHOLDER/${NAME_EVENING}/g"   "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_NIGHT_PLACEHOLDER/${NAME_NIGHT}/g"       "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"

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
  done
  echo -e "----------\nDone: motion\n----------"
}

case "$MODE" in
  all)
    ch_init
    ch_system
    ch_motion
    ;;
  init)
    ch_init
    ;;
  system)
    ch_system
    ;;
  motion)
    ch_motion
    ;;
esac

echo -e "----------\nRestart: HomeAssistant!\n----------"
ha core restart
