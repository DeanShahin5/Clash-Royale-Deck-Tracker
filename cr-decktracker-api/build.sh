#!/usr/bin/env bash
# Render.com Build Script
# This script runs during the build phase on Render

set -o errexit  # Exit on error

echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

echo "✅ Build completed successfully!"
