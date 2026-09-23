import os
import subprocess
import shutil
import plistlib

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

# Check for provisioning profile
profile_path = None
for candidate in [
    os.path.join(repo_dir, 'embedded.mobileprovision'),
    os.path.join(repo_dir, 'FrameLab.mobileprovision'),
]:
    if os.path.exists(candidate):
        profile_path = candidate
        break

if not profile_path:
    # check for any .mobileprovision in repo root
    for f in os.listdir(repo_dir):
        if f.endswith('.mobileprovision'):
            profile_path = os.path.join(repo_dir, f)
            break

print("[6/6] Codesigning and packaging FrameLabIOS.ipa...")
if profile_path and os.path.exists(profile_path):
    print(f"  -> Found Provisioning Profile: {profile_path}")
    embedded_dest = os.path.join(payload_app, 'embedded.mobileprovision')
    shutil.copyfile(profile_path, embedded_dest)
    
    # Extract entitlements
    entitlements_xml = subprocess.run(['security', 'cms', '-D', '-i', profile_path], capture_output=True, text=True)
    if entitlements_xml.returncode == 0:
        try:
            plist_data = plistlib.loads(entitlements_xml.stdout.encode('utf-8'))
            entitlements = plist_data.get('Entitlements', {})
            ent_path = os.path.join(build_tmp, 'entitlements.plist')
            with open(ent_path, 'wb') as ef:
                plistlib.dump(entitlements, ef)
            
            # Find distribution identity
            res_id = subprocess.run(['security', 'find-identity', '-v', '-p', 'codesigning'], capture_output=True, text=True)
            cert_name = "Apple Distribution: Alok Rathaur (A54KS68ZGH)"
            if cert_name not in res_id.stdout:
                cert_name = "-"
            
            print(f"  -> Signing with: {cert_name}")
            subprocess.run(['codesign', '-f', '-s', cert_name, '--entitlements', ent_path, '--timestamp=none', payload_app], check=True)
        except Exception as e:
            print("  Warning parsing entitlements:", e)
            subprocess.run(['codesign', '-f', '-s', '-', '--timestamp=none', payload_app], check=True)
    else:
        subprocess.run(['codesign', '-f', '-s', '-', '--timestamp=none', payload_app], check=True)
else:
    print("  -> Notice: No .mobileprovision found in repository root.")
    print("  -> Signing ad-hoc for Sideloadly (Diawi requires embedded.mobileprovision).")
    subprocess.run(['codesign', '-f', '-s', '-', '--timestamp=none', payload_app], check=True)

ipa_path = os.path.join(dist_ios, 'FrameLabIOS.ipa')
if os.path.exists(ipa_path):
    os.remove(ipa_path)
subprocess.run(['zip', '-qr', 'FrameLabIOS.ipa', 'Payload'], cwd=dist_ios, check=True)

# Also copy to repo root
shutil.copyfile(ipa_path, os.path.join(repo_dir, 'FrameLabIOS.ipa'))

shutil.rmtree(build_tmp)

print(f"======================================================")
print(f" SUCCESS: IPA generated successfully!")
print(f" File: {ipa_path}")
print(f" Size: {os.path.getsize(ipa_path)} bytes")
if not profile_path:
    print(" TIP FOR DIAWI: Drop your downloaded 'embedded.mobileprovision'")
    print(" into the project root and run ./scripts/build_ipa.sh again.")
print(f"======================================================")
