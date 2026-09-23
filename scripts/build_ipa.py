import os
import subprocess
import shutil

repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sdk_path = '/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk'
if not os.path.exists(sdk_path):
    res = subprocess.run(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], capture_output=True, text=True)
    sdk_path = res.stdout.strip()

print(f"======================================================")
print(f"         FrameLab iOS IPA Build & Packaging           ")
print(f"======================================================")
print(f"[1/6] Using iOS SDK: {sdk_path}")

build_tmp = '/tmp/framelab_ios_packaging'
dist_ios = os.path.join(repo_dir, 'dist', 'ios')
payload_app = os.path.join(dist_ios, 'Payload', 'FrameLabIOS.app')

if os.path.exists(build_tmp):
    shutil.rmtree(build_tmp)
os.makedirs(build_tmp)

if os.path.exists(dist_ios):
    shutil.rmtree(dist_ios)
os.makedirs(payload_app)

print("[2/6] Compiling C and Objective-C modules (arm64)...")
c_o = os.path.join(build_tmp, 'FrameLabC.o')
subprocess.run([
    'clang', '-target', 'arm64-apple-ios17.0',
    '-isysroot', sdk_path,
    '-I' + os.path.join(repo_dir, 'C/FrameLabC/include'),
    '-c', os.path.join(repo_dir, 'C/FrameLabC/FrameLabC.c'),
    '-o', c_o
], check=True)

objc_o = os.path.join(build_tmp, 'FrameLabObjC.o')
subprocess.run([
    'clang', '-target', 'arm64-apple-ios17.0',
    '-isysroot', sdk_path,
    '-fobjc-arc',
    '-I' + os.path.join(repo_dir, 'C/FrameLabC/include'),
    '-I' + os.path.join(repo_dir, 'ObjectiveC/FrameLabObjC/include'),
    '-c', os.path.join(repo_dir, 'ObjectiveC/FrameLabObjC/FrameLabObjC.m'),
    '-o', objc_o
], check=True)

print("[3/6] Compiling FrameLabCore Swift module...")
core_swift = []
for root, dirs, files in os.walk(os.path.join(repo_dir, 'Packages/FrameLabCore/Sources/FrameLabCore')):
    for f in files:
        if f.endswith('.swift'):
            core_swift.append(os.path.join(root, f))

lib_core = os.path.join(build_tmp, 'libFrameLabCore.a')
subprocess.run([
    'swiftc', '-target', 'arm64-apple-ios17.0',
    '-sdk', sdk_path,
    '-module-name', 'FrameLabCore',
    '-emit-module',
    '-emit-module-path', os.path.join(build_tmp, 'FrameLabCore.swiftmodule'),
    '-emit-library', '-static',
    '-I' + os.path.join(repo_dir, 'C/FrameLabC/include'),
    '-I' + os.path.join(repo_dir, 'ObjectiveC/FrameLabObjC/include'),
    c_o, objc_o,
    '-o', lib_core
] + core_swift, check=True)

print("[4/6] Compiling FrameLabIOS application binary...")
ios_swift = []
for root, dirs, files in os.walk(os.path.join(repo_dir, 'Apps/FrameLabIOS')):
    for f in files:
        if f.endswith('.swift'):
            ios_swift.append(os.path.join(root, f))

app_bin = os.path.join(payload_app, 'FrameLabIOS')
subprocess.run([
    'swiftc', '-target', 'arm64-apple-ios17.0',
    '-sdk', sdk_path,
    '-I' + build_tmp,
    '-I' + os.path.join(repo_dir, 'C/FrameLabC/include'),
    '-I' + os.path.join(repo_dir, 'ObjectiveC/FrameLabObjC/include'),
    '-L' + build_tmp,
    '-lFrameLabCore',
    '-parse-as-library',
    '-o', app_bin
] + ios_swift, check=True)

print("[5/6] Creating Info.plist and extracting retina app icons...")
info_plist = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>FrameLab</string>
    <key>CFBundleExecutable</key>
    <string>FrameLabIOS</string>
    <key>CFBundleIdentifier</key>
    <string>com.alok.framelab</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>FrameLab</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>MinimumOSVersion</key>
    <string>17.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>FrameLab needs access to your photo library to inspect and process local videos.</string>
</dict>
</plist>"""

with open(os.path.join(payload_app, 'Info.plist'), 'w') as f:
    f.write(info_plist)

with open(os.path.join(payload_app, 'PkgInfo'), 'w') as f:
    f.write('APPL????')

icon_src = os.path.join(repo_dir, 'AppIcon.icns')
iconset = os.path.join(build_tmp, 'icons.iconset')
subprocess.run(['iconutil', '-c', 'iconset', icon_src, '-o', iconset], check=True)
base_png = os.path.join(iconset, 'icon_512x512.png')

for size, name in [
    (120, 'AppIcon60x60@2x.png'),
    (180, 'AppIcon60x60@3x.png'),
    (152, 'AppIcon76x76@2x~ipad.png'),
    (167, 'AppIcon83.5x83.5@2x~ipad.png'),
    (1024, 'AppIcon1024x1024.png')
]:
    subprocess.run(['sips', '-z', str(size), str(size), base_png, '--out', os.path.join(payload_app, name)], capture_output=True)

print("[6/6] Codesigning ad-hoc and packaging FrameLabIOS.ipa...")
subprocess.run(['codesign', '-f', '-s', '-', '--timestamp=none', payload_app], check=True)

ipa_path = os.path.join(dist_ios, 'FrameLabIOS.ipa')
if os.path.exists(ipa_path):
    os.remove(ipa_path)
subprocess.run(['zip', '-qr', 'FrameLabIOS.ipa', 'Payload'], cwd=dist_ios, check=True)

shutil.rmtree(build_tmp)

print(f"======================================================")
print(f" SUCCESS: IPA generated successfully!")
print(f" File: {ipa_path}")
print(f" Size: {os.path.getsize(ipa_path)} bytes")
print(f"======================================================")
