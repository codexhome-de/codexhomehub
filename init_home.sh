#!/bin/bash

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

  sunrise_offset_hk:
    name: Sunrise Offset
    options:
      - "-30 min"
      - "0"
      - "30 min"
      - "1 hour"
      - "1.5 hours"
      - "2 hours"
    initial: "1 hour"
EOF

cat > "$AUTOMATIONS_DIR/tech_day_mode.yaml" << 'EOF'
- id: set_day_mode_on_startup
  alias: Set Day Mode On Startup
  trigger:
    - platform: homeassistant
      event: start

  variables:
    offset_hours: >
      {% set map = {
        "-30 min": -0.5,
        "0": 0,
        "30 min": 0.5,
        "1 hour": 1,
        "1.5 hours": 1.5,
        "2 hours": 2
      } %}
      {{ map[states('input_select.sunrise_offset_hk')] }}

    offset_td: >
      {{ timedelta(hours=offset_hours) }}

    next_rising: >
      {{ as_datetime(state_attr('sun.sun','next_rising')) }}

    next_setting: >
      {{ as_datetime(state_attr('sun.sun','next_setting')) }}

    sunrise_with_offset: >
      {{ next_rising + offset_td }}

  action:
    - choose:
        - conditions:
            - condition: time
              after: "22:22:00"
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"

        - conditions:
            - condition: template
              value_template: >
                {{ now() < sunrise_with_offset }}
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Night"

        - conditions:
            - condition: template
              value_template: >
                {{ now() >= sunrise_with_offset and now() < next_setting }}
          sequence:
            - action: input_select.select_option
              target:
                entity_id: input_select.tech_day_mode_hk
              data:
                option: "Day"

        - conditions:
            - condition: template
              value_template: >
                {{ now() >= next_setting and now() < today_at("22:22:00") }}
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