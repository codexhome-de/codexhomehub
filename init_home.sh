#!/bin/bash

# --- Language parameter (mandatory)
LANG="${1:-}"
if [ "$LANG" != "DE" ] && [ "$LANG" != "EN" ]; then
  echo "Usage: $0 [DE|EN]"
  exit 1
fi

PACKAGES_DIR="/homeassistant/packages"
AUTOMATIONS_DIR="/homeassistant/automations"

mkdir -p "$PACKAGES_DIR" "$AUTOMATIONS_DIR"

# --- Localized entity names
if [ "$LANG" = "DE" ]; then
  NAME_DAY_MODE="Tagesmodus"
  NAME_DAY="Tag"
  NAME_EVENING="Abend"
  NAME_NIGHT="Nacht"
  NAME_REMINDER_ALARM="Erinnerung Alarm"
  NAME_REMINDER="Erinnerung"
  NAME_REMINDER_SENSOR="Erinnerung"
else
  NAME_DAY_MODE="Day Mode"
  NAME_DAY="Day"
  NAME_EVENING="Evening"
  NAME_NIGHT="Night"
  NAME_REMINDER_ALARM="Reminder Alarm"
  NAME_REMINDER="Reminder"
  NAME_REMINDER_SENSOR="Reminder"
fi

# --- Day Mode config
SUNRISE_OFFSET="+01:00:00"
NIGHT_TIME="23:00:00"

cat > "$PACKAGES_DIR/tech_day_mode.yaml" << EOF
input_select:
  tech_day_mode_hk:
    name: $NAME_DAY_MODE
    icon: mdi:theme-light-dark
    options:
      - $NAME_DAY
      - $NAME_EVENING
      - $NAME_NIGHT
    initial: $NAME_EVENING
EOF

cat > "$AUTOMATIONS_DIR/tech_day_mode.yaml" << EOF
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
                option: "$NAME_DAY"
        - conditions:
            - condition: trigger
              id: evening
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "$NAME_EVENING"
        - conditions:
            - condition: trigger
              id: night
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "$NAME_NIGHT"
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
                option: "$NAME_DAY"
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
                option: "$NAME_NIGHT"
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
                option: "$NAME_NIGHT"
        # Startup fallback: Evening
        - conditions:
            - condition: trigger
              id: startup
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "$NAME_EVENING"
EOF

sed -i "s/SUNRISE_OFFSET_PLACEHOLDER/$SUNRISE_OFFSET/g" "$AUTOMATIONS_DIR/tech_day_mode.yaml"
sed -i "s/NIGHT_TIME_PLACEHOLDER/$NIGHT_TIME/g" "$AUTOMATIONS_DIR/tech_day_mode.yaml"

cat > "$PACKAGES_DIR/tech_reminder.yaml" << EOF
input_boolean:
  reminder_trigger_hk:
    name: $NAME_REMINDER_ALARM

  reminder_hk:
    name: $NAME_REMINDER


template:
  - binary_sensor:
      - name: "$NAME_REMINDER_SENSOR"
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
touch "$PROFILE"
if ! grep -q "alias cu" "$PROFILE"; then
  cat >> "$PROFILE" << 'EOF'
alias cu='cd /homeassistant/codexhomehub && git pull'
EOF
fi

echo "Restarting HA..."
ha core restart