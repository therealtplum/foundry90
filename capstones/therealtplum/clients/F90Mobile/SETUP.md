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

4. **Save location** (Important - follow these steps carefully):
   - **If you see "A folder named 'F90Mobile' already exists" warning:**
     - Click **Cancel** on the dialog
     - In Terminal, temporarily rename the existing folder:
       ```bash
       cd capstones/therealtplum/clients/
       mv F90Mobile F90Mobile_source
       ```
     - Then in Xcode, navigate to `clients/` directory and save the project
     - Xcode will create `F90Mobile.xcodeproj` and a new `F90Mobile/` folder
     - After project creation, we'll move your source files into place (see step 5)
   - **If no warning appears:**
     - Navigate to `capstones/therealtplum/clients/` and save the project there
     - The project file will be created at: `clients/F90Mobile.xcodeproj`

5. **Add existing source files**:
   - **If you renamed the folder in step 4:**
     - In Terminal, copy your source files into Xcode's new F90Mobile directory:
       ```bash
       cd capstones/therealtplum/clients/
       cp F90Mobile_source/F90Mobile/F90MobileApp.swift F90Mobile/F90Mobile/
       cp F90Mobile_source/F90Mobile/MainTabView.swift F90Mobile/F90Mobile/
       cp -R F90Mobile_source/F90Mobile/Views F90Mobile/F90Mobile/
       cp -R F90Mobile_source/F90Mobile/Assets.xcassets F90Mobile/F90Mobile/
       cp F90Mobile_source/F90Mobile/Info.plist F90Mobile/F90Mobile/
       rm F90Mobile/F90Mobile/ContentView.swift  # Remove Xcode's default file
       ```
     - Then in Xcode, the files should appear automatically (if using file system synchronization)
     - Or manually add them: Right-click on `F90Mobile` group → "Add Files to F90Mobile..." → Select the files
   - **If you didn't rename the folder:**
     - In Xcode's project navigator, delete the auto-generated `ContentView.swift`
     - Right-click on the `F90Mobile` group → "Add Files to F90Mobile..."
     - Navigate to `clients/F90Mobile/F90Mobile/` and select:
       - `F90MobileApp.swift`
       - `MainTabView.swift`
       - `Views/` folder
       - `Assets.xcassets/` folder
       - `Info.plist`
     - **Important**: Make sure "Copy items if needed" is **unchecked**
     - Make sure "Create groups" is selected
     - Make sure "Add to targets: F90Mobile" is **checked**
     - Click "Add"

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

### Duplicate Info.plist Error
**Error**: "Multiple commands produce Info.plist" or "Copy Bundle Resources contains Info.plist"

**Solution**:
1. In Xcode, select the **F90Mobile** project → **F90Mobile** target → **Build Phases** tab
2. Expand **Copy Bundle Resources**
3. Find **Info.plist** in the list and **delete it** (select and press Delete)
4. Info.plist should only be referenced via `INFOPLIST_FILE` build setting, not copied as a resource
5. Clean build folder (⌘⇧K) and rebuild

### Package Not Found
**Error**: "Unable to find module dependency: 'F90Shared'"

**Solution**:
1. In Xcode, select the **F90Mobile** project → **F90Mobile** target
2. Go to **Package Dependencies** tab (or **General** → **Frameworks, Libraries, and Embedded Content**)
3. Click **+** button → **Add Local...**
4. Navigate to `clients/F90Shared/` and select the folder
5. Click **Add Package** and ensure it's added to the **F90Mobile** target
6. Clean build folder (⌘⇧K) and rebuild

### Optional Chaining Error on displayName
**Error**: "Cannot use optional chaining on non-optional value of type 'String'"

**Solution**: The `displayName` property in `KalshiMarketSummary` is non-optional. Use:
```swift
market.displayName.localizedCaseInsensitiveContains(searchText)
```
Not:
```swift
market.displayName?.localizedCaseInsensitiveContains(searchText) ?? false
```

### Build Errors
- Verify iOS Deployment Target is 17.0+
- Check that all Swift files are added to the target
- Ensure F90Shared package builds successfully
- Clean build folder (⌘⇧K) if issues persist

### Runtime Issues
- Verify backend API is running at the configured URL
- Check network permissions in Info.plist if needed
- Review console logs for API errors

