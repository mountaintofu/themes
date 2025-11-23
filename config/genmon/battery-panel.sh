#!/usr/bin/env zsh
# Dependencies: acpi, zsh>=5.0, coreutils, file, gawk, grep, xfce4-power-manager

# Makes the script more portable (zsh compatible)
readonly DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"

# Optional icons to display before the text
# declare -ra ICON_ARRAY=(
#   "${DIR}/icons/battery/battery-unknown.png"
#   "${DIR}/icons/battery/battery-0.png"
#   "${DIR}/icons/battery/battery-10.png"
#   "${DIR}/icons/battery/battery-20.png"
#   "${DIR}/icons/battery/battery-30.png"
#   "${DIR}/icons/battery/battery-40.png"
#   "${DIR}/icons/battery/battery-50.png"
#   "${DIR}/icons/battery/battery-60.png"
#   "${DIR}/icons/battery/battery-70.png"
#   "${DIR}/icons/battery/battery-80.png"
#   "${DIR}/icons/battery/battery-90.png"
#   "${DIR}/icons/battery/battery-100.png"
#   "${DIR}/icons/battery/battery-charging-20.png"
#   "${DIR}/icons/battery/battery-charging-30.png"
#   "${DIR}/icons/battery/battery-charging-40.png"
#   "${DIR}/icons/battery/battery-charging-60.png"
#   "${DIR}/icons/battery/battery-charging-80.png"
#   "${DIR}/icons/battery/battery-charging-90.png"
#   "${DIR}/icons/battery/battery-charging-100.png"
# )

# Find battery path
BAT_PATH=$(find /sys/class/power_supply/ -name "BAT*" 2>/dev/null | head -n 1)

if [ -z "$BAT_PATH" ]; then
  echo "<txt>No Battery</txt>"
  exit 0
fi

