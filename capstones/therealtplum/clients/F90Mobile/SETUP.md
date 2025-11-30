# F90Mobile Setup Guide

## Creating the Xcode Project

Since this is a new iOS project, you'll need to create an Xcode project. Here's how:

1. **Open Xcode** and select "Create a new Xcode project"

2. **Choose iOS → App** and click Next

3. **Configure the project**:
   - Product Name: `F90Mobile`
   - Team: Select your development team
   - Organization Identifier: `com.foundry90` (or your preferred identifier)
   - Interface: SwiftUI
   - Language: Swift
   - Storage: None (we'll use UserDefaults for now)
   - Include Tests: Optional

4. **Save location**: Navigate to `capstones/therealtplum/clients/F90Mobile/` and save

5. **Replace default files**:
   - Replace the auto-generated `F90MobileApp.swift` with the one in this directory
   - Delete the default `ContentView.swift` (we use `MainTabView.swift` instead)
   - Add all files from the `F90Mobile/` directory to the project

6. **Add F90Shared Package**:
   - In Xcode, go to File → Add Package Dependencies
   - Click "Add Local..." 
   - Navigate to `capstones/therealtplum/clients/F90Shared/`
   - Select the Package.swift file
   - Add the package to your target

7. **Configure Build Settings**:
   - Set iOS Deployment Target to 17.0 or higher
   - Ensure Swift Language Version is 5.9 or higher

8. **Add Assets**:
   - The `Assets.xcassets` folder is already set up
   - Add app icons as needed

9. **Build and Run**:
   - Select an iPhone simulator or device
   - Build (⌘B) and Run (⌘R)

## Project Structure in Xcode

Your Xcode project should have this structure:

```
F90Mobile
├── F90MobileApp.swift
├── MainTabView.swift
├── Views/
│   ├── MarketsListView.swift
│   ├── MarketDetailView.swift
│   ├── AccountView.swift
│   └── SettingsView.swift
├── Assets.xcassets/
└── Info.plist
```

## Dependencies

- **F90Shared**: Local Swift package (must be added as dependency)
  - Path: `../F90Shared/`

## Configuration

The app connects to the backend API at `http://127.0.0.1:3000` by default. For device testing, you may need to update the base URL in `KalshiService` to use your local network IP address.

## Troubleshooting

### Package Not Found
- Ensure F90Shared package is added as a local dependency
- Check that Package.swift in F90Shared is valid
- Clean build folder (⌘⇧K) and rebuild

### Build Errors
- Verify iOS Deployment Target is 17.0+
- Check that all Swift files are added to the target
- Ensure F90Shared package builds successfully

### Runtime Issues
- Verify backend API is running at the configured URL
- Check network permissions in Info.plist if needed
- Review console logs for API errors

