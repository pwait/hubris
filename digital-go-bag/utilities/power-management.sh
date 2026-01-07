#!/bin/bash
#
# POWER MANAGEMENT UTILITIES
# Monitor and extend battery life for off-grid computing
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

show_battery_status() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║                    BATTERY STATUS                              ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Check for battery
    local bat_path=""
    for path in /sys/class/power_supply/BAT*; do
        if [[ -d "$path" ]]; then
            bat_path="$path"
            break
        fi
    done

    if [[ -z "$bat_path" ]]; then
        print_color "$YELLOW" "No battery detected (desktop system?)"
        return
    fi

    local capacity status voltage power_now energy_now energy_full

    capacity=$(cat "$bat_path/capacity" 2>/dev/null || echo "?")
    status=$(cat "$bat_path/status" 2>/dev/null || echo "Unknown")
    energy_now=$(cat "$bat_path/energy_now" 2>/dev/null || cat "$bat_path/charge_now" 2>/dev/null || echo "0")
    energy_full=$(cat "$bat_path/energy_full" 2>/dev/null || cat "$bat_path/charge_full" 2>/dev/null || echo "0")
    power_now=$(cat "$bat_path/power_now" 2>/dev/null || echo "0")
    voltage=$(cat "$bat_path/voltage_now" 2>/dev/null || echo "0")

    # Color based on capacity
    local cap_color="$GREEN"
    if [[ "$capacity" != "?" ]]; then
        if [[ "$capacity" -lt 20 ]]; then
            cap_color="$RED"
        elif [[ "$capacity" -lt 50 ]]; then
            cap_color="$YELLOW"
        fi
    fi

    print_color "$WHITE" "Battery:"
    echo -e "  Capacity: ${cap_color}${capacity}%${NC}"
    echo "  Status: $status"

    if [[ "$voltage" != "0" ]]; then
        echo "  Voltage: $(echo "scale=2; $voltage/1000000" | bc) V"
    fi

    if [[ "$power_now" != "0" ]]; then
        local watts
        watts=$(echo "scale=2; $power_now/1000000" | bc)
        echo "  Power: ${watts} W"

        # Estimate remaining time
        if [[ "$status" == "Discharging" && "$energy_now" != "0" ]]; then
            local hours
            hours=$(echo "scale=1; $energy_now/$power_now" | bc 2>/dev/null || echo "?")
            print_color "$WHITE" "  Time remaining: ~${hours} hours"
        fi
    fi

    echo ""

    # AC adapter status
    for ac in /sys/class/power_supply/AC* /sys/class/power_supply/ADP*; do
        if [[ -f "$ac/online" ]]; then
            local online
            online=$(cat "$ac/online")
            if [[ "$online" == "1" ]]; then
                print_color "$GREEN" "AC Power: Connected"
            else
                print_color "$YELLOW" "AC Power: Disconnected"
            fi
            break
        fi
    done
}

enable_powersave() {
    print_color "$BLUE" "Enabling power-saving mode..."

    # CPU governor
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo "powersave" | sudo tee "$cpu" 2>/dev/null || true
        done
        print_color "$GREEN" "  CPU: powersave governor"
    fi

    # Reduce screen brightness
    for bl in /sys/class/backlight/*/brightness; do
        if [[ -f "$bl" ]]; then
            local max
            max=$(cat "${bl%brightness}max_brightness")
            local target=$((max / 3))
            echo "$target" | sudo tee "$bl" 2>/dev/null || true
            print_color "$GREEN" "  Display: brightness reduced"
            break
        fi
    done

    # Disable Bluetooth
    if command -v rfkill &>/dev/null; then
        sudo rfkill block bluetooth 2>/dev/null || true
        print_color "$GREEN" "  Bluetooth: disabled"
    fi

    # Disable WiFi power management
    if command -v iw &>/dev/null; then
        for dev in /sys/class/net/wlan*; do
            local iface
            iface=$(basename "$dev")
            sudo iw dev "$iface" set power_save on 2>/dev/null || true
        done
        print_color "$GREEN" "  WiFi: power save on"
    fi

    # USB autosuspend
    for usb in /sys/bus/usb/devices/*/power/autosuspend; do
        echo "1" | sudo tee "$usb" 2>/dev/null || true
    done
    print_color "$GREEN" "  USB: autosuspend enabled"

    # Disable NMI watchdog
    echo 0 | sudo tee /proc/sys/kernel/nmi_watchdog 2>/dev/null || true

    # Enable laptop mode
    echo 5 | sudo tee /proc/sys/vm/laptop_mode 2>/dev/null || true

    print_color "$GREEN" "Power-saving mode enabled!"
}

