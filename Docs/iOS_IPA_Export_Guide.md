# FrameLab iOS IPA Export & Device Testing Guide

This guide explains how to build, export, and install the **FrameLab iOS app (`.ipa`)** onto a physical iPhone.

---

## 1. Prerequisites

1. **Xcode**: Download Xcode (15 or 16) from the Mac App Store.
2. **Apple ID**: A free personal Apple ID is completely sufficient (paid developer account is optional).
3. **iPhone**: Running iOS 17.0 or later.
4. **Cable**: USB-C or Lightning cable to connect your iPhone to your Mac.

---

## 2. Fastest Method: Direct Install via Xcode (No .ipa file needed)

If your iPhone is connected to your Mac, Xcode can install and launch the app directly:

1. Connect your iPhone to your Mac.
2. Open `FrameLab.xcworkspace` (or `Package.swift`) in Xcode:
   ```bash
   open FrameLab.xcworkspace
   ```
3. In the Xcode top toolbar, click the device selector and choose your **connected iPhone**.
4. In Project Settings under **Signing & Capabilities**:
   - Check **"Automatically manage signing"**.
   - Select your **Personal Team** (your Apple ID).
   - Set a unique Bundle Identifier (e.g. `com.legendprixai.framelab`).
5. Press **Cmd + R (Run)**.
   - Xcode will compile `FrameLabCore` and the iOS SwiftUI app for ARM64, sign it with your personal certificate, install it on your iPhone, and launch it with live debugging!

---

## 3. How to Export a Standalone `.ipa` File (Via Xcode GUI)

If you need a standalone `.ipa` file to share or sideload via Sideloadly or AltStore:

### Step 1: Select Build Destination
In Xcode's top toolbar, click the run destination and select:
- Scheme: **FrameLabIOS**
- Destination: **Any iOS Device (arm64)**

### Step 2: Archive the App
- In the top menu bar, click **Product → Archive**.
- Xcode compiles an optimized Release build and automatically opens the **Organizer** window.

### Step 3: Distribute & Export
1. In the **Organizer** window, select your archive and click **Distribute App**.
2. Select **Custom** → **Development** (or **Ad-Hoc** / **Release Testing**).
3. Keep default settings:
   - *App Thinning*: None (universal) or select your iPhone model.
   - *Signing*: Automatically manage signing.
4. Click **Export** and choose an export destination on your disk (e.g., `dist/`).
5. Xcode generates a folder containing **`FrameLabIOS.ipa`**!

---

## 4. Automated CLI Export (`xcodebuild`)

Once full Xcode is installed, you can automate this via terminal:

### Step 1: Create `scripts/exportOptions.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

### Step 2: Run Archive & Export Command
```bash
# 1. Build xcarchive
xcodebuild archive \
  -workspace FrameLab.xcworkspace \
  -scheme FrameLabIOS \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath ./build/FrameLabIOS.xcarchive

# 2. Export .ipa
xcodebuild -exportArchive \
  -archivePath ./build/FrameLabIOS.xcarchive \
  -exportOptionsPlist ./scripts/exportOptions.plist \
  -exportPath ./dist/ios
```

The resulting file will be located at `./dist/ios/FrameLabIOS.ipa`.

---

## 5. How to Sideload & Install the `.ipa` on iPhone

Once you have the `.ipa` file, you can install it using any of the following tools:

### Option A: Apple Configurator (Official Apple Tool)
1. Install **Apple Configurator** from the Mac App Store.
2. Connect your iPhone via USB.
3. Drag and drop `FrameLabIOS.ipa` onto your device inside Apple Configurator.

### Option B: Sideloadly / AltStore (Most Popular for Sideloading)
1. Download [Sideloadly](https://sideloadly.io/) or [AltStore](https://altstore.io/).
2. Connect your iPhone and drag `FrameLabIOS.ipa` into Sideloadly.
3. Enter your Apple ID and click **Start**.
4. The tool automatically signs and installs the app onto your iPhone over USB or Wi-Fi.

---

## 6. Critical iPhone Settings (iOS 17+)

When running developer-installed apps on iOS 17+, you must enable two iOS security settings:

### 1. Enable Developer Mode (iOS 16+ Requirement)
- On your iPhone: Go to **Settings → Privacy & Security**.
- Scroll to the bottom and tap **Developer Mode**.
- Toggle it **ON**.
- Restart your iPhone when prompted, then tap **Turn On** and enter your passcode.

### 2. Trust Developer Profile (For Free Apple IDs)
- On your iPhone: Go to **Settings → General → VPN & Device Management**.
- Under *Developer App*, tap your Apple ID email.
- Tap **Trust "<Your Apple ID>"**.
- You can now launch **FrameLab** from your iPhone home screen!
