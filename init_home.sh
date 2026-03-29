#!/bin/bash

PACKAGES_DIR="/homeassistant/packages"
AUTOMATIONS_DIR="/homeassistant/automations"

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

  sunrise_offset_hk:
    name: Sunrise Offset
    options:
      - "30min before"
      - "Sunrise"
      - "30min after"
      - "1h after"
      - "1.5h after"
      - "2h after"
    initial: "Sunrise"
EOF

cat > "$AUTOMATIONS_DIR/tech_day_mode.yaml" << 'EOF'
- id: set_day_mode
  alias: Set Day Mode

  trigger:
    - id: day
      platform: sun
      event: sunrise
      offset: "+01:00:00"

    - id: evening
      platform: sun
      event: sunset

    - id: night
      platform: time
      at: "22:22:00"

    - id: startup
      platform: homeassistant
      event: start

  action:
    - choose:
        - conditions:
            - condition: trigger
              id: day
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Day"

        - conditions:
            - condition: trigger
              id: evening
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Evening"

        - conditions:
            - condition: trigger
              id: night
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"

        # Startup: Day
        - conditions:
            - condition: trigger
              id: startup
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

        # Startup: Night (after 0:00)
        - conditions:
            - condition: trigger
              id: startup
            - condition: template
              value_template: >
                {{ now() >= today_at("22:22:00") }}
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"

        # Startup: Night (before 24:00)
        - conditions:
            - condition: trigger
              id: startup
            - condition: sun
              before: sunrise
              before_offset: "+01:00:00"
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"

        # Startup fallback: Evening
        - conditions:
            - condition: trigger
              id: startup
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

# ─── Update configuration.yaml ────────────────────────────────────────────────
CONFIG="/homeassistant/configuration.yaml"

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
    echo "Appended homeassistant packages and homekit config."
  else
    echo "Packages block already present, skipping append."
  fi
else
  echo "Warning: $CONFIG not found, skipping configuration.yaml update."
fi

echo "Restarting HA..."
ha core restart
