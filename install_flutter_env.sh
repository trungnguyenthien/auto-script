#!/bin/bash

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FLUTTER_VERSION="3.38.2"
CMDLINE_TOOLS_VERSION="11076708"
ANDROID_HOME="$HOME/Library/Android/sdk"
FLUTTER_HOME="$HOME/flutter"
INSTALL_LOG="$HOME/.flutter_env_install.log"
SHELL_RC="$HOME/.zshrc"

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
echo -e "  • Ruby (via Homebrew) - Latest stable version"
echo -e "  • CocoaPods 1.16.2+ (via Homebrew) - iOS dependency manager"
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

if is_step_completed "java17"; then
    skip_step "Java 17"
elif ! brew list openjdk@17 &> /dev/null; then
    brew install openjdk@17
    
    # Create symlink
    sudo ln -sfn $(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
    
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

# ========== Step 4: Install Ruby via Homebrew ==========
echo -e "\n${BLUE}[Step 4/7] Installing Ruby via Homebrew...${NC}"

if is_step_completed "ruby"; then
    skip_step "Ruby"
else
    # Check if Homebrew Ruby is installed
    if ! brew list ruby &> /dev/null; then
        echo -e "${YELLOW}Installing Ruby via Homebrew...${NC}"
        brew install ruby
    else
        echo -e "${GREEN}✓ Ruby already installed via Homebrew${NC}"
    fi
    
    # Add Ruby to PATH
    if [[ $(uname -m) == 'arm64' ]]; then
        RUBY_PATH="/opt/homebrew/opt/ruby/bin"
        GEM_PATH="/opt/homebrew/lib/ruby/gems"
    else
        RUBY_PATH="/usr/local/opt/ruby/bin"
        GEM_PATH="/usr/local/lib/ruby/gems"
    fi
    
    if ! grep -q "# Ruby configuration" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Ruby configuration" >> "$SHELL_RC"
        echo "export PATH=\"$RUBY_PATH:\$PATH\"" >> "$SHELL_RC"
        echo "export LDFLAGS=\"-L$(brew --prefix ruby)/lib\"" >> "$SHELL_RC"
        echo "export CPPFLAGS=\"-I$(brew --prefix ruby)/include\"" >> "$SHELL_RC"
    fi
    export PATH="$RUBY_PATH:$PATH"
    
    log_step "ruby"
    echo -e "${GREEN}✓ Ruby installed${NC}"
fi

# ========== Step 5: Install CocoaPods via Homebrew ==========
echo -e "\n${BLUE}[Step 5/7] Installing CocoaPods via Homebrew...${NC}"

if is_step_completed "cocoapods"; then
    skip_step "CocoaPods"
else
    # Install CocoaPods via Homebrew
    if ! brew list cocoapods &> /dev/null; then
        echo -e "${YELLOW}Installing CocoaPods via Homebrew...${NC}"
        brew install cocoapods
    else
        echo -e "${GREEN}✓ CocoaPods already installed via Homebrew${NC}"
    fi
    
    # Verify pod is available
    if command -v pod &> /dev/null; then
        POD_VERSION=$(pod --version)
        log_step "cocoapods"
        echo -e "${GREEN}✓ CocoaPods installed (version: ${POD_VERSION})${NC}"
        
        # Setup CocoaPods
        if ! is_step_completed "cocoapods-setup"; then
            echo -e "${YELLOW}Setting up CocoaPods (this may take a few minutes)...${NC}"
            pod setup --verbose
            log_step "cocoapods-setup"
        fi
    else
        echo -e "${YELLOW}⚠️  CocoaPods installed but not in PATH yet${NC}"
        echo -e "${YELLOW}⚠️  It will be available after you restart terminal or run: source $SHELL_RC${NC}"
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
        unzip -q /tmp/flutter.zip -d "$HOME"
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
echo -e "${YELLOW}Loading environment variables...${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Source the shell configuration file
source "$SHELL_RC"

echo -e "${GREEN}✓ Environment variables loaded${NC}\n"

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