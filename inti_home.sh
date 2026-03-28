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
- id: set_day_mode_on_startup
  alias: Set Day Mode - On Startup
  trigger:
    - platform: homeassistant
      event: start

  action:
    - choose:
        # 🌙 Night (22:22 → midnight)
        - conditions:
            - condition: time
              after: "22:22:00"
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"

        # 🌙 Night (midnight → sunrise+1h)
        - conditions:
            - condition: sun
              before: sunrise
              before_offset: "+01:00:00"
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"

        # 🌅 Day (sunrise+1h → sunset)
        - conditions:
            - condition: sun
              after: sunrise
              after_offset: "+01:00:00"
              before: sunset
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Day"

        # 🌆 Evening (sunset → 22:22)
        - conditions:
            - condition: sun
              after: sunset
            - condition: time
              before: "22:22:00"
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Evening"
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