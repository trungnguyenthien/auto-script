#!/bin/bash

# Script tự động tạo iOS Simulator devices cho macOS ARM
# Cho phép chọn iOS versions từ các runtime đã cài sẵn

set -e

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Danh sách devices cần tạo
DEVICES=(
    "iPhone SE (3rd generation)"
    "iPhone 14"
    "iPhone 14 Plus"
    "iPhone 14 Pro"
    "iPhone 14 Pro Max"
    "iPhone 15 Pro"
    "iPhone 16"
    "iPhone 16 Plus"
    "iPhone 16 Pro"
    "iPhone 16 Pro Max"
)

# Biến lưu các iOS versions được chọn
SELECTED_IOS_VERSIONS=()
SELECTED_RUNTIME_IDS=()

# Hàm in màu
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_section() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Kiểm tra macOS ARM
check_arm() {
    if [[ $(uname -m) != "arm64" ]]; then
        print_error "Script này chỉ dành cho macOS ARM (Apple Silicon)"
        exit 1
    fi
    print_info "Đã xác nhận macOS ARM ✓"
}

# Kiểm tra Xcode đã cài đặt
check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode chưa được cài đặt. Vui lòng cài Xcode từ App Store"
        exit 1
    fi
    
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    print_info "Đã tìm thấy: $XCODE_VERSION ✓"
}

# Lấy tất cả runtimes iOS có sẵn
get_available_runtimes() {
    local temp_file=$(mktemp)
    if timeout 10s xcrun simctl list runtimes > "$temp_file" 2>&1; then
        # Lấy tất cả dòng chứa iOS runtime (loại trừ watchOS, tvOS)
        grep "iOS" "$temp_file" | grep -v "watchOS" | grep -v "tvOS"
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Parse runtime line để lấy version và ID
parse_runtime_line() {
    local line=$1
    # Format: iOS 17.5 (17.5 - 21F79) - com.apple.CoreSimulator.SimRuntime.iOS-17-5
    
    # Lấy version number (ví dụ: 17.5)
    local version=$(echo "$line" | sed -E 's/^iOS ([0-9]+\.[0-9]+).*/\1/')
    
    # Lấy runtime ID
    local runtime_id=$(echo "$line" | sed -E 's/.*- (com\.apple\.CoreSimulator\.SimRuntime\.[^ ]+).*/\1/')
    
    echo "$version|$runtime_id"
}

# Cho người dùng chọn iOS versions
select_ios_versions() {
    print_section "CHỌN iOS VERSIONS"
    
    print_info "Đang quét các iOS runtime có sẵn..."
    echo ""
    
    local runtimes=$(get_available_runtimes)
    
    if [ -z "$runtimes" ]; then
        print_error "Không tìm thấy iOS runtime nào được cài đặt"
        print_warning "Vui lòng cài đặt ít nhất một iOS runtime trước"
        print_info "Bạn có thể cài runtime bằng Xcode > Settings > Platforms"
        exit 1
    fi
    
    # Tạo mảng để lưu các version và runtime_id
    local -a versions=()
    local -a runtime_ids=()
    local index=1
    
    echo "Hãy chọn các iOS version cần tạo simulator (phân cách bởi khoảng trắng):"
    
    # Parse từng dòng runtime
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
    read -p "Nhập các số tương ứng (ví dụ: 1 3 4): " selection
    
    # Parse input
    SELECTED_IOS_VERSIONS=()
    SELECTED_RUNTIME_IDS=()
    
    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#versions[@]}" ]; then
            local idx=$((num - 1))
            SELECTED_IOS_VERSIONS+=("${versions[$idx]}")
            SELECTED_RUNTIME_IDS+=("${runtime_ids[$idx]}")
            print_info "✓ Đã chọn: iOS ${versions[$idx]}"
        else
            print_warning "✗ Bỏ qua số không hợp lệ: $num"
        fi
    done
    
    echo ""
    
    if [ ${#SELECTED_IOS_VERSIONS[@]} -eq 0 ]; then
        print_error "Không có version nào được chọn"
        exit 1
    fi
    
    print_info "Tổng cộng ${#SELECTED_IOS_VERSIONS[@]} iOS version được chọn"
}

# Kiểm tra device type có tồn tại không
check_device_type() {
    local device_name=$1
    local temp_file=$(mktemp)
    
    if timeout 5s xcrun simctl list devicetypes > "$temp_file" 2>&1; then
        if grep -q "$device_name" "$temp_file"; then
            rm -f "$temp_file"
            return 0
        else
            rm -f "$temp_file"
            return 1
        fi
    else
        rm -f "$temp_file"
        print_error "Timeout khi lấy danh sách device types"
        return 1
    fi
}

# Tạo simulator device
create_simulator() {
    local device_name=$1
    local ios_version=$2
    local runtime_id=$3
    
    # Tên simulator
    local sim_name="[iOS ${ios_version}] ${device_name}"
    
    # Kiểm tra xem simulator đã tồn tại chưa
    print_info "  ⊙ Kiểm tra: $sim_name"
    local temp_file=$(mktemp)
    if timeout 10s xcrun simctl list devices > "$temp_file" 2>&1; then
        if grep -q "$sim_name" "$temp_file"; then
            rm -f "$temp_file"
            print_warning "  → Đã tồn tại, bỏ qua"
            return 2  # Return code 2 = skipped
        fi
        rm -f "$temp_file"
    else
        rm -f "$temp_file"
        print_error "  → Timeout khi kiểm tra simulators"
        return 1
    fi
    
    # Tạo simulator với timeout
    print_info "  + Đang tạo..."
    
    local create_output
    local temp_output=$(mktemp)
    if timeout 30s xcrun simctl create "$sim_name" "$device_name" "$runtime_id" > "$temp_output" 2>&1; then
        create_output=$(cat "$temp_output")
        rm -f "$temp_output"
        print_info "  ✓ Thành công! UUID: ${create_output:0:36}"
        return 0
    else
        local exit_code=$?
        create_output=$(cat "$temp_output")
        rm -f "$temp_output"
        
        if [ $exit_code -eq 124 ]; then
            print_error "  ✗ TIMEOUT (>30s)"
        else
            print_error "  ✗ Lỗi: $create_output"
        fi
        return 1
    fi
}

# Tạo tất cả simulators
create_all_simulators() {
    print_section "TẠO SIMULATORS"
    
    local total_devices=${#DEVICES[@]}
    local total_versions=${#SELECTED_IOS_VERSIONS[@]}
    local total_sims=$((total_devices * total_versions))
    local current=0
    local success=0
    local failed=0
    local skipped=0
    
    print_info "Sẽ tạo tổng cộng $total_sims simulators ($total_devices devices × $total_versions iOS versions)"
    echo ""
    
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for device in "${DEVICES[@]}"; do
        echo ""
        print_info "━━━ Device: $device ━━━"
        
        local version_idx=0
        for version in "${SELECTED_IOS_VERSIONS[@]}"; do
            current=$((current + 1))
            echo ""
            echo "[$current/$total_sims] iOS $version"
            
            # Lấy runtime ID tương ứng
            local runtime_id="${SELECTED_RUNTIME_IDS[$version_idx]}"
            version_idx=$((version_idx + 1))
            
            if [ -z "$runtime_id" ]; then
                print_warning "  ⊙ Bỏ qua (không có runtime iOS $version)"
                skipped=$((skipped + 1))
                continue
            fi
            
            local create_result
            create_simulator "$device" "$version" "$runtime_id"
            create_result=$?
            
            if [ $create_result -eq 0 ]; then
                success=$((success + 1))
            elif [ $create_result -eq 2 ]; then
                skipped=$((skipped + 1))
            else
                failed=$((failed + 1))
                print_warning "⚠ Tiếp tục với simulator tiếp theo..."
            fi
            
            # Chờ ngắn giữa các lần tạo
            sleep 0.3
        done
    done
    
    echo ""
    print_section "KẾT QUẢ"
    print_info "✓ Thành công: $success"
    print_info "✗ Thất bại: $failed"
    print_info "⊙ Đã tồn tại/Bỏ qua: $skipped"
    print_info "━ Tổng: $total_sims"
}

# Hiển thị tổng kết
show_summary() {
    print_section "TỔNG KẾT"
    
    echo ""
    print_info "Danh sách tất cả simulators đã tạo:"
    echo ""
    
    for version in "${SELECTED_IOS_VERSIONS[@]}"; do
        echo -e "${YELLOW}iOS $version:${NC}"
        xcrun simctl list devices "iOS $version" 2>/dev/null | grep -E "iPhone" | sed 's/^/  /'
        echo ""
    done
    
    local total_sims=$(xcrun simctl list devices | grep -c "iPhone.*iOS")
    print_info "Tổng số simulators iPhone: $total_sims"
}

# Xóa tất cả simulators trong danh sách DEVICES
delete_all_simulators() {
    print_warning "Bạn có chắc muốn XÓA TẤT CẢ simulators của các devices trong danh sách?"
    read -p "Nhập 'YES' để xác nhận: " confirm
    
    if [ "$confirm" != "YES" ]; then
        print_info "Hủy thao tác xóa"
        return
    fi
    
    print_info "Đang xóa tất cả simulators..."
    
    for device in "${DEVICES[@]}"; do
        # Xóa cho tất cả iOS versions có trong hệ thống
        local all_sims=$(xcrun simctl list devices | grep "$device" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
        
        while IFS= read -r sim_id; do
            if [ ! -z "$sim_id" ]; then
                local sim_name=$(xcrun simctl list devices | grep "$sim_id" | sed -E 's/^[[:space:]]*//' | sed -E 's/ \([^)]+\).*$//')
                xcrun simctl delete "$sim_id" 2>/dev/null
                print_info "Đã xóa: $sim_name"
            fi
        done <<< "$all_sims"
    done
    
    print_info "Hoàn tất xóa simulators"
}

# Menu chính
show_menu() {
    clear
    print_section "iOS SIMULATOR BATCH CREATOR"
    echo ""
    echo "Script sẽ tạo simulators cho các devices sau:"
    for device in "${DEVICES[@]}"; do
        echo "  • $device"
    done
    echo ""
    echo "Tùy chọn:"
    echo "1) Chọn iOS versions và tạo simulators"
    echo "2) Xem danh sách simulators hiện có"
    echo "3) Xem danh sách iOS runtimes đã cài"
    echo "4) XÓA tất cả simulators trong danh sách DEVICES"
    echo "5) Thoát"
    echo ""
    read -p "Nhập lựa chọn (1-5): " choice
    
    case $choice in
        1)
            echo ""
            select_ios_versions
            echo ""
            create_all_simulators
            echo ""
            show_summary
            ;;
        2)
            echo ""
            print_info "Danh sách simulators hiện có:"
            xcrun simctl list devices available
            ;;
        3)
            echo ""
            print_info "Danh sách iOS runtimes đã cài:"
            xcrun simctl list runtimes | grep iOS
            ;;
        4)
            echo ""
            delete_all_simulators
            ;;
        5)
            print_info "Thoát chương trình"
            exit 0
            ;;
        *)
            print_error "Lựa chọn không hợp lệ"
            exit 1
            ;;
    esac
}

# Main
main() {
    check_arm
    check_xcode
    echo ""
    show_menu
}

# Chạy script
main