#!/bin/bash

# Script to automatically create iOS Simulator devices for macOS ARM
# Allows selection of iOS versions from installed runtimes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD_RED='\033[1;31m'
NC='\033[0m' # No Color

# Global arrays for simulator manager operations
DEVICE_NAMES=()
DEVICE_UUIDS=()
DEVICE_STATUS=()

# Fallback timeout function for macOS/systems without GNU timeout
timeout() {
    if type -P timeout &> /dev/null; then
        command timeout "$@"
    elif type -P gtimeout &> /dev/null; then
        gtimeout "$@"
    else
        local duration=$1
        shift
        "$@"
    fi
}

# Device list - will be overridden by user selection
DEVICES=()

# Variables to store selected iOS versions and devices
SELECTED_IOS_VERSIONS=()
SELECTED_RUNTIME_IDS=()
SELECTED_DEVICES=()
SELECTED_DEVICE_IDENTIFIERS=()

# Color print functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_critical() {
    echo -e "${BOLD_RED}[CRITICAL]${NC} $1"
}

print_section() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check macOS ARM
check_arm() {
    if [[ $(uname -m) != "arm64" ]]; then
        print_critical "THIS SCRIPT IS ONLY FOR macOS ARM (Apple Silicon)"
        exit 1
    fi
    print_info "macOS ARM verified ✓"
}

# Check if Xcode is installed
check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        print_critical "XCODE IS NOT INSTALLED. Please install Xcode from App Store"
        exit 1
    fi
    
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    print_info "Found: $XCODE_VERSION ✓"
}

