# MirrorChild Broadcast Extension Setup

This folder contains the files needed for implementing a Broadcast Extension in MirrorChild. The broadcast extension allows users to share their screen system-wide, even when the app is in the background.

## Setup Instructions in Xcode

Follow these steps to add the Broadcast Extension to your Xcode project:

1. **Create a new Broadcast Upload Extension target**:
   - In Xcode, go to File > New > Target...
   - Select "Broadcast Upload Extension" and click Next
   - Enter "MirrorChildBroadcast" as the Product Name
   - Set Language to Swift
   - Click Finish

2. **Add the extension files**:
   - Replace the generated SampleHandler.swift with the one in this folder
   - Add the Info.plist file to the extension target
   - Add the MirrorChildBroadcast.entitlements file to the extension target

3. **Set up App Groups**:
   - Select your main app target and go to the "Signing & Capabilities" tab
   - Click the "+" button and add "App Groups"
   - Add the app group: "group.com.mirrochild.screensharing"
   - Repeat the same for the broadcast extension target

4. **Update Bundle Identifier**:
   - In the BroadcastManager.swift file, update the `preferredExtension` value in `createBroadcastPickerView()` to match your extension's bundle identifier

5. **Build and Run**:
   - Build and run the app to test the broadcast functionality
   - Tap the screen sharing button to show the broadcast UI
   - Use the broadcast button to start/stop screen sharing

## How It Works

1. The main app creates a RPSystemBroadcastPickerView which shows the system broadcast UI
2. When user starts broadcasting, the system launches our extension
3. The extension captures screen content through ReplayKit and saves frame info to shared files
4. The main app monitors these files to update its UI based on broadcast status

## Troubleshooting

- If the broadcast button doesn't appear, check that the bundle identifier in BroadcastManager.swift matches your extension
- If communication between app and extension fails, verify that both targets have the same App Group
- Ensure both entitlements files are properly added to their respective targets 