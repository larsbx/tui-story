#!/bin/bash
set -e

echo "Setting up Semantic Relationship Graph TUI..."

# Check if Zig is already installed
if command -v zig &> /dev/null; then
    echo "Zig is already installed: $(zig version)"
else
    echo "Installing Zig 0.13.0..."

    # Detect OS
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "${OS}" in
        Linux*)
            if [ "${ARCH}" = "x86_64" ]; then
                ZIG_URL="https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz"
                ZIG_DIR="zig-linux-x86_64-0.13.0"
            else
                echo "Unsupported architecture: ${ARCH}"
                exit 1
            fi
            ;;
        Darwin*)
            if [ "${ARCH}" = "arm64" ]; then
                ZIG_URL="https://ziglang.org/download/0.13.0/zig-macos-aarch64-0.13.0.tar.xz"
                ZIG_DIR="zig-macos-aarch64-0.13.0"
            elif [ "${ARCH}" = "x86_64" ]; then
                ZIG_URL="https://ziglang.org/download/0.13.0/zig-macos-x86_64-0.13.0.tar.xz"
                ZIG_DIR="zig-macos-x86_64-0.13.0"
            else
                echo "Unsupported architecture: ${ARCH}"
                exit 1
            fi
            ;;
        *)
            echo "Unsupported OS: ${OS}"
            exit 1
            ;;
    esac

    # Download and extract Zig
    wget -q "${ZIG_URL}" -O zig.tar.xz
    tar -xf zig.tar.xz
    rm zig.tar.xz

    # Add to PATH for this session
    export PATH="$PWD/${ZIG_DIR}:$PATH"

    echo "Zig installed successfully!"
    echo "To make this permanent, add the following to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"$PWD/${ZIG_DIR}:\$PATH\""
fi

echo ""
echo "Building the application..."
zig build

echo ""
echo "Setup complete!"
echo ""
echo "To run the application:"
echo "  zig build run"
echo ""
echo "Optional: Set ANTHROPIC_API_KEY for real LLM analysis:"
echo "  export ANTHROPIC_API_KEY='your-api-key'"
echo "  zig build run"
