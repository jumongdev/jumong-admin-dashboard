#!/bin/bash

# 1. Download Flutter
git clone https://github.com/flutter/flutter.git -b stable

# 2. Add Flutter to the path
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Enable web
flutter config --enable-web

# 4. Get packages
flutter pub get

# 5. Build
flutter build web --release