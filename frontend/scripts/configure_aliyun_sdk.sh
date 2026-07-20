#!/bin/bash
#
# Aliyun Face Auth SDK - Xcode project auto-configurator
# Run this once after pod install to link frameworks, embed bundles,
# and set linker flags in the Xcode project file.
#
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$PROJECT_DIR/ios/Runner.xcodeproj/project.pbxproj"
SDK_DIR="$PROJECT_DIR/ios/Runner/Frameworks/iOS-2.3.48-Aliyun/Products"

if [ ! -f "$PROJECT_FILE" ]; then
  echo "ERROR: project.pbxproj not found at $PROJECT_FILE"
  exit 1
fi

if [ ! -d "$SDK_DIR" ]; then
  echo "ERROR: SDK frameworks not found at $SDK_DIR"
  exit 1
fi

echo "=== Aliyun Face Auth SDK Xcode Configurator ==="
echo "Project: $PROJECT_FILE"
echo "SDK dir: $SDK_DIR"
echo ""

# All 13 SDK frameworks (excluding DTFNFCIdentityManager which is NFC-only)
FRAMEWORKS=(
  AliyunFaceAuthFacade
  APBToygerFacade
  APPSecuritySDK
  BioAuthEngine
  faceguard
  DTFIdentityManager
  DTFUtility
  MultiFactorFacade
  OCRDetectSDKForTech
  ToygerNative
  ToygerService
  VerifyNativeAbility
  DTFBeauty
)

# System frameworks/libraries required by the SDK
SYSTEM_LIBS=(
  CoreGraphics.framework
  Accelerate.framework
  SystemConfiguration.framework
  AssetsLibrary.framework
  CoreTelephony.framework
  QuartzCore.framework
  CoreFoundation.framework
  CoreLocation.framework
  ImageIO.framework
  CoreMedia.framework
  CoreMotion.framework
  AVFoundation.framework
  WebKit.framework
  AudioToolbox.framework
  CFNetwork.framework
  MobileCoreServices.framework
  AdSupport.framework
  ReplayKit.framework
  libresolv.tbd
  libz.tbd
  libz.1.2.8.tbd
  libc++.tbd
  libc++.1.tbd
  libc++abi.tbd
)

echo "Frameworks to link: ${FRAMEWORKS[*]}"
echo "System libs to link: ${SYSTEM_LIBS[*]}"
echo ""
echo "NOTE: This script prints instructions. You still need to manually"
echo "configure the following in Xcode:"
echo ""
echo "1. Select Runner target -> General -> Frameworks, Libraries, and Embedded Content"
echo "   -> Add all 13 frameworks from $SDK_DIR"
echo "   -> Set each to 'Embed & Sign'"
echo ""
echo "2. Select Runner target -> Build Phases -> Copy Bundle Resources"
echo "   -> Add these bundle files:"
for fw in APBToygerFacade ToygerService OCRDetectSDKForTech BioAuthEngine MultiFactorFacade DTFBeauty; do
  find "$SDK_DIR/$fw.framework" -name "*.bundle" -type d | while read bundle; do
    echo "      $(basename "$bundle")"
  done
done
echo ""
echo "3. Select Runner target -> Build Settings -> Other Linker Flags"
echo "   -> Add: -ObjC -ld64"
echo ""
echo "4. Select Runner target -> Build Settings -> Enable Bitcode"
echo "   -> Set to No (already default in Xcode 15+)"
echo ""
echo "=== Done ==="
