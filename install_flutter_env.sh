#!/bin/bash

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FLUTTER_VERSION="3.44.0"
CMDLINE_TOOLS_VERSION="11076708"
RUBY_VERSION="3.2.2"
ANDROID_HOME="$HOME/Library/Android/sdk"
INSTALL_LOG="$HOME/.flutter_env_install.log"
SHELL_RC="$HOME/.zshrc"

# Detect existing Flutter installation or fallback to default
if command -v flutter &>/dev/null; then
    FLUTTER_BIN_PATH=$(which flutter)
    while [ -h "$FLUTTER_BIN_PATH" ]; do
        FLUTTER_BIN_PATH=$(readlink "$FLUTTER_BIN_PATH")
    done
    FLUTTER_HOME=$(cd "$(dirname "$FLUTTER_BIN_PATH")/.." && pwd)
else
    FLUTTER_HOME="$HOME/flutter"
fi


# Function to log completed steps
log_step() {
    echo "$1" >> "$INSTALL_LOG"
}

# Function to check if step is completed
is_step_completed() {
    if [ -f "$INSTALL_LOG" ]; then
        grep -q "^$1$" "$INSTALL_LOG"
        return $?
    fi
    return 1
}

# Function to skip step message
skip_step() {
    echo -e "${GREEN}✓ $1 (already completed, skipping)${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
}

# Helper function to initialize rbenv safely
init_rbenv() {
    # Remove stale shim locks if they exist to prevent rehash errors
    rm -f "$HOME/.rbenv/shims/.rbenv-shim"
    
    # Temporarily disable set -e to prevent rbenv init/rehash failure from stopping the script
    set +e
    eval "$(rbenv init -)"
    set -e
}

# Helper function to run rbenv rehash safely
rbenv_rehash() {
    rm -f "$HOME/.rbenv/shims/.rbenv-shim"
    set +e
    rbenv rehash 2>/dev/null
    set -e
}

