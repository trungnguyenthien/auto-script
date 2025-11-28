#!/bin/bash

# Script to Start and Wipe iOS Simulators
# Focuses on operational tasks for existing devices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Arrays to store device info
DEVICE_NAMES=()
DEVICE_UUIDS=()
DEVICE_STATUS=()

# --- Helper Functions ---

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check Xcode
check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode not installed."
        exit 1
    fi
}

# Get list of available simulators (iPhone/iPad only)
scan_simulators() {
    # Reset arrays
    DEVICE_NAMES=()
    DEVICE_UUIDS=()
    DEVICE_STATUS=()
    
    local temp_file=$(mktemp)
    
    # Get available devices, filter for iPhone/iPad
    xcrun simctl list devices available | grep -E "iPhone|iPad" > "$temp_file"
    
    if [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        return 1
    fi

    # Parse file
    while IFS= read -r line; do
        # Ignore header lines
        if [[ "$line" =~ ^--.*--$ ]]; then continue; fi

        # Extract Name (remove leading spaces, remove UUID part)
        local name=$(echo "$line" | sed -E 's/^[[:space:]]*//' | sed -E 's/ \([0-9A-F-]+\).*$//')
        
        # Extract UUID
        local uuid=$(echo "$line" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
        
        # Extract Status (Booted or Shutdown)
        local status="Shutdown"
        if [[ "$line" == *"(Booted)"* ]]; then
            status="Booted"
        fi

        if [[ "$uuid" =~ ^[0-9A-F]{8}- ]]; then
            DEVICE_NAMES+=("$name")
            DEVICE_UUIDS+=("$uuid")
            DEVICE_STATUS+=("$status")
        fi
    done < "$temp_file"
    rm -f "$temp_file"
    return 0
}

# Function to let user select a simulator
# Returns: sets global variable SELECTED_INDEX
select_simulator() {
    scan_simulators
    if [ $? -ne 0 ]; then
        print_error "No simulators found!"
        return 1
    fi

    echo "Available Simulators:"
    local i=0
    for name in "${DEVICE_NAMES[@]}"; do
        local status_icon="🔴"
        local status_text="Shutdown"
        
        if [ "${DEVICE_STATUS[$i]}" == "Booted" ]; then
            status_icon="🟢"
            status_text="Booted"
        fi
        
        # Format: 1) [🔴] iPhone 14 Pro
        echo -e "  $((i+1))) [${status_icon}] ${name}"
        i=$((i+1))
    done

    echo ""
    read -p "Select device number (or 'q' to cancel): " selection

    if [[ "$selection" == "q" ]]; then
        return 1
    fi

    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#DEVICE_NAMES[@]}" ]; then
        SELECTED_INDEX=$((selection - 1))
        return 0
    else
        print_error "Invalid selection."
        return 1
    fi
}

# --- Action Functions ---

# 1. Start Simulator
action_start_simulator() {
    print_header "START SIMULATOR"
    
    if select_simulator; then
        local uuid="${DEVICE_UUIDS[$SELECTED_INDEX]}"
        local name="${DEVICE_NAMES[$SELECTED_INDEX]}"
        local status="${DEVICE_STATUS[$SELECTED_INDEX]}"

        echo ""
        if [ "$status" == "Booted" ]; then
            print_warning "$name is already booted."
            print_info "Opening Simulator window..."
            open -a Simulator
        else
            print_info "Booting: $name..."
            # Boot device
            xcrun simctl boot "$uuid"
            
            # Open Simulator.app to make it visible
            print_info "Opening interface..."
            open -a Simulator
            print_info "✓ Done"
        fi
    fi
    echo ""
    read -p "Press Enter to continue..."
}

# 2. Wipe Simulator
action_wipe_simulator() {
    print_header "WIPE SIMULATOR DATA"
    print_warning "⚠️  This will factory reset the device and delete all installed apps/data."
    
    if select_simulator; then
        local uuid="${DEVICE_UUIDS[$SELECTED_INDEX]}"
        local name="${DEVICE_NAMES[$SELECTED_INDEX]}"
        local status="${DEVICE_STATUS[$SELECTED_INDEX]}"

        echo ""
        echo -e "Target: ${CYAN}$name${NC}"
        read -p "Are you sure you want to WIPE this device? (type 'yes'): " confirm

        if [ "$confirm" == "yes" ]; then
            # Must shutdown before erase
            if [ "$status" == "Booted" ]; then
                print_info "Device is running. Shutting down first..."
                xcrun simctl shutdown "$uuid"
                sleep 2
            fi

            print_info "Erasing data..."
            if xcrun simctl erase "$uuid"; then
                print_info "✓ Device wiped successfully."
            else
                print_error "Failed to wipe device."
            fi
        else
            print_info "Cancelled."
        fi
    fi
    echo ""
    read -p "Press Enter to continue..."
}

# 3. Shutdown All
action_shutdown_all() {
    print_header "SHUTDOWN ALL SIMULATORS"
    print_info "Stopping all running devices..."
    xcrun simctl shutdown all
    print_info "✓ All devices shutdown."
    sleep 1
}

# --- Main Menu ---

show_menu() {
    while true; do
        clear
        print_header "SIMULATOR MANAGER"
        echo "1) Start a Simulator (Boot & Open)"
        echo "2) Wipe Data (Factory Reset)"
        echo "3) Shutdown ALL Simulators"
        echo "4) Exit"
        echo ""
        read -p "Enter choice: " choice

        case $choice in
            1) action_start_simulator ;;
            2) action_wipe_simulator ;;
            3) action_shutdown_all ;;
            4) exit 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Run
check_xcode
show_menu