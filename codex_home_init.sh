#!/bin/bash

#VERSION="3"

BASE_DIR="${1:-$(dirname "$0")/..}"

PACKAGES_DIR="$BASE_DIR/packages"
AUTOMATIONS_DIR="$BASE_DIR/automations"

mkdir -p "$PACKAGES_DIR" "$AUTOMATIONS_DIR"

cat > "$PACKAGES_DIR/tech_day_mode.yaml" << 'EOF'
input_select:
  tech_day_mode_hk:
    name: Day Mode
    icon: mdi:theme-light-dark
    options:
      - Day
      - Evening
      - Night
    initial: Evening
EOF

cat > "$AUTOMATIONS_DIR/tech_day_mode.yaml" << 'EOF'
- id: set_day_mode_sunrise
  alias: Set Day Mode - Sunrise
  trigger:
    - platform: sun
      event: sunrise
      offset: "+01:00:00"
  action:
    - service: input_select.select_option
      target:
        entity_id: input_select.tech_day_mode_hk
      data:
        option: "Day"

- id: set_day_mode_sunset
  alias: Set Day Mode - Sunset
  trigger:
    - platform: sun
      event: sunset
  action:
    - service: input_select.select_option
      target:
        entity_id: input_select.tech_day_mode_hk
      data:
        option: "Evening"

- id: set_day_mode_night
  alias: Set Day Mode - 22:22
  trigger:
    - platform: time
      at: "22:22:00"
  action:
    - service: input_select.select_option
      target:
        entity_id: input_select.tech_day_mode_hk
      data:
        option: "Night"
EOF

cat > "$PACKAGES_DIR/tech_reminder.yaml" << 'EOF'
input_boolean:
  reminder_trigger_hk:
    name: Reminder Alarm

  reminder_hk:
    name: Reminder


template:
  - binary_sensor:
      - name: "Reminder"
        unique_id: reminder
        default_entity_id: binary_sensor.reminder_hk
        device_class: smoke
        state: "{{ is_state('input_boolean.reminder_trigger_hk', 'on') }}"
EOF

echo "Created: $PACKAGES_DIR/tech_day_mode.yaml"
echo "Created: $AUTOMATIONS_DIR/tech_day_mode.yaml"
echo "Created: $PACKAGES_DIR/tech_reminder.yaml"
echo "Done."