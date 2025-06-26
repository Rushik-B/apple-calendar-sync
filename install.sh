#!/bin/bash

# Google Calendar to Apple Calendar Sync - Installation Script

echo "🚀 Installing Google Calendar to Apple Calendar Sync..."

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed. Please install Xcode or Xcode Command Line Tools."
    echo "Run: xcode-select --install"
    exit 1
fi

# Build the project
echo "📦 Building the project..."
if ! swift build -c release; then
    echo "❌ Build failed. Please check the error messages above."
    exit 1
fi

# Create the installation directory if it doesn't exist
echo "📁 Creating installation directory..."
sudo mkdir -p /usr/local/bin

# Copy the executable
echo "📋 Installing executable..."
sudo cp .build/release/gcal-sync /usr/local/bin/

# Make it executable (should already be, but just in case)
sudo chmod +x /usr/local/bin/gcal-sync

# Verify installation
if command -v gcal-sync &> /dev/null; then
    echo "✅ Installation successful!"
    echo ""
    echo "You can now use 'gcal-sync' from anywhere in your terminal."
    echo ""
    echo "Next steps:"
    echo "1. Run 'gcal-sync setup' to configure Google API credentials"
    echo "2. Run 'gcal-sync sync' to perform your first sync"
    echo "3. See README.md for setting up automatic syncing"
else
    echo "❌ Installation failed. The executable was not found in PATH."
    exit 1
fi 