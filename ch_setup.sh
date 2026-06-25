#!/bin/bash

ch_err() {
  echo -e "Error (line $1)\n$2"
  exit 1
}

ch_file() {
  if [ ! -f "$1" ] && cp "$2" "$1" 2>/dev/null; then
    ch_err $LINENO "Created $1 from example — edit it, then re-run."
  elif [ ! -f "$1" ]; then
    ch_err $LINENO "Error: $1 not found and no $2 to seed from."
  fi
}

MODE="${1}"
case "$MODE" in
  all|init|day_mode|heatshield|motion|reminder) ;;
  *) ch_err $LINENO "Usage: $0 [all|init|day_mode|heatshield|motion|reminder]" ;;
esac

DEPLOY_DATE=$(date +%Y%m%d)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HA_DIR="$(dirname "$SCRIPT_DIR")"
PACKAGES_DIR="$HA_DIR/packages"
AUTOMATIONS_DIR="$HA_DIR/automations"
SENSORS_DIR="$SCRIPT_DIR/sensors"
mkdir -p "$PACKAGES_DIR" "$AUTOMATIONS_DIR" "$SENSORS_DIR"

ch_file "$SCRIPT_DIR/ch_config.cfg" "$SCRIPT_DIR/template_config.cfg"
source "$SCRIPT_DIR/ch_config.cfg"

if [ "$LANGUAGE" != "DE" ] && [ "$LANGUAGE" != "EN" ]; then
  ch_err $LINENO "Error: LANGUAGE=\"$LANGUAGE\" is invalid in $CH_CONFIG — must be DE or EN"
fi
source "$SCRIPT_DIR/template_lang_$LANGUAGE.cfg"

ch_init() {
  HA_CONFIG="$HA_DIR/configuration.yaml"

  if [ -f "$HA_CONFIG" ]; then
    sed -i 's|^automation:.*|automation: !include_dir_merge_list automations/|' "$HA_CONFIG"
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
    ch_err $LINENO "Error: HomeAssistant configuration file not found at: $HA_CONFIG"
  fi

  # --- Add alias to .bash_profile
  PROFILE="/data/.bash_profile"
  touch "$PROFILE"
  if ! grep -q "alias ch_update" "$PROFILE"; then
    cat >> "$PROFILE" << 'EOF'
alias ch_update='cd /homeassistant/codexhomehub && git fetch origin && git reset --hard origin/master'
EOF
  fi
}

ch_day_mode() {
  cp "$SCRIPT_DIR/template_package_day_mode.yaml"         "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"  "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_DAY_MODE_PLACEHOLDER/$NAME_DAY_MODE/g"   "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_DAY_PLACEHOLDER/$NAME_DAY/g"             "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_EVENING_PLACEHOLDER/$NAME_EVENING/g"     "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_NIGHT_PLACEHOLDER/$NAME_NIGHT/g"         "$PACKAGES_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_PARTY_PLACEHOLDER/$NAME_PARTY/g"         "$PACKAGES_DIR/tech_day_mode.yaml"

  cp "$SCRIPT_DIR/template_automation_day_mode.yaml"      "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"  "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_DAY_PLACEHOLDER/$NAME_DAY/g"             "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_EVENING_PLACEHOLDER/$NAME_EVENING/g"     "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NAME_NIGHT_PLACEHOLDER/$NAME_NIGHT/g"         "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/SUNRISE_OFFSET_PLACEHOLDER/$SUNRISE_OFFSET/g" "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/SUNSET_OFFSET_PLACEHOLDER/$SUNSET_OFFSET/g"   "$AUTOMATIONS_DIR/tech_day_mode.yaml"
  sed -i "s/NIGHT_TIME_PLACEHOLDER/$NIGHT_TIME/g"         "$AUTOMATIONS_DIR/tech_day_mode.yaml"
}

ch_reminder_alarm() {
  cp "$SCRIPT_DIR/template_package_reminder.yaml"                     "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"              "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s/NAME_REMINDER_ALARM_PLACEHOLDER/$NAME_REMINDER_ALARM/g"   "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s/NAME_REMINDER_PLACEHOLDER/$NAME_REMINDER/g"               "$PACKAGES_DIR/tech_reminder.yaml"
  sed -i "s/NAME_REMINDER_SENSOR_PLACEHOLDER/$NAME_REMINDER_SENSOR/g" "$PACKAGES_DIR/tech_reminder.yaml"
}

ch_motion() {
  ch_file "$SCRIPT_DIR/ch_rooms.cfg" "$SCRIPT_DIR/template_rooms.cfg"
  readarray -t ROOMS < "$SCRIPT_DIR/ch_rooms.cfg"

  for room in "${ROOMS[@]}"; do
    ROOM_UPPER="$room"
    ROOM_LOWER=$(echo "$room" \
      | tr '[:upper:]' '[:lower:]' \
      | tr ' ' '_' | tr '-' '_' \
      | sed -e 's/Ä/ae/g; s/Ö/oe/g; s/Ü/ue/g; s/ä/ae/g; s/ö/oe/g; s/ü/ue/g; s/ß/ss/g')
    ROOM_LOWER=$(echo "$ROOM_LOWER" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '-' '_')

    cp "$SCRIPT_DIR/template_package_motion.yaml"                                     "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"                            "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/ROOM_UPPER_PLACEHOLDER/${ROOM_UPPER}/g"                                 "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/ROOM_LOWER_PLACEHOLDER/${ROOM_LOWER}/g"                                 "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_DAY_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION_DAY}/g"         "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_EVENING_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION_EVENING}/g" "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_NIGHT_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION_NIGHT}/g"     "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_MOTION_PLACEHOLDER/${ROOM_UPPER} ${NAME_MOTION}/g"                 "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"

    cp "$SCRIPT_DIR/template_automation_motion.yaml"        "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"  "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/ROOM_UPPER_PLACEHOLDER/${ROOM_UPPER}/g"       "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/ROOM_LOWER_PLACEHOLDER/${ROOM_LOWER}/g"       "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_DAY_PLACEHOLDER/${NAME_DAY}/g"           "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_EVENING_PLACEHOLDER/${NAME_EVENING}/g"   "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
    sed -i "s/NAME_NIGHT_PLACEHOLDER/${NAME_NIGHT}/g"       "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"

    SENSOR_FILE="$SENSORS_DIR/${ROOM_LOWER}_sensors.yaml"
    if [ ! -f "$SENSOR_FILE" ]; then
      cat > "$SENSOR_FILE" <<EOF
- binary_sensor.${ROOM_LOWER}_presence_a
EOF
    fi
  done
}

ch_heatshield() {
  cp "$SCRIPT_DIR/template_package_heatshield.yaml"                       "$PACKAGES_DIR/tech_heatshield.yaml"
  sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"                  "$PACKAGES_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_MODE_PLACEHOLDER/$NAME_HEATSHIELD_MODE/g"     "$PACKAGES_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_EAST_PLACEHOLDER/$NAME_HEATSHIELD_EAST/g"     "$PACKAGES_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_SOUTH_PLACEHOLDER/$NAME_HEATSHIELD_SOUTH/g"   "$PACKAGES_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_WEST_PLACEHOLDER/$NAME_HEATSHIELD_WEST/g"     "$PACKAGES_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_OFF_PLACEHOLDER/$NAME_HEATSHIELD_OFF/g"       "$PACKAGES_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_AUTO_PLACEHOLDER/$NAME_HEATSHIELD_AUTO/g"     "$PACKAGES_DIR/tech_heatshield.yaml"

  cp "$SCRIPT_DIR/template_automation_heatshield.yaml"                    "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s|#DEPLOY_PLACEHOLDER|#Deployed $DEPLOY_DATE|"                  "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_EAST_PLACEHOLDER/$NAME_HEATSHIELD_EAST/g"     "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_SOUTH_PLACEHOLDER/$NAME_HEATSHIELD_SOUTH/g"   "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_WEST_PLACEHOLDER/$NAME_HEATSHIELD_WEST/g"     "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_OFF_PLACEHOLDER/$NAME_HEATSHIELD_OFF/g"       "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s/NAME_HEATSHIELD_AUTO_PLACEHOLDER/$NAME_HEATSHIELD_AUTO/g"     "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s/HEATSHIELD_EAST_TIME_PLACEHOLDER/$HEATSHIELD_EAST_TIME/g"     "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s/HEATSHIELD_SOUTH_TIME_PLACEHOLDER/$HEATSHIELD_SOUTH_TIME/g"   "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s/HEATSHIELD_WEST_TIME_PLACEHOLDER/$HEATSHIELD_WEST_TIME/g"     "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s/HEATSHIELD_TEMP_DIFF_PLACEHOLDER/$HEATSHIELD_TEMP_DIFF/g"     "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s|OUTSIDE_TEMP_SENSOR_PLACEHOLDER|$OUTSIDE_TEMP_SENSOR|g"       "$AUTOMATIONS_DIR/tech_heatshield.yaml"
  sed -i "s|INSIDE_TEMP_SENSOR_PLACEHOLDER|$INSIDE_TEMP_SENSOR|g"         "$AUTOMATIONS_DIR/tech_heatshield.yaml"
}

case "$MODE" in
  all)
    ch_init
    ch_day_mode
    ch_heatshield
    ch_motion
    ch_reminder_alarm
    ;;
  init)
    ch_init
    ;;
  day_mode)
    ch_day_mode
    ;;
  heatshield)
    ch_heatshield
    ;;
  motion)
    ch_motion
    ;;
  reminder)
    ch_reminder_alarm
    ;;
esac

ha core restart
