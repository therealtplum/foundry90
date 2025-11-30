# Foundry90 Client Applications

This directory contains client applications for the Foundry90 Markets Hub platform.

## Applications

### FMHubControl (macOS)
Desktop application for macOS built with SwiftUI. Designed for larger screens and desktop workflows.

**Location**: `FMHubControl/`

**Key Features**:
- System health monitoring
- Operations management
- Markets hub with advanced widgets
- Desktop-optimized UI

### F90Mobile (iOS)
Mobile application for iPhone built with SwiftUI. Designed specifically for iPhone form factors and touch interactions.

**Location**: `F90Mobile/`

**Key Features**:
- Markets browsing and search
- Account management
- Position tracking
- iPhone-optimized navigation and UI

## Shared Components

### F90Shared (Swift Package)
Shared Swift package containing common business logic, models, and services used by both macOS and iOS applications.

**Location**: `F90Shared/`

**Contents**:
- `KalshiModels.swift`: Data models for markets, accounts, positions, credentials
- `KalshiService.swift`: API service layer for backend communication

**Usage**: Both FMHubControl and F90Mobile depend on this package to share core functionality while maintaining platform-specific UI implementations.

## Architecture

```
clients/
├── FMHubControl/          # macOS application
│   └── FMHubControl/
│       └── [macOS-specific views and components]
├── F90Mobile/            # iOS application
│   └── F90Mobile/
│       └── [iOS-specific views and components]
└── F90Shared/            # Shared Swift package
    └── Sources/
        └── F90Shared/
            ├── KalshiModels.swift
            └── KalshiService.swift
```

## Design Principles

1. **Platform Separation**: Each platform (macOS/iOS) has its own application with platform-optimized UI
2. **Shared Business Logic**: Common models and services are shared through the F90Shared package
3. **Clear Boundaries**: Platform-specific code is clearly separated while sharing where it makes sense for scale

## Setup

Each application should be opened in Xcode and configured to use the F90Shared package as a local dependency.