# Get all available iOS runtimes
get_available_runtimes() {
    local temp_file=$(mktemp)
    if timeout 10s xcrun simctl list runtimes > "$temp_file" 2>&1; then
        # Get all iOS runtime lines (exclude watchOS, tvOS)
        grep "iOS" "$temp_file" | grep -v "watchOS" | grep -v "tvOS"
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Parse runtime line to get version and ID
parse_runtime_line() {
    local line=$1
    # Format: iOS 17.5 (17.5 - 21F79) - com.apple.CoreSimulator.SimRuntime.iOS-17-5
    
    # Get version number (e.g., 17.5)
    local version=$(echo "$line" | sed -E 's/^iOS ([0-9]+\.[0-9]+).*/\1/')
    
    # Get runtime ID
    local runtime_id=$(echo "$line" | sed -E 's/.*- (com\.apple\.CoreSimulator\.SimRuntime\.[^ ]+).*/\1/')
    
    echo "$version|$runtime_id"
}

# Get all available device types (iPhone and iPad)
get_available_device_types() {
    local temp_file=$(mktemp)
    if timeout 10s xcrun simctl list devicetypes > "$temp_file" 2>&1; then
        # Get all iPhone and iPad device types
        grep -E "iPhone|iPad" "$temp_file"
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Parse device type line to get display name and full identifier
parse_device_type_line() {
    local line=$1
    # Format: iPhone SE (com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation)
    
    # Get original device name (part before parenthesis)
    local device_name=$(echo "$line" | sed -E 's/^[[:space:]]*//' | sed -E 's/[[:space:]]*\(.*//' | sed -E 's/[[:space:]]*$//')
    
    # Get full identifier (com.apple.CoreSimulator.SimDeviceType.xxx)
    local full_identifier=$(echo "$line" | sed -E 's/.*\((com\.apple\.CoreSimulator\.SimDeviceType\.[^)]+)\).*/\1/')
    
    # Get short identifier to differentiate
    local short_identifier=$(echo "$full_identifier" | sed -E 's/.*SimDeviceType\.//')
    
    # Create display name (name shown to user)
    local display_name="$device_name"
    
    # Handle special cases for iPhone SE
    if [[ "$device_name" == "iPhone SE" ]]; then
        if [[ "$short_identifier" == *"3rd"* ]]; then
            display_name="iPhone SE Gen3"
        elif [[ "$short_identifier" == *"2nd"* ]]; then
            display_name="iPhone SE Gen2"
        elif [[ "$short_identifier" == *"1st"* ]] || [[ "$short_identifier" == "iPhone-SE" ]]; then
            display_name="iPhone SE Gen1"
        fi
    fi
    
    # Return format: display_name|full_identifier
    echo "$display_name|$full_identifier"
}

# Let user select device models
select_device_models() {
    print_section "SELECT DEVICE MODELS"
    
    print_info "Scanning available device types..."
    echo ""
    
    local device_types=$(get_available_device_types)
    
    if [ -z "$device_types" ]; then
        print_error "No device types found"
        exit 1
    fi
    
    # Create arrays to store device names
    local -a device_display_names=()
    local -a device_identifiers=()
    local index=1
    
    echo "Select device models to create simulators (space-separated):"
    echo "Hint: Enter 'all' for all devices, 'iphone' for all iPhones, 'ipad' for all iPads"
    echo ""
    
    # Parse each device type line
    while IFS= read -r line; do
        local parsed=$(parse_device_type_line "$line")
        local display_name=$(echo "$parsed" | cut -d'|' -f1)
        local full_identifier=$(echo "$parsed" | cut -d'|' -f2)
        
        if [ ! -z "$display_name" ] && [ ! -z "$full_identifier" ]; then
            device_display_names+=("$display_name")
            device_identifiers+=("$full_identifier")
            echo "$index - $display_name"
            index=$((index + 1))
        fi
    done <<< "$device_types"
    
    echo ""
    read -p "Enter numbers or 'all'/'iphone'/'ipad' (e.g., 1 3 5): " selection
    
    # Parse input
    SELECTED_DEVICES=()
    SELECTED_DEVICE_IDENTIFIERS=()
    
    if [ "$selection" = "all" ]; then
        SELECTED_DEVICES=("${device_display_names[@]}")
        SELECTED_DEVICE_IDENTIFIERS=("${device_identifiers[@]}")
        print_info "✓ Selected all ${#SELECTED_DEVICES[@]} devices"
    elif [ "$selection" = "iphone" ]; then
        for i in "${!device_display_names[@]}"; do
            if [[ "${device_display_names[$i]}" == iPhone* ]]; then
                SELECTED_DEVICES+=("${device_display_names[$i]}")
                SELECTED_DEVICE_IDENTIFIERS+=("${device_identifiers[$i]}")
            fi
        done
        print_info "✓ Selected all ${#SELECTED_DEVICES[@]} iPhones"
    elif [ "$selection" = "ipad" ]; then
        for i in "${!device_display_names[@]}"; do
            if [[ "${device_display_names[$i]}" == iPad* ]]; then
                SELECTED_DEVICES+=("${device_display_names[$i]}")
                SELECTED_DEVICE_IDENTIFIERS+=("${device_identifiers[$i]}")
            fi
        done
        print_info "✓ Selected all ${#SELECTED_DEVICES[@]} iPads"
    else
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#device_display_names[@]}" ]; then
                local idx=$((num - 1))
                SELECTED_DEVICES+=("${device_display_names[$idx]}")
                SELECTED_DEVICE_IDENTIFIERS+=("${device_identifiers[$idx]}")
                print_info "✓ Selected: ${device_display_names[$idx]}"
            else
                print_warning "✗ Skipping invalid number: $num"
            fi
        done
    fi
    
    echo ""
    
    if [ ${#SELECTED_DEVICES[@]} -eq 0 ]; then
        print_error "No devices selected"
        exit 1
    fi
    
    print_info "Total ${#SELECTED_DEVICES[@]} device models selected"
}

# Let user select iOS versions
select_ios_versions() {
    print_section "SELECT iOS VERSIONS"
    
    print_info "Scanning available iOS runtimes..."
    echo ""
    
    local runtimes=$(get_available_runtimes)
    
    if [ -z "$runtimes" ]; then
        print_critical "NO iOS RUNTIMES FOUND"
        print_warning "Please install at least one iOS runtime first"
        print_info "You can install runtimes via Xcode > Settings > Platforms"
        exit 1
    fi
    
    # Create arrays to store versions and runtime_ids
    local -a versions=()
    local -a runtime_ids=()
    local index=1
    
    echo "Select iOS versions to create simulators (space-separated):"
    
    # Parse each runtime line
    while IFS= read -r line; do
        local parsed=$(parse_runtime_line "$line")
        local version=$(echo "$parsed" | cut -d'|' -f1)
        local runtime_id=$(echo "$parsed" | cut -d'|' -f2)
        
        if [ ! -z "$version" ] && [ ! -z "$runtime_id" ]; then
            versions+=("$version")
            runtime_ids+=("$runtime_id")
            echo "$index - iOS $version"
            index=$((index + 1))
        fi
    done <<< "$runtimes"
    
    echo ""
    read -p "Enter numbers (e.g., 1 3 4): " selection
    
    # Parse input
    SELECTED_IOS_VERSIONS=()
    SELECTED_RUNTIME_IDS=()
    
    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#versions[@]}" ]; then
            local idx=$((num - 1))
            SELECTED_IOS_VERSIONS+=("${versions[$idx]}")
            SELECTED_RUNTIME_IDS+=("${runtime_ids[$idx]}")
            print_info "✓ Selected: iOS ${versions[$idx]}"
        else
            print_warning "✗ Skipping invalid number: $num"
        fi
    done
    
    echo ""
    
    if [ ${#SELECTED_IOS_VERSIONS[@]} -eq 0 ]; then
        print_error "No versions selected"
        exit 1
    fi
    
    print_info "Total ${#SELECTED_IOS_VERSIONS[@]} iOS versions selected"
}

# Check if device type exists
check_device_type() {
    local device_name=$1
    local temp_file=$(mktemp)
    
    if timeout 5s xcrun simctl list devicetypes > "$temp_file" 2>&1; then
        if grep -F -q "$device_name" "$temp_file"; then
            rm -f "$temp_file"
            return 0
        else
            rm -f "$temp_file"
            return 1
        fi
    else
        rm -f "$temp_file"
        print_error "Timeout when getting device types list"
        return 1
    fi
}

# Create simulator device
create_simulator() {
    local device_display_name=$1
    local device_identifier=$2
    local ios_version=$3
    local runtime_id=$4
    
    # Simulator name (use display name)
    local sim_name="[iOS ${ios_version}] ${device_display_name}"
    
    # Check if simulator already exists
    print_info "  ⊙ Checking: $sim_name"
    local temp_file=$(mktemp)
    if timeout 10s xcrun simctl list devices > "$temp_file" 2>&1; then
        if grep -F -q "$sim_name" "$temp_file"; then
            rm -f "$temp_file"
            print_warning "  → Already exists, skipping"
            return 2  # Return code 2 = skipped
        fi
        rm -f "$temp_file"
    else
        rm -f "$temp_file"
        print_error "  → Timeout when checking simulators"
        return 1
    fi
    
    # Create simulator with timeout (use full identifier)
    print_info "  + Creating..."
    
    local create_output
    local temp_output=$(mktemp)
    if timeout 30s xcrun simctl create "$sim_name" "$device_identifier" "$runtime_id" > "$temp_output" 2>&1; then
        create_output=$(cat "$temp_output")
        rm -f "$temp_output"
        print_info "  ✓ Success! UUID: ${create_output:0:36}"
        return 0
    else
        local exit_code=$?
        create_output=$(cat "$temp_output")
        rm -f "$temp_output"
        
        if [ $exit_code -eq 124 ]; then
            print_error "  ✗ TIMEOUT (>30s)"
        else
            print_error "  ✗ Error: $create_output"
        fi
        return 1
    fi
}

# Create all simulators
create_all_simulators() {
    print_section "CREATE SIMULATORS"
    
    local total_devices=${#SELECTED_DEVICES[@]}
    local total_versions=${#SELECTED_IOS_VERSIONS[@]}
    local total_sims=$((total_devices * total_versions))
    local current=0
    local success=0
    local failed=0
    local skipped=0
    
    print_info "Will create total $total_sims simulators ($total_devices devices × $total_versions iOS versions)"
    echo ""
    
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local device_idx=0
    for device_display in "${SELECTED_DEVICES[@]}"; do
        local device_identifier="${SELECTED_DEVICE_IDENTIFIERS[$device_idx]}"
        device_idx=$((device_idx + 1))
        
        echo ""
        print_info "━━━ Device: $device_display ━━━"
        
        local version_idx=0
        for version in "${SELECTED_IOS_VERSIONS[@]}"; do
            current=$((current + 1))
            echo ""
            echo "[$current/$total_sims] iOS $version"
            
            # Get corresponding runtime ID
            local runtime_id="${SELECTED_RUNTIME_IDS[$version_idx]}"
            version_idx=$((version_idx + 1))
            
            if [ -z "$runtime_id" ]; then
                print_warning "  ⊙ Skipping (no runtime for iOS $version)"
                skipped=$((skipped + 1))
                continue
            fi
            
            local create_result
            create_simulator "$device_display" "$device_identifier" "$version" "$runtime_id" && create_result=0 || create_result=$?
            
            if [ $create_result -eq 0 ]; then
                success=$((success + 1))
            elif [ $create_result -eq 2 ]; then
                skipped=$((skipped + 1))
            else
                failed=$((failed + 1))
                print_warning "⚠ Continuing with next simulator..."
            fi
            
            # Short wait between creations
            sleep 0.3
        done
        
        # Reset version_idx for next device
        version_idx=0
    done
    
    echo ""
    print_section "RESULTS"
    print_info "✓ Success: $success"
    print_info "✗ Failed: $failed"
    print_info "⊙ Already exists/Skipped: $skipped"
    print_info "━ Total: $total_sims"
}

# Show summary
show_summary() {
    print_section "SUMMARY"
    
    echo ""
    print_info "List of all created simulators:"
    echo ""
    
    for version in "${SELECTED_IOS_VERSIONS[@]}"; do
        echo -e "${YELLOW}iOS $version:${NC}"
        xcrun simctl list devices "iOS $version" 2>/dev/null | grep -E "iPhone|iPad" | sed 's/^/  /'
        echo ""
    done
    
    local total_sims=$(xcrun simctl list devices | grep -c -E "iPhone.*iOS|iPad.*iOS")
    print_info "Total iPhone/iPad simulators: $total_sims"
}

# Delete simulators by pattern or specific selection
delete_all_simulators() {
    print_warning "Choose deletion method:"
    echo "1) Delete all simulators containing '[iOS'"
    echo "2) Delete simulators by specific iOS version"
    echo "3) Select specific simulators to delete (by index)"
    echo "4) Cancel"
    echo ""
    read -p "Enter choice (1-4): " delete_choice
    
    case $delete_choice in
        1)
            print_critical "ARE YOU SURE YOU WANT TO DELETE ALL SIMULATORS WITH FORMAT [iOS x.x]?"
            read -p "Enter 'YES' to confirm: " confirm
            
            if [ "$confirm" != "YES" ]; then
                print_info "Deletion cancelled"
                return
            fi
            
            print_info "Deleting simulators..."
            local count=0
            
            local all_sims=$(xcrun simctl list devices | grep "\[iOS" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
            
            while IFS= read -r sim_id; do
                if [ ! -z "$sim_id" ]; then
                    local sim_name=$(xcrun simctl list devices | grep "$sim_id" | sed -E 's/^[[:space:]]*//' | sed -E 's/ \([^)]+\).*$//')
                    xcrun simctl delete "$sim_id" 2>/dev/null
                    print_info "Deleted: $sim_name"
                    count=$((count + 1))
                fi
            done <<< "$all_sims"
            
            print_info "Deleted $count simulators"
            ;;
        2)
            read -p "Enter iOS version to delete (e.g., 18.2): " ios_ver
            print_critical "ARE YOU SURE YOU WANT TO DELETE ALL iOS $ios_ver SIMULATORS?"
            read -p "Enter 'YES' to confirm: " confirm
            
            if [ "$confirm" != "YES" ]; then
                print_info "Deletion cancelled"
                return
            fi
            
            print_info "Deleting iOS $ios_ver simulators..."
            local count=0
            
            local all_sims=$(xcrun simctl list devices | grep "\[iOS $ios_ver\]" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
            
            while IFS= read -r sim_id; do
                if [ ! -z "$sim_id" ]; then
                    local sim_name=$(xcrun simctl list devices | grep "$sim_id" | sed -E 's/^[[:space:]]*//' | sed -E 's/ \([^)]+\).*$//')
                    xcrun simctl delete "$sim_id" 2>/dev/null
                    print_info "Deleted: $sim_name"
                    count=$((count + 1))
                fi
            done <<< "$all_sims"
            
            print_info "Deleted $count simulators"
            ;;
        3)
            # Get list of ALL simulators (iPhone and iPad)
            local temp_file=$(mktemp)
            xcrun simctl list devices available | grep -E "iPhone|iPad" > "$temp_file"
            
            if [ ! -s "$temp_file" ]; then
                rm -f "$temp_file"
                print_warning "No simulators found"
                return
            fi
            
            # Create arrays to store information
            local -a sim_names=()
            local -a sim_ids=()
            local index=1
            
            echo ""
            print_info "List of all simulators:"
            echo ""
            
            while IFS= read -r line; do
                # Skip header lines (-- iOS x.x --)
                if [[ "$line" =~ ^--.*--$ ]]; then
                    continue
                fi
                
                local sim_name=$(echo "$line" | sed -E 's/^[[:space:]]*//' | sed -E 's/ \([^)]+\).*$//')
                local sim_id=$(echo "$line" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
                
                # Check if it's a valid UUID
                if [[ "$sim_id" =~ ^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$ ]]; then
                    sim_names+=("$sim_name")
                    sim_ids+=("$sim_id")
                    echo "$index - $sim_name"
                    index=$((index + 1))
                fi
            done < "$temp_file"
            
            rm -f "$temp_file"
            
            if [ ${#sim_names[@]} -eq 0 ]; then
                print_warning "No simulators found"
                return
            fi
            
            echo ""
            echo "Hint: Enter 'all' to select all, 'iphone' for iPhones, 'ipad' for iPads"
            read -p "Enter numbers of simulators to delete (space-separated): " selection
            
            if [ -z "$selection" ]; then
                print_info "Deletion cancelled"
                return
            fi
            
            # Parse selection
            local -a to_delete_names=()
            local -a to_delete_ids=()
            
            if [ "$selection" = "all" ]; then
                to_delete_names=("${sim_names[@]}")
                to_delete_ids=("${sim_ids[@]}")
            elif [ "$selection" = "iphone" ]; then
                for i in "${!sim_names[@]}"; do
                    if [[ "${sim_names[$i]}" == *iPhone* ]]; then
                        to_delete_names+=("${sim_names[$i]}")
                        to_delete_ids+=("${sim_ids[$i]}")
                    fi
                done
            elif [ "$selection" = "ipad" ]; then
                for i in "${!sim_names[@]}"; do
                    if [[ "${sim_names[$i]}" == *iPad* ]]; then
                        to_delete_names+=("${sim_names[$i]}")
                        to_delete_ids+=("${sim_ids[$i]}")
                    fi
                done
            else
                for num in $selection; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#sim_names[@]}" ]; then
                        local idx=$((num - 1))
                        to_delete_names+=("${sim_names[$idx]}")
                        to_delete_ids+=("${sim_ids[$idx]}")
                    else
                        print_warning "Skipping invalid number: $num"
                    fi
                done
            fi
            
            if [ ${#to_delete_ids[@]} -eq 0 ]; then
                print_warning "No simulators selected"
                return
            fi
            
            echo ""
            print_critical "ARE YOU SURE YOU WANT TO DELETE ${#to_delete_ids[@]} SIMULATOR(S)?"
            echo "Will delete:"
            for name in "${to_delete_names[@]}"; do
                echo "  • $name"
            done
            echo ""
            read -p "Enter 'YES' to confirm: " confirm
            
            if [ "$confirm" != "YES" ]; then
                print_info "Deletion cancelled"
                return
            fi
            
            print_info "Deleting simulators..."
            local count=0
            
            for i in "${!to_delete_ids[@]}"; do
                xcrun simctl delete "${to_delete_ids[$i]}" 2>/dev/null
                print_info "Deleted: ${to_delete_names[$i]}"
                count=$((count + 1))
            done
            
            print_info "Deleted $count simulators"
            ;;
        4)
            print_info "Deletion cancelled"
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
}

# --- Simulator Manager Operational Functions ---

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

action_start_simulator() {
    print_section "START SIMULATOR"
    
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
            xcrun simctl boot "$uuid"
            
            print_info "Opening interface..."
            open -a Simulator
            print_info "✓ Done"
        fi
    fi
    echo ""
    read -p "Press Enter to continue..."
}

action_wipe_simulator() {
    print_section "WIPE SIMULATOR DATA"
    print_warning "⚠️  This will factory reset the device and delete all installed apps/data."
    
    if select_simulator; then
        local uuid="${DEVICE_UUIDS[$SELECTED_INDEX]}"
        local name="${DEVICE_NAMES[$SELECTED_INDEX]}"
        local status="${DEVICE_STATUS[$SELECTED_INDEX]}"

        echo ""
        echo -e "Target: ${CYAN}$name${NC}"
        read -p "Are you sure you want to WIPE this device? (type 'yes'): " confirm

        if [ "$confirm" == "yes" ]; then
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

action_shutdown_all() {
    print_section "SHUTDOWN ALL SIMULATORS"
    print_info "Stopping all running devices..."
    xcrun simctl shutdown all
    print_info "✓ All devices shutdown."
    sleep 1
}

# Main menu
show_menu() {
    while true; do
        clear
        print_section "iOS SIMULATOR BATCH CREATOR & MANAGER"
        echo ""
        echo "Options:"
        echo "1) Create simulators (Select device models and iOS versions)"
        echo "2) Start a simulator (Boot & Open)"
        echo "3) Wipe simulator data (Factory Reset)"
        echo "4) Shutdown ALL simulators"
        echo "5) View current simulators list"
        echo "6) View installed iOS runtimes"
        echo "7) View available device types"
        echo "8) DELETE simulators by pattern"
        echo "9) Exit"
        echo ""
        read -p "Enter choice (1-9): " choice
        
        case $choice in
            1)
                echo ""
                select_device_models
                echo ""
                select_ios_versions
                echo ""
                print_section "CONFIRMATION"
                echo ""
                print_info "Will create ${#SELECTED_DEVICES[@]} devices × ${#SELECTED_IOS_VERSIONS[@]} iOS versions = $((${#SELECTED_DEVICES[@]} * ${#SELECTED_IOS_VERSIONS[@]})) simulators"
                echo ""
                echo "Selected devices:"
                for device in "${SELECTED_DEVICES[@]}"; do
                    echo "  • $device"
                done
                echo ""
                echo "Selected iOS versions:"
                for version in "${SELECTED_IOS_VERSIONS[@]}"; do
                    echo "  • iOS $version"
                done
                echo ""
                read -p "Continue to create simulators? (y/n): " confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    echo ""
                    create_all_simulators
                    echo ""
                    show_summary
                else
                    print_info "Cancelled"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                echo ""
                action_start_simulator
                ;;
            3)
                echo ""
                action_wipe_simulator
                ;;
            4)
                echo ""
                action_shutdown_all
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                print_info "Current simulators list:"
                xcrun simctl list devices available
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                echo ""
                print_info "Installed iOS runtimes:"
                xcrun simctl list runtimes | grep iOS
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                echo ""
                print_info "Available device types:"
                get_available_device_types
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                echo ""
                delete_all_simulators
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
                print_info "Exiting program"
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                sleep 1
                ;;
        esac
    done
}

# Main
main() {
    check_arm
    check_xcode
    echo ""
    show_menu
}

# Run script
main