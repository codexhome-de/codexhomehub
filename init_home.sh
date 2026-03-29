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
    initial: "1 hour"
EOF

cat > "$AUTOMATIONS_DIR/tech_day_mode.yaml" << 'EOF'
- id: set_day_mode
  alias: Set Day Mode
  trigger:
    - platform: homeassistant
      event: start
    - platform: state
      entity_id: input_select.sunrise_offset_hk
    - platform: time_pattern
      minutes: "/5"   # re-evaluate every 5 min (lightweight + reliable)

  action:
    - choose:
        # Night (after 22:22)
        - conditions:
            - condition: template
              value_template: >
                {{ now() >= today_at("22:22:00") }}
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"

        # Night (before sunrise + offset)
        - conditions:
            - condition: template
              value_template: >
                {% set map = {
                  "30min before": -0.5,
                  "Sunrise": 0,
                  "30min after": 0.5,
                  "1h after": 1,
                  "1.5h after": 1.5,
                  "2h after": 2
                } %}
                {% set offset = timedelta(hours=map[states('input_select.sunrise_offset_hk')]) %}
                {{ now() < (as_datetime(state_attr('sun.sun','next_rising')) + offset) }}
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"

        # Day (sunrise + offset → sunset)
        - conditions:
            - condition: template
              value_template: >
                {% set map = {
                  "30min before": -0.5,
                  "Sunrise": 0,
                  "30min after": 0.5,
                  "1h after": 1,
                  "1.5h after": 1.5,
                  "2h after": 2
                } %}
                {% set offset = timedelta(hours=map[states('input_select.sunrise_offset_hk')]) %}
                {{ now() >= (as_datetime(state_attr('sun.sun','next_rising')) + offset)
                   and now() < as_datetime(state_attr('sun.sun','next_setting')) }}
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Day"

        # Evening (sunset → 22:22)
        - conditions:
            - condition: template
              value_template: >
                {{ now() >= as_datetime(state_attr('sun.sun','next_setting'))
                   and now() < today_at("22:22:00") }}
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

echo "Done."