# DD Feature - Info.plist Requirements

## Required Privacy Permissions

Add these entries to your `Info.plist` file to support DD photo upload and location features:

### Camera Access
```xml
<key>NSCameraUsageDescription</key>
<string>DDRide needs camera access to take your profile photo for riders to identify you</string>
```

### Photo Library Access
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>DDRide needs photo library access to select your profile photo</string>
```

### Location (When In Use)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>DDRide needs your location to calculate accurate ETAs when you're en route to pick up riders</string>
```

## Complete Info.plist Entry

If starting fresh, add this section to your Info.plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- ... other entries ... -->

    <!-- Camera Permission -->
    <key>NSCameraUsageDescription</key>
    <string>DDRide needs camera access to take your profile photo for riders to identify you</string>

    <!-- Photo Library Permission -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>DDRide needs photo library access to select your profile photo</string>

    <!-- Location Permission (When In Use Only) -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>DDRide needs your location to calculate accurate ETAs when you're en route to pick up riders</string>

    <!-- ... other entries ... -->
</dict>
</plist>
```

## Important Notes

1. **Location Permission**: We only request "When In Use" permission, NOT "Always". This is battery-efficient and appropriate for our use case where we only capture location once when DD marks "en route".

2. **Camera Permission**: Only requested when user attempts to take a photo. If denied, they can still upload from photo library.

3. **Photo Library Permission**: Only requested when user attempts to select from library. If denied, they can still take a photo with camera.

4. **Graceful Fallback**: The app handles permission denials gracefully with user-friendly error messages directing them to Settings if needed.

## Testing Permission Flows

1. **First Launch**: User should see permission requests when they attempt to:
   - Take a photo (Camera permission)
   - Select from library (Photo Library permission)
   - Mark "On My Way" (Location permission)

2. **Permission Denied**: User should see helpful error messages explaining:
   - Why the permission is needed
   - How to enable it in Settings
   - Alternative options (e.g., use library if camera denied)

3. **Permission Revoked**: If user revokes permissions in Settings, app should detect and show appropriate error messages on next attempt.

## Xcode Configuration

To add these to your project:

1. Open your project in Xcode
2. Select your target
3. Go to "Info" tab
4. Right-click in the list and select "Add Row"
5. Add each key from above with its corresponding string value

Or edit Info.plist directly as XML.