enable_performance() {
    print_color "$BLUE" "Enabling performance mode..."

    # CPU governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" | sudo tee "$cpu" 2>/dev/null || true
    done

    # Enable Bluetooth
    if command -v rfkill &>/dev/null; then
        sudo rfkill unblock bluetooth 2>/dev/null || true
    fi

    # Disable laptop mode
    echo 0 | sudo tee /proc/sys/vm/laptop_mode 2>/dev/null || true

    print_color "$GREEN" "Performance mode enabled!"
}

monitor_power() {
    print_color "$BLUE" "Monitoring power usage (Ctrl+C to stop)..."
    echo ""

    while true; do
        clear
        show_battery_status

        # Show top power consumers
        if command -v powertop &>/dev/null; then
            echo ""
            print_color "$WHITE" "Top power consumers:"
            sudo powertop --time=1 --csv=/tmp/powertop.csv 2>/dev/null
            tail -20 /tmp/powertop.csv 2>/dev/null | head -10 || true
        fi

        sleep 5
    done
}

estimate_runtime() {
    print_color "$CYAN" "Runtime Estimation Calculator"
    echo ""

    # Get current battery
    local capacity=100
    local bat_path=""
    for path in /sys/class/power_supply/BAT*; do
        if [[ -d "$path" ]]; then
            bat_path="$path"
            capacity=$(cat "$path/capacity" 2>/dev/null || echo "100")
            break
        fi
    done

    local energy_full=0
    if [[ -n "$bat_path" ]]; then
        energy_full=$(cat "$bat_path/energy_full" 2>/dev/null || echo "0")
        energy_full=$((energy_full / 1000000))  # Convert to Wh
    fi

    if [[ "$energy_full" == "0" ]]; then
        print_color "$WHITE" "Enter battery capacity in Wh (e.g., 50): "
        read -r energy_full
    fi

    print_color "$WHITE" "Current capacity: ${capacity}%"
    print_color "$WHITE" "Battery: ${energy_full} Wh"
    echo ""

    # Common power draw estimates
    cat << EOF
Estimated runtime at current charge (${capacity}%):

Usage Level          | Power Draw | Runtime
---------------------|------------|--------
Idle (screen off)    | ~3W        | ~$((energy_full * capacity / 100 / 3)) hours
Light (text editing) | ~8W        | ~$((energy_full * capacity / 100 / 8)) hours
Normal (browsing)    | ~15W       | ~$((energy_full * capacity / 100 / 15)) hours
Heavy (compiling)    | ~30W       | ~$((energy_full * capacity / 100 / 30)) hours
Maximum              | ~60W       | ~$((energy_full * capacity / 100 / 60)) hours

Tips to extend battery life:
- Reduce screen brightness (biggest impact)
- Disable WiFi/Bluetooth when not needed
- Use powersave governor: $0 powersave
- Close unnecessary applications
- Use dark themes (OLED screens)
EOF
}

show_help() {
    echo "Power Management Utilities"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status      - Show battery and power status"
    echo "  powersave   - Enable power-saving mode"
    echo "  performance - Enable performance mode"
    echo "  monitor     - Continuously monitor power"
    echo "  estimate    - Estimate runtime"
    echo "  help        - Show this help"
}

case "${1:-status}" in
    status)
        show_battery_status
        ;;
    powersave|save)
        enable_powersave
        ;;
    performance|perf)
        enable_performance
        ;;
    monitor|watch)
        monitor_power
        ;;
    estimate|calc)
        estimate_runtime
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