# Function to safely read sysfs files
safe_read() {
  local file=$1
  local default=${2:-"Unknown"}
  if [ -f "$file" ] && [ -r "$file" ]; then
    cat "$file" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# Read basic info
readonly MANUFACTURER=$(safe_read "$BAT_PATH/manufacturer" "Unknown")
readonly MODEL=$(safe_read "$BAT_PATH/model_name" "Unknown")
readonly TECHNOLOGY=$(safe_read "$BAT_PATH/technology" "Unknown")
readonly TYPE=$(safe_read "$BAT_PATH/type" "Unknown")
readonly BATTERY=$(safe_read "$BAT_PATH/capacity" "0")

# Enhanced serial number detection
get_serial_number() {
  # Method 1: Try sysfs
  if [ -f "$BAT_PATH/serial_number" ] && [ -r "$BAT_PATH/serial_number" ]; then
    local serial=$(cat "$BAT_PATH/serial_number" 2>/dev/null)
    if [ -n "$serial" ] && [ "$serial" != " " ] && [ "$serial" != "0" ]; then
      echo "$serial"
      return
    fi
  fi
  
  # Method 2: Try upower
  if command -v upower &> /dev/null; then
    local bat_name=$(basename "$BAT_PATH")
    local serial=$(upower -i /org/freedesktop/UPower/devices/battery_${bat_name} 2>/dev/null | grep "serial:" | awk '{print $2}')
    if [ -n "$serial" ] && [ "$serial" != "0" ]; then
      echo "$serial"
      return
    fi
  fi
  
  # Method 3: Try dmidecode (requires root)
  if command -v dmidecode &> /dev/null && [ -r /dev/mem ] 2>/dev/null; then
    local serial=$(sudo dmidecode -t battery 2>/dev/null | grep "Serial Number" | head -n1 | awk -F': ' '{print $2}')
    if [ -n "$serial" ] && [ "$serial" != "Not Specified" ]; then
      echo "$serial"
      return
    fi
  fi
  
  # Method 4: Try acpi
  if command -v acpi &> /dev/null; then
    local serial=$(acpi -i 2>/dev/null | grep "serial number" | awk -F': ' '{print $2}' | tr -d ' ')
    if [ -n "$serial" ]; then
      echo "$serial"
      return
    fi
  fi
  
  echo "N/A"
}

readonly SERIAL_NUMBER=$(get_serial_number)

# Function to convert microunits to regular units
convert_micro() {
  local value=$1
  if [ -n "$value" ] && [ "$value" != "0" ]; then
    awk -v val="$value" 'BEGIN {printf "%.2f", val / 1000000}'
  else
    echo "0"
  fi
}

# Read energy/charge values (some batteries use energy_*, others use charge_*)
if [ -f "$BAT_PATH/energy_now" ]; then
  # Battery reports in energy (Wh)
  ENERGY=$(convert_micro "$(safe_read "$BAT_PATH/energy_now" "0")")
  ENERGY_FULL=$(convert_micro "$(safe_read "$BAT_PATH/energy_full" "0")")
  ENERGY_DESIGN=$(convert_micro "$(safe_read "$BAT_PATH/energy_full_design" "0")")
elif [ -f "$BAT_PATH/charge_now" ]; then
  # Battery reports in charge (Ah) - need to multiply by voltage for Wh
  VOLTAGE_NOW=$(safe_read "$BAT_PATH/voltage_now" "0")
  CHARGE_NOW=$(safe_read "$BAT_PATH/charge_now" "0")
  CHARGE_FULL=$(safe_read "$BAT_PATH/charge_full" "0")
  CHARGE_DESIGN=$(safe_read "$BAT_PATH/charge_full_design" "0")
  
  # Convert to Wh: (charge in µAh * voltage in µV) / 1000000000000 = Wh
  if [ "$VOLTAGE_NOW" != "0" ]; then
    ENERGY=$(awk -v c="$CHARGE_NOW" -v v="$VOLTAGE_NOW" 'BEGIN {printf "%.2f", (c * v) / 1000000000000}')
    ENERGY_FULL=$(awk -v c="$CHARGE_FULL" -v v="$VOLTAGE_NOW" 'BEGIN {printf "%.2f", (c * v) / 1000000000000}')
    ENERGY_DESIGN=$(awk -v c="$CHARGE_DESIGN" -v v="$VOLTAGE_NOW" 'BEGIN {printf "%.2f", (c * v) / 1000000000000}')
  else
    ENERGY="0"
    ENERGY_FULL="0"
    ENERGY_DESIGN="0"
  fi
else
  ENERGY="N/A"
  ENERGY_FULL="N/A"
  ENERGY_DESIGN="N/A"
fi

# Read voltage
readonly VOLTAGE=$(convert_micro "$(safe_read "$BAT_PATH/voltage_now" "0")")

# Read power/current rate
if [ -f "$BAT_PATH/power_now" ]; then
  RATE=$(convert_micro "$(safe_read "$BAT_PATH/power_now" "0")")
elif [ -f "$BAT_PATH/current_now" ]; then
  # Convert current to power: (current in µA * voltage in µV) / 1000000000000 = W
  CURRENT_NOW=$(safe_read "$BAT_PATH/current_now" "0")
  VOLTAGE_NOW=$(safe_read "$BAT_PATH/voltage_now" "0")
  if [ "$VOLTAGE_NOW" != "0" ]; then
    RATE=$(awk -v c="$CURRENT_NOW" -v v="$VOLTAGE_NOW" 'BEGIN {printf "%.2f", (c * v) / 1000000000000}')
  else
    RATE="0"
  fi
else
  RATE="N/A"
fi

# Read temperature (try multiple methods)
if [ -f "$BAT_PATH/temp" ]; then
  # Temperature in decidegrees Celsius
  TEMP_RAW=$(safe_read "$BAT_PATH/temp" "0")
  TEMPERATURE=$(awk -v t="$TEMP_RAW" 'BEGIN {printf "%.1f", t / 10}')
elif command -v acpi &> /dev/null; then
  TEMPERATURE=$(acpi -t 2>/dev/null | awk 'NR==1 {print $4}' | sed 's/,//')
  [ -z "$TEMPERATURE" ] && TEMPERATURE="N/A"
else
  TEMPERATURE="N/A"
fi

# Read time remaining
readonly TIME_UNTIL=$(acpi 2>/dev/null | awk -F', ' '{print $3}' | awk '{print $1}')

# Panel
INFO=""
if command -v xfce4-power-manager-settings &> /dev/null; then
  INFO+="<txtclick>xfce4-power-manager-settings</txtclick>"
fi

if acpi -a 2>/dev/null | grep -qi "off-line"; then
  if [ "${BATTERY}" -lt 10 ]; then
    [[ $(file -b "${ICON_ARRAY[1]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[1]}</img>"
  elif [ "${BATTERY}" -ge 10 ] && [ "${BATTERY}" -lt 20 ]; then
    [[ $(file -b "${ICON_ARRAY[2]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[2]}</img>"
  elif [ "${BATTERY}" -ge 20 ] && [ "${BATTERY}" -lt 30 ]; then
    [[ $(file -b "${ICON_ARRAY[3]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[3]}</img>"
  elif [ "${BATTERY}" -ge 30 ] && [ "${BATTERY}" -lt 40 ]; then
    [[ $(file -b "${ICON_ARRAY[4]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[4]}</img>"
  elif [ "${BATTERY}" -ge 40 ] && [ "${BATTERY}" -lt 50 ]; then
    [[ $(file -b "${ICON_ARRAY[5]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[5]}</img>"
  elif [ "${BATTERY}" -ge 50 ] && [ "${BATTERY}" -lt 60 ]; then
    [[ $(file -b "${ICON_ARRAY[6]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[6]}</img>"
  elif [ "${BATTERY}" -ge 60 ] && [ "${BATTERY}" -lt 70 ]; then
    [[ $(file -b "${ICON_ARRAY[7]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[7]}</img>"
  elif [ "${BATTERY}" -ge 70 ] && [ "${BATTERY}" -lt 80 ]; then
    [[ $(file -b "${ICON_ARRAY[8]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[8]}</img>"
  elif [ "${BATTERY}" -ge 80 ] && [ "${BATTERY}" -lt 90 ]; then
    [[ $(file -b "${ICON_ARRAY[9]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[9]}</img>"
  elif [ "${BATTERY}" -ge 90 ] && [ "${BATTERY}" -lt 100 ]; then
    [[ $(file -b "${ICON_ARRAY[10]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[10]}</img>"
  elif [ "${BATTERY}" -eq 100 ]; then
    [[ $(file -b "${ICON_ARRAY[11]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[11]}</img>"
  fi
elif acpi -a 2>/dev/null | grep -qi "on-line"; then
  if [ "${BATTERY}" -lt 15 ]; then
    [[ $(file -b "${ICON_ARRAY[12]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[12]}</img>"
  elif [ "${BATTERY}" -ge 15 ] && [ "${BATTERY}" -lt 30 ]; then
    [[ $(file -b "${ICON_ARRAY[13]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[13]}</img>"
  elif [ "${BATTERY}" -ge 30 ] && [ "${BATTERY}" -lt 55 ]; then
    [[ $(file -b "${ICON_ARRAY[14]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[14]}</img>"
  elif [ "${BATTERY}" -ge 55 ] && [ "${BATTERY}" -lt 70 ]; then
    [[ $(file -b "${ICON_ARRAY[15]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[15]}</img>"
  elif [ "${BATTERY}" -ge 70 ] && [ "${BATTERY}" -lt 85 ]; then
    [[ $(file -b "${ICON_ARRAY[16]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[16]}</img>"
  elif [ "${BATTERY}" -ge 85 ] && [ "${BATTERY}" -lt 100 ]; then
    [[ $(file -b "${ICON_ARRAY[17]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[17]}</img>"
  elif [ "${BATTERY}" -eq 100 ]; then
    [[ $(file -b "${ICON_ARRAY[18]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[18]}</img>"
  fi
else
  [[ $(file -b "${ICON_ARRAY[0]}" 2>/dev/null) =~ "PNG|SVG" ]] && INFO+="<img>${ICON_ARRAY[0]}</img>"
fi

if command -v xfce4-power-manager-settings &> /dev/null; then
  INFO+="<click>xfce4-power-manager-settings</click>"
fi

INFO+="<txt>"
if acpi -a 2>/dev/null | grep -qi "off-line"; then
  if [ "${BATTERY}" -lt 10 ]; then
    INFO+="<span weight='Bold' fgcolor='White' bgcolor='Red'>"
  else
    INFO+="<span weight='Regular' fgcolor='White'>"
  fi
elif acpi -a 2>/dev/null | grep -qi "on-line"; then
  INFO+="<span weight='Bold' fgcolor='Light Green'>"
else
  INFO+="<span weight='Bold' fgcolor='Yellow'>"
fi
INFO+="${BATTERY}%"
INFO+="</span>"
INFO+="</txt>"

# Tooltip
MORE_INFO="<tool>"
MORE_INFO+="┌ ${MANUFACTURER} ${MODEL}\n"
[ "$SERIAL_NUMBER" != "N/A" ] && MORE_INFO+="├─ Serial number: ${SERIAL_NUMBER}\n"
MORE_INFO+="├─ Technology: ${TECHNOLOGY}\n"
[ "$TEMPERATURE" != "N/A" ] && MORE_INFO+="├─ Temperature: +${TEMPERATURE}℃\n"
MORE_INFO+="├─ Energy: ${ENERGY} Wh\n"
MORE_INFO+="├─ Energy when full: ${ENERGY_FULL} Wh\n"
MORE_INFO+="├─ Energy (design): ${ENERGY_DESIGN} Wh\n"
MORE_INFO+="├─ Rate: ${RATE} W\n"
if acpi -a 2>/dev/null | grep -qi "off-line"; then
  if [ "${BATTERY}" -eq 100 ]; then
    MORE_INFO+="└─ Voltage: ${VOLTAGE} V"
  else
    MORE_INFO+="└─ Remaining Time: ${TIME_UNTIL}"
  fi
elif acpi -a 2>/dev/null | grep -qi "on-line"; then
  if [ "${BATTERY}" -eq 100 ]; then
    MORE_INFO+="└─ Voltage: ${VOLTAGE} V"
  else
    MORE_INFO+="└─ Time to fully charge: ${TIME_UNTIL}"
  fi
else
  MORE_INFO+="└─ Voltage: ${VOLTAGE} V"
fi
MORE_INFO+="</tool>"

# Panel Print
echo -e "${INFO}"

# Tooltip Print
echo -e "${MORE_INFO}"
