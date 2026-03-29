#!/bin/bash

#VERSION="4"

ROOMS_FILE="$(dirname "$0")/rooms.cfg"

if [ ! -f "$ROOMS_FILE" ]; then
  echo "Error: rooms.cfg not found at $ROOMS_FILE"
  exit 1
fi

readarray -t ROOMS < "$ROOMS_FILE"

to_slug() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '_'
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HA_DIR="$(dirname "$SCRIPT_DIR")"

PACKAGES_DIR="$HA_DIR/packages"
AUTOMATIONS_DIR="$HA_DIR/automations"
SENSORS_DIR="$SCRIPT_DIR/sensors"

DEPLOY_DATE=$(date +%Y%m%d)

mkdir -p "$PACKAGES_DIR" "$AUTOMATIONS_DIR" "$SENSORS_DIR"

for room in "${ROOMS[@]}"; do
  ROOM_UPPER="$room"
  ROOM_LOWER=$(to_slug "$room")

  # Package
  cp "$SCRIPT_DIR/template_package_motion.yaml" "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
  sed -i 's/#VERSION="\([^"]*\)"/#VERSION="\1" - deployed '"${DEPLOY_DATE}"'/g' "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
  sed -i "s/Room/${ROOM_UPPER}/g" "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"
  sed -i "s/room/${ROOM_LOWER}/g" "$PACKAGES_DIR/package_motion_${ROOM_LOWER}.yaml"

  # Automation
  cp "$SCRIPT_DIR/template_automation_motion.yaml" "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
  sed -i 's/#VERSION="\([^"]*\)"/#VERSION="\1" - deployed '"${DEPLOY_DATE}"'/g' "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
  sed -i "s/Room/${ROOM_UPPER}/g" "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"
  sed -i "s/room/${ROOM_LOWER}/g" "$AUTOMATIONS_DIR/automation_motion_${ROOM_LOWER}.yaml"

  # Sensors
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

echo "Done."