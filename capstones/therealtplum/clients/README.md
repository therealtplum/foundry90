# Clients Directory - Standardized Structure

## Overview

The clients directory has been reorganized with standardized naming conventions based on function and target, grouped by function. All shared code and assets are now accessible by both macOS and iOS applications.

## Directory Structure

```
clients/
├── apps/                          # Platform-specific applications (grouped by function)
│   ├── macos-f90hub/              # macOS application (target: macOS, function: F90 Hub)
│   │   ├── F90Hub/                # App source code
│   │   │   ├── views/             # SwiftUI views
│   │   │   │   ├── F90HubApp.swift
│   │   │   │   ├── RootView.swift
│   │   │   │   ├── SystemHealthView.swift
│   │   │   │   ├── OperationsView.swift
│   │   │   │   └── ...
│   │   │   ├── viewmodels/        # View models (MVVM pattern)
│   │   │   │   ├── SystemHealthViewModel.swift
│   │   │   │   ├── MarketStatusViewModel.swift
│   │   │   │   └── ...
│   │   │   ├── widgets/           # Reusable widget components
│   │   │   │   ├── BaseWidgetView.swift
│   │   │   │   ├── MarketStatusWidget.swift
│   │   │   │   └── ...
│   │   │   └── Assets.xcassets/   # App assets
│   │   └── F90Hub.xcodeproj/      # Xcode project
│   └── ios-f90mobile/              # iOS application (target: iOS, function: F90 Mobile)
│       └── F90Mobile/             # App source code (to be populated)
└── shared/                        # Shared code and assets (accessible by both apps)
    ├── Package.swift              # Swift Package Manager manifest
    ├── Sources/
    │   └── F90Shared/             # Shared Swift code
    │       ├── KalshiService.swift
    │       ├── KalshiModels.swift
    │       ├── FredService.swift
    │       ├── FredModels.swift
    │       ├── SystemHealthService.swift
    │       ├── SystemHealthModel.swift
    │       ├── MarketStatusService.swift
    │       ├── MarketStatusModel.swift
    │       └── ThemeManager.swift
    └── Resources/                 # Shared assets
        ├── F90_logo.png
        ├── F90_logo_small.png
        ├── F90_logo_tiny.png
        └── F90_logo.svg
```

## Naming Conventions

### Applications
- **Format**: `{platform}-{function}`
- **Examples**:
  - `macos-f90hub` - macOS F90 Hub application
  - `ios-f90mobile` - iOS F90 Mobile application

### App Code Organization
- **Views**: All SwiftUI views in `views/` directory
- **ViewModels**: All view models in `viewmodels/` directory
- **Widgets**: Reusable widget components in `widgets/` directory
- **Naming**: `{Feature}View.swift`, `{Feature}ViewModel.swift`, `{Feature}Widget.swift`

### Shared Code
- **Package name**: `F90Shared`
- **All types are public**: Services, models, and UI components are marked `public` for cross-module access
- **Swift Package Manager**: Shared code is packaged for easy integration

## Current Status

### ✅ Completed
- Directory structure standardized and organized
- All shared code moved to `shared/Sources/F90Shared/` Swift package
- All app code organized into `views/`, `viewmodels/`, and `widgets/` directories
- App renamed from `FMHubControl` to `F90Hub`
- Xcode project updated with correct references
- Package dependency configured and linked
- All types made public for cross-module access
- Deployment target set to macOS 14.0+
- Old directories and files cleaned up

### Package Configuration
- **macOS**: 14.0+
- **iOS**: 16.0+
- **All types public**: Services, models, and UI components are accessible from apps

## Usage

### In App Code
All app files that use shared code should import the package:

```swift
import F90Shared
```

### Available Shared Types

**Services:**
- `KalshiService`, `KalshiServiceType`
- `FredService`, `FredServiceType`
- `SystemHealthService`, `SystemHealthServiceType`
- `MarketStatusService`, `MarketStatusServiceType`

**Models:**
- `KalshiMarketSummary`, `KalshiMarketDetail`, `KalshiUserAccount`, `KalshiUserBalance`, `KalshiPosition`
- `EconomicRelease`
- `SystemHealth`, `WebHealth`, `RegressionTestResults`
- `MarketStatus`, `MarketOpenTimeCalculator`

**UI Components:**
- `ThemeManager`
- `AppTheme`

## Building

### Shared Package
```bash
cd clients/shared
swift build
```

### macOS App
1. Open `apps/macos-f90hub/F90Hub.xcodeproj` in Xcode
2. Ensure package dependency is resolved (File → Packages → Resolve Package Versions)
3. Build: `Cmd+B`
4. Run: `Cmd+R`

## Notes

- **No functionality changed**: All code reorganization maintains existing functionality
- **Shared code accessible**: Both macOS and iOS apps can use the same shared code
- **Standardized naming**: All directories follow consistent naming patterns
- **Swift Package Manager**: Shared code is packaged for easy integration
- **Assets shared**: Logo files and other assets are available to both platforms

## Troubleshooting

If you encounter issues:

1. **Package not found**: 
   - File → Packages → Resolve Package Versions
   - Verify `clients/shared/` path is correct in Xcode project settings

2. **Types not accessible**:
   - Ensure `import F90Shared` is present
   - Verify the package builds: `cd clients/shared && swift build`

3. **Build errors**:
   - Clean build folder: `Shift+Cmd+K`
   - Restart Xcode if package resolution issues persist

4. **Missing destinations**:
   - Verify deployment target matches your system (macOS 14.0+)
   - Check Xcode → Settings → Platforms for installed SDKs
