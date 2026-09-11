#!/bin/bash
set -e

echo "=== Setting up Flutter SDK on Vercel ==="
if [ ! -d "$HOME/flutter" ]; then
  echo "Cloning Flutter stable branch..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
else
  echo "Flutter SDK cache found."
fi

export PATH="$PATH:$HOME/flutter/bin"

echo "=== Flutter Environment ==="
flutter --version

echo "=== Resolving Dependencies ==="
flutter pub get

echo "=== Building Flutter Web Release Bundle ==="
flutter build web --release --base-href /

echo "=== Build Completed Successfully! Output in build/web ==="
