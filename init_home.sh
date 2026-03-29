#!/bin/bash

PACKAGES_DIR="/homeassistant/packages"
AUTOMATIONS_DIR="/homeassistant/automations"

mkdir -p "$PACKAGES_DIR" "$AUTOMATIONS_DIR"

# --- Day Mode config
SUNRISE_OFFSET="+01:00:00"
NIGHT_TIME="23:00:00"

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
- id: set_day_mode
  alias: Set Day Mode
  trigger:
    - id: day
      platform: sun
      event: sunrise
      offset: "SUNRISE_OFFSET_PLACEHOLDER"
    - id: evening
      platform: sun
      event: sunset
    - id: night
      platform: time
      at: "NIGHT_TIME_PLACEHOLDER"
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
              after_offset: "SUNRISE_OFFSET_PLACEHOLDER"
              before: sunset
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Day"
        # Startup: Night (late)
        - conditions:
            - condition: trigger
              id: startup
            - condition: template
              value_template: >
                {{ now() >= today_at("NIGHT_TIME_PLACEHOLDER") }}
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"
        # Startup: Night (early)
        - conditions:
            - condition: trigger
              id: startup
            - condition: sun
              before: sunrise
              before_offset: "SUNRISE_OFFSET_PLACEHOLDER"
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

sed -i "s/SUNRISE_OFFSET_PLACEHOLDER/$SUNRISE_OFFSET/g" "$AUTOMATIONS_DIR/tech_day_mode.yaml"
sed -i "s/NIGHT_TIME_PLACEHOLDER/$NIGHT_TIME/g" "$AUTOMATIONS_DIR/tech_day_mode.yaml"

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

# --- Update configuration.yaml
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
  fi
fi

# --- Add alias to .bash_profile
PROFILE="/data/.bash_profile"
  if ! grep -q "alias cu" "$PROFILE"; then
    cat >> "$PROFILE" << 'EOF'
alias cu='cd /homeassistant/codexhomehub && git pull'
EOF
  fi

echo "Restarting HA..."
ha core restart