verify_project_environment() {
    # Check if we are in a Flutter project (presence of pubspec.yaml and android/app/build.gradle)
    if [ ! -f "pubspec.yaml" ] || [ ! -f "android/app/build.gradle" ]; then
        print_info "Not executed inside a Flutter project directory. Skipping project-specific verification."
        return 0
    fi
    
    echo -e "\n${BLUE}=== VERIFYING PROJECT ENVIRONMENT FOR FLUTTER 3.44 ===${NC}"
    
    local build_gradle="android/app/build.gradle"
    local gradle_properties="android/gradle/wrapper/gradle-wrapper.properties"
    local has_errors=false
    local has_warnings=false
    
    # 1. Check compileSdkVersion / compileSdk
    if grep -E "compileSdk[vV]ersion|[cC]ompileSdk" "$build_gradle" | grep -q "flutter\."; then
        echo -e "  • compileSdkVersion: ${GREEN}OK${NC} (Inherited from flutter)"
    else
        local compile_sdk=$(grep -E "compileSdk[vV]ersion|[cC]ompileSdk" "$build_gradle" | grep -oE "[0-9]+" | head -n 1 || true)
        if [ -n "$compile_sdk" ]; then
            if [ "$compile_sdk" -ge 36 ]; then
                echo -e "  • compileSdkVersion: ${GREEN}OK${NC} (Version: $compile_sdk)"
            else
                echo -e "  • compileSdkVersion: ${YELLOW}WARNING${NC} (Version: $compile_sdk. Khuyến nghị nâng lên >= 36)"
                has_warnings=true
            fi
        else
            echo -e "  • compileSdkVersion: ${YELLOW}UNKNOWN${NC} (Không tìm thấy định dạng số cứng)"
        fi
    fi
    
    # 2. Check targetSdkVersion / targetSdk
    if grep -E "targetSdk[vV]ersion|[tT]argetSdk" "$build_gradle" | grep -q "flutter\."; then
        echo -e "  • targetSdkVersion: ${GREEN}OK${NC} (Inherited from flutter)"
    else
        local target_sdk=$(grep -E "targetSdk[vV]ersion|[tT]argetSdk" "$build_gradle" | grep -oE "[0-9]+" | head -n 1 || true)
        if [ -n "$target_sdk" ]; then
            if [ "$target_sdk" -ge 36 ]; then
                echo -e "  • targetSdkVersion: ${GREEN}OK${NC} (Version: $target_sdk)"
            else
                echo -e "  • targetSdkVersion: ${YELLOW}WARNING${NC} (Version: $target_sdk. Khuyến nghị nâng lên >= 36 để cập nhật Play Store)"
                has_warnings=true
            fi
        else
            echo -e "  • targetSdkVersion: ${YELLOW}UNKNOWN${NC} (Không tìm thấy định dạng số cứng)"
        fi
    fi
    
    # 3. Check minSdkVersion / minSdk
    if grep -E "minSdk[vV]ersion|[mM]inSdk" "$build_gradle" | grep -q "flutter\."; then
        echo -e "  • minSdkVersion: ${GREEN}OK${NC} (Inherited from flutter)"
    else
        local min_sdk=$(grep -E "minSdk[vV]ersion|[mM]inSdk" "$build_gradle" | grep -oE "[0-9]+" | head -n 1 || true)
        if [ -n "$min_sdk" ]; then
            if [ "$min_sdk" -ge 24 ]; then
                echo -e "  • minSdkVersion: ${GREEN}OK${NC} (Version: $min_sdk)"
            elif [ "$min_sdk" -ge 21 ]; then
                echo -e "  • minSdkVersion: ${YELLOW}WARNING${NC} (Version: $min_sdk. Khuyến nghị nâng lên >= 24 để tương thích thư viện mới)"
                has_warnings=true
            else
                echo -e "  • minSdkVersion: ${RED}ERROR${NC} (Version: $min_sdk. Thấp hơn yêu cầu tối thiểu 21 của Flutter)"
                has_errors=true
            fi
        else
            echo -e "  • minSdkVersion: ${YELLOW}UNKNOWN${NC} (Không tìm thấy định dạng số cứng)"
        fi
    fi
    
    # 4. Check Gradle Wrapper Version
    if [ -f "$gradle_properties" ]; then
        local gradle_url=$(grep "distributionUrl" "$gradle_properties" || true)
        local gradle_ver=$(echo "$gradle_url" | grep -oE "gradle-[0-9]+\.[0-9]+(\.[0-9]+)?" | cut -d'-' -f2 || true)
        
        if [ -n "$gradle_ver" ]; then
            local major=$(echo "$gradle_ver" | cut -d'.' -f1)
            local minor=$(echo "$gradle_ver" | cut -d'.' -f2)
            
            local is_valid=false
            if [ "$major" -gt 7 ]; then
                is_valid=true
            elif [ "$major" -eq 7 ] && [ "$minor" -ge 3 ]; then
                is_valid=true
            fi
            
            if $is_valid; then
                if [ "$major" -ge 8 ]; then
                    echo -e "  • Gradle Version: ${GREEN}OK${NC} (Version: $gradle_ver)"
                else
                    echo -e "  • Gradle Version: ${YELLOW}WARNING${NC} (Version: $gradle_ver. Khuyến nghị nâng lên >= 8.x để hỗ trợ JDK 17 tốt nhất)"
                    has_warnings=true
                fi
            else
                echo -e "  • Gradle Version: ${RED}ERROR${NC} (Version: $gradle_ver. Gradle < 7.3 không hỗ trợ JDK 17)"
                has_errors=true
            fi
        else
            echo -e "  • Gradle Version: ${YELLOW}UNKNOWN${NC} (Không đọc được phiên bản trong $gradle_properties)"
        fi
    else
        echo -e "  • Gradle Version: ${RED}ERROR${NC} (Không tìm thấy tệp $gradle_properties)"
        has_errors=true
    fi
    
    echo -e "${BLUE}=====================================================${NC}\n"
    
    if $has_errors; then
        print_critical "Dự án hiện tại KHÔNG đáp ứng các yêu cầu bắt buộc tối thiểu cho Flutter 3.44."
        read -p "Bạn có muốn TẠM DỪNG cài đặt để cập nhật cấu hình dự án trước không? (y/n) [y]: " choice
        choice="${choice:-y}"
        if [[ "$choice" == "y" ]] || [[ "$choice" == "Y" ]]; then
            print_info "Đã dừng cài đặt để bạn cập nhật cấu hình dự án."
            exit 1
        fi
    elif $has_warnings; then
        print_warning "Cấu hình dự án hiện tại chưa đạt mức khuyến nghị tối ưu cho Flutter 3.44."
        read -p "Bạn có muốn TẠM DỪNG cài đặt để xem xét nâng cấp cấu hình trước không? (y/n) [y]: " choice
        choice="${choice:-y}"
        if [[ "$choice" == "y" ]] || [[ "$choice" == "Y" ]]; then
            print_info "Đã dừng cài đặt để bạn xem xét nâng cấp cấu hình dự án."
            exit 1
        fi
    else
        print_info "Dự án của bạn đáp ứng hoàn hảo các yêu cầu cấu hình cho Flutter 3.44!"
    fi
}

# Function to request sudo password upfront
request_sudo() {
    echo -e "${YELLOW}This script requires sudo access for some operations.${NC}"
    echo -e "${YELLOW}Please enter your password once:${NC}"
    sudo -v
    
    # Keep sudo alive in background
    while true; do
        sudo -n true
        sleep 50
        kill -0 "$$" || exit
    done 2>/dev/null &
}

echo -e "${BLUE}=== Flutter Development Environment Installation for macOS ===${NC}\n"
echo -e "${YELLOW}This script will install the following tools:${NC}\n"
echo -e "${GREEN}Core Tools:${NC}"
echo -e "  • Homebrew - Package manager for macOS"
echo -e "  • Xcode Command Line Tools - Essential build tools"
echo -e "  • Java 17 (OpenJDK) - Required for Android development"
echo -e ""
echo -e "${GREEN}iOS Development:${NC}"
echo -e "  • Ruby ${RUBY_VERSION} (via rbenv) - Stable version"
echo -e "  • CocoaPods (via Ruby gem) - iOS dependency manager"
echo -e "  • libimobiledevice, ideviceinstaller, ios-deploy - iOS build tools"
echo -e ""
echo -e "${GREEN}Android Development:${NC}"
echo -e "  • Android SDK Command Line Tools ${CMDLINE_TOOLS_VERSION}"
echo -e "  • Android Platform Tools"
echo -e "  • Android Platforms: API 34, 35, 36"
echo -e "  • Android Build Tools 35.0.0"
echo -e ""
echo -e "${GREEN}Flutter Framework:${NC}"
echo -e "  • Flutter SDK ${FLUTTER_VERSION} (Apple Silicon optimized)"
echo -e "\n${BLUE}Installation log: $INSTALL_LOG${NC}"
echo -e "${YELLOW}To reset and reinstall everything, delete: rm $INSTALL_LOG${NC}"
echo -e "\n${YELLOW}Press Enter to continue or Ctrl+C to cancel...${NC}"
read

# Kiểm tra yêu cầu môi trường dự án trước khi cài đặt
verify_project_environment

# Request sudo password once at the beginning
request_sudo

# ========== Step 1: Install Homebrew ==========
echo -e "\n${BLUE}[Step 1/7] Checking Homebrew...${NC}"

if is_step_completed "homebrew"; then
    skip_step "Homebrew already installed"
elif ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_RC"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$SHELL_RC"
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    log_step "homebrew"
    echo -e "${GREEN}✓ Homebrew installed${NC}"
else
    echo -e "${GREEN}✓ Homebrew already installed${NC}"
    log_step "homebrew"
fi

# Update Homebrew
if ! is_step_completed "homebrew-update"; then
    echo -e "${YELLOW}Updating Homebrew...${NC}"
    brew update
    log_step "homebrew-update"
    echo -e "${GREEN}✓ Homebrew updated${NC}"
else
    skip_step "Homebrew update"
fi

# ========== Step 2: Install Xcode Command Line Tools ==========
echo -e "\n${BLUE}[Step 2/7] Installing Xcode Command Line Tools...${NC}"

if is_step_completed "xcode-cli"; then
    skip_step "Xcode Command Line Tools"
elif ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
    
    # Try to install via softwareupdate (non-interactive)
    echo -e "${YELLOW}Attempting automatic installation...${NC}"
    sudo rm -rf /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress 2>/dev/null || true
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    
    PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
    if [ -n "$PROD" ]; then
        sudo softwareupdate -i "$PROD" --verbose
    else
        # Fallback to interactive installation
        echo -e "${YELLOW}A dialog will appear. Please click 'Install' and wait for it to complete.${NC}"
        xcode-select --install
        
        # Wait for installation to complete
        echo -e "${YELLOW}Waiting for Xcode Command Line Tools installation...${NC}"
        until xcode-select -p &> /dev/null; do
            sleep 5
        done
    fi
    
    # Accept license
    sudo xcodebuild -license accept 2>/dev/null || true
    
    log_step "xcode-cli"
    echo -e "${GREEN}✓ Xcode Command Line Tools installed${NC}"
else
    echo -e "${GREEN}✓ Xcode Command Line Tools already installed${NC}"
    # Accept license if needed
    sudo xcodebuild -license accept 2>/dev/null || true
    log_step "xcode-cli"
fi

# Check if Xcode app is installed
if [ -d "/Applications/Xcode.app" ]; then
    if ! is_step_completed "xcode-app"; then
        echo -e "${GREEN}✓ Xcode app detected${NC}"
        
        # Set Xcode path
        sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
        
        # Accept Xcode license
        sudo xcodebuild -license accept 2>/dev/null || true
        
        # Install additional components
        echo -e "${YELLOW}Installing Xcode additional components...${NC}"
        sudo xcodebuild -runFirstLaunch 2>/dev/null || true
        
        log_step "xcode-app"
        echo -e "${GREEN}✓ Xcode configured${NC}"
    else
        skip_step "Xcode app configuration"
    fi
else
    echo -e "${YELLOW}⚠️  Xcode app not found at /Applications/Xcode.app${NC}"
    echo -e "${YELLOW}⚠️  For full iOS development, please install Xcode from the App Store${NC}"
    echo -e "${YELLOW}⚠️  After installing Xcode, run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer${NC}"
fi

# ========== Step 3: Install Java 17 ==========
echo -e "\n${BLUE}[Step 3/7] Installing Java 17 (OpenJDK)...${NC}"

# Verification and auto-fix for Java 17 symlink
jdk_link="/Library/Java/JavaVirtualMachines/openjdk-17.jdk"
brew_prefix=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
brew_jdk_path="${brew_prefix}/opt/openjdk@17/libexec/openjdk.jdk"

if brew list openjdk@17 &> /dev/null; then
    if [ ! -d "$jdk_link" ] || [ ! -d "$jdk_link/Contents/Home" ]; then
        print_warning "Phát hiện Java 17 đã được cài đặt qua Homebrew nhưng liên kết hệ thống ($jdk_link) không tồn tại hoặc bị hỏng."
        read -p "Bạn có muốn script tự động sửa lỗi này bằng cách tạo lại liên kết (cần quyền sudo)? (y/n) [y]: " choice
        choice="${choice:-y}"
        if [[ "$choice" == "y" ]] || [[ "$choice" == "Y" ]]; then
            echo -e "${YELLOW}Đang tạo lại liên kết hệ thống cho Java 17...${NC}"
            sudo mkdir -p "/Library/Java/JavaVirtualMachines"
            sudo ln -sfn "$brew_jdk_path" "$jdk_link"
            echo -e "${GREEN}✓ Đã tạo liên kết hệ thống thành công.${NC}"
        else
            print_info "Bạn chọn tự sửa lỗi. Vui lòng mở một terminal khác và chạy lệnh sau:"
            echo -e "  sudo mkdir -p /Library/Java/JavaVirtualMachines"
            echo -e "  sudo ln -sfn $brew_jdk_path $jdk_link"
            read -p "Sau khi tự chạy xong câu lệnh trên, hãy nhấn Enter tại đây để tiếp tục..."
        fi
    fi
fi

if is_step_completed "java17"; then
    skip_step "Java 17"
elif ! brew list openjdk@17 &> /dev/null; then
    brew install openjdk@17
    
    # Create symlink
    sudo mkdir -p "/Library/Java/JavaVirtualMachines"
    sudo ln -sfn "$brew_jdk_path" "$jdk_link"
    
    log_step "java17"
    echo -e "${GREEN}✓ Java 17 installed${NC}"
else
    echo -e "${GREEN}✓ Java 17 already installed${NC}"
    log_step "java17"
fi

# Set JAVA_HOME
JAVA_HOME_PATH="/Library/Java/JavaVirtualMachines/openjdk-17.jdk/Contents/Home"
if ! grep -q "JAVA_HOME" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Java configuration" >> "$SHELL_RC"
    echo "export JAVA_HOME=\"$JAVA_HOME_PATH\"" >> "$SHELL_RC"
    echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >> "$SHELL_RC"
fi
export JAVA_HOME="$JAVA_HOME_PATH"
export PATH="$JAVA_HOME/bin:$PATH"

# ========== Step 4: Install Ruby via rbenv ==========
echo -e "\n${BLUE}[Step 4/7] Installing Ruby via rbenv...${NC}"

if is_step_completed "ruby"; then
    skip_step "Ruby (rbenv)"
else
    # Install rbenv and ruby-build if not installed
    if ! command -v rbenv &> /dev/null; then
        echo -e "${YELLOW}Installing rbenv and ruby-build...${NC}"
        brew install rbenv ruby-build
    else
        echo -e "${GREEN}✓ rbenv already installed${NC}"
    fi

    # Configure shell init for rbenv
    if ! grep -q "rbenv init" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Ruby configuration (rbenv)" >> "$SHELL_RC"
        echo 'eval "$(rbenv init -)"' >> "$SHELL_RC"
    fi
    init_rbenv

    # Check if selected Ruby version is installed
    if ! rbenv versions --bare | grep -q "^${RUBY_VERSION}$"; then
        echo -e "${YELLOW}Installing Ruby ${RUBY_VERSION} via rbenv (this may take a few minutes)...${NC}"
        rbenv install "${RUBY_VERSION}"
    else
        echo -e "${GREEN}✓ Ruby ${RUBY_VERSION} already installed in rbenv${NC}"
    fi

    # Set global version
    rbenv global "${RUBY_VERSION}"
    rbenv shell "${RUBY_VERSION}"

    log_step "ruby"
    echo -e "${GREEN}✓ Ruby version configured: $(ruby --version)${NC}"
fi

# ========== Step 5: Install CocoaPods via Ruby Gem ==========
echo -e "\n${BLUE}[Step 5/7] Installing CocoaPods via Ruby Gem...${NC}"

# Ensure rbenv is active in this shell session
init_rbenv

if is_step_completed "cocoapods"; then
    skip_step "CocoaPods"
else
    # Install CocoaPods gem
    if ! gem list -i cocoapods &> /dev/null; then
        echo -e "${YELLOW}Installing CocoaPods Gem...${NC}"
        gem install cocoapods
        rbenv_rehash
    else
        echo -e "${GREEN}✓ CocoaPods Gem already installed${NC}"
    fi
    
    # Verify pod is available
    if command -v pod &> /dev/null; then
        POD_VERSION=$(pod --version)
        log_step "cocoapods"
        echo -e "${GREEN}✓ CocoaPods installed (version: ${POD_VERSION})${NC}"
        
        # Setup CocoaPods
        if ! is_step_completed "cocoapods-setup"; then
            echo -e "${YELLOW}Setting up CocoaPods...${NC}"
            pod setup --verbose || true
            log_step "cocoapods-setup"
        fi
    else
        echo -e "${RED}Error: CocoaPods was installed but 'pod' command is not found.${NC}"
        exit 1
    fi
fi

# Install additional iOS build tools
if ! is_step_completed "ios-tools"; then
    echo -e "${YELLOW}Installing additional iOS build tools...${NC}"
    brew install libimobiledevice ideviceinstaller ios-deploy 2>/dev/null || true
    log_step "ios-tools"
    echo -e "${GREEN}✓ iOS build tools installed${NC}"
else
    skip_step "iOS build tools"
fi

# ========== Step 6: Install Android SDK ==========
echo -e "\n${BLUE}[Step 6/7] Installing Android SDK...${NC}"

# Create Android SDK directory
mkdir -p "$ANDROID_HOME/cmdline-tools"

# Download and extract command-line tools
if is_step_completed "android-cmdtools"; then
    skip_step "Android cmdline-tools"
elif [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
    echo -e "${YELLOW}Downloading Android cmdline-tools...${NC}"
    curl -o /tmp/tools.zip "https://dl.google.com/android/repository/commandlinetools-mac-${CMDLINE_TOOLS_VERSION}_latest.zip"
    unzip -q /tmp/tools.zip -d "$ANDROID_HOME/cmdline-tools"
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
    rm /tmp/tools.zip
    log_step "android-cmdtools"
    echo -e "${GREEN}✓ Android cmdline-tools downloaded${NC}"
else
    echo -e "${GREEN}✓ Android cmdline-tools already installed${NC}"
    log_step "android-cmdtools"
fi

# Set Android environment variables
if ! grep -q "ANDROID_HOME" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Android SDK configuration" >> "$SHELL_RC"
    echo "export ANDROID_HOME=\"$ANDROID_HOME\"" >> "$SHELL_RC"
    echo "export ANDROID_SDK_ROOT=\"$ANDROID_HOME\"" >> "$SHELL_RC"
    echo "export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$PATH\"" >> "$SHELL_RC"
fi
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Install Android SDK packages
if ! is_step_completed "android-packages"; then
    echo -e "${YELLOW}Installing Android SDK packages (this may take a few minutes)...${NC}"
    yes | sdkmanager --licenses > /dev/null 2>&1 || true
    sdkmanager --update
    sdkmanager \
        "platform-tools" \
        "platforms;android-34" \
        "platforms;android-35" \
        "platforms;android-36" \
        "build-tools;35.0.0"
    
    log_step "android-packages"
    echo -e "${GREEN}✓ Android SDK packages installed${NC}"
else
    skip_step "Android SDK packages"
fi

# ========== Step 7: Install Flutter SDK ==========
echo -e "\n${BLUE}[Step 7/7] Installing Flutter SDK ${FLUTTER_VERSION}...${NC}"

if is_step_completed "flutter"; then
    skip_step "Flutter SDK ${FLUTTER_VERSION}"
else
    if [ -d "$FLUTTER_HOME" ]; then
        CURRENT_FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        if [ "$CURRENT_FLUTTER_VERSION" = "$FLUTTER_VERSION" ]; then
            echo -e "${GREEN}✓ Flutter ${FLUTTER_VERSION} already installed${NC}"
            log_step "flutter"
        else
            echo -e "${YELLOW}Flutter directory exists but version mismatch (${CURRENT_FLUTTER_VERSION} vs ${FLUTTER_VERSION}). Removing...${NC}"
            rm -rf "$FLUTTER_HOME"
        fi
    fi
    
    if [ ! -d "$FLUTTER_HOME" ]; then
        # Check if running on Apple Silicon
        ARCH=$(uname -m)
        if [[ "$ARCH" != "arm64" ]]; then
            echo -e "${RED}Error: This script only supports Apple Silicon (ARM64) Macs.${NC}"
            echo -e "${YELLOW}For Intel Macs, please use the official Flutter installation guide.${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Downloading Flutter ${FLUTTER_VERSION} for Apple Silicon (this may take a few minutes)...${NC}"
        FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"
        
        curl -L --retry 5 --retry-delay 3 "$FLUTTER_URL" -o /tmp/flutter.zip

        echo -e "${YELLOW}Extracting Flutter...${NC}"
        mkdir -p "$(dirname "$FLUTTER_HOME")"
        unzip -q /tmp/flutter.zip -d "$(dirname "$FLUTTER_HOME")"
        rm /tmp/flutter.zip
        
        log_step "flutter"
        echo -e "${GREEN}✓ Flutter ${FLUTTER_VERSION} installed${NC}"
    fi
fi

# Set Flutter environment variables
if ! grep -q "flutter/bin" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Flutter configuration" >> "$SHELL_RC"
    echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$SHELL_RC"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"

# Configure Flutter
if ! is_step_completed "flutter-config"; then
    echo -e "${YELLOW}Configuring Flutter...${NC}"
    flutter config --no-analytics
    yes | flutter doctor --android-licenses > /dev/null 2>&1 || true
    flutter precache --android
    flutter precache --ios
    log_step "flutter-config"
    echo -e "${GREEN}✓ Flutter configured${NC}"
else
    skip_step "Flutter configuration"
fi

# ========== Final Steps ==========
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Installation completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"

# Ensure rbenv is active to report correct versions
if command -v rbenv &>/dev/null; then
    init_rbenv
fi

echo -e "\n${YELLOW}Installed versions:${NC}"
echo -e "Xcode Command Line Tools: $(xcode-select -p 2>/dev/null || echo 'Not installed')"
if [ -d "/Applications/Xcode.app" ]; then
    echo -e "Xcode: $(xcodebuild -version 2>/dev/null | head -n 1 || echo 'Installed')"
fi
echo -e "Java: $(java -version 2>&1 | head -n 1)"
echo -e "Ruby: $(ruby --version)"
echo -e "CocoaPods: $(pod --version 2>/dev/null || echo 'Not installed')"
echo -e "Flutter: $(flutter --version | head -n 1)"
echo -e "Android SDK: $ANDROID_HOME"

echo -e "\n${YELLOW}iOS Development Notes:${NC}"
if [ ! -d "/Applications/Xcode.app" ]; then
    echo -e "${RED}⚠️  Xcode app is required for iOS development${NC}"
    echo -e "${YELLOW}   1. Install Xcode from the App Store (https://apps.apple.com/app/xcode/id497799835)${NC}"
    echo -e "${YELLOW}   2. Open Xcode and accept the license agreement${NC}"
    echo -e "${YELLOW}   3. Run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer${NC}"
    echo -e "${YELLOW}   4. Run: sudo xcodebuild -runFirstLaunch${NC}"
    echo -e "${YELLOW}   5. Run: flutter doctor -v${NC}"
else
    echo -e "${GREEN}✓ Xcode is installed${NC}"
    echo -e "${YELLOW}   To build for iOS devices, you'll need:${NC}"
    echo -e "${YELLOW}   - An Apple Developer account (free or paid)${NC}"
    echo -e "${YELLOW}   - Configure signing in Xcode for your project${NC}"
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${YELLOW}Lưu ý về biến môi trường...${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Để áp dụng biến môi trường mới vào terminal hiện tại của bạn, hãy chạy:${NC}"
echo -e "  ${GREEN}source $SHELL_RC${NC}"

# Run flutter doctor
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Running Flutter Doctor...${NC}"
echo -e "${BLUE}========================================${NC}\n"

flutter doctor -v

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}Environment setup complete! 🎉${NC}"
echo -e "${GREEN}You can now build for both Android and iOS!${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}To reset installation and start fresh:${NC}"
echo -e "${BLUE}rm $INSTALL_LOG${NC}"