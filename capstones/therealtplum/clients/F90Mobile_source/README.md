# F90Mobile

iOS application for Foundry90 Markets Hub - iPhone-focused mobile client.

## Overview

F90Mobile is a native iOS application built with SwiftUI, designed specifically for iPhone devices. It provides a mobile interface for viewing markets, managing account information, and interacting with the Kalshi trading platform.

## Architecture

- **Shared Package**: Uses `F90Shared` Swift package for common models and services
- **SwiftUI**: Modern declarative UI framework
- **iPhone-Optimized**: Designed specifically for iPhone form factors and interaction patterns

## Key Features

### Markets
- Browse and search markets
- View market details with real-time pricing
- Pull-to-refresh functionality
- Category filtering

### Account
- View account balance and available funds
- Monitor open positions
- Real-time P&L tracking
- Secure credential management

### Settings
- User authentication
- API configuration
- App information

## Project Structure

```
F90Mobile/
├── F90Mobile/
│   ├── F90MobileApp.swift      # App entry point
│   ├── MainTabView.swift        # Main navigation
│   └── Views/
│       ├── MarketsListView.swift
│       ├── MarketDetailView.swift
│       ├── AccountView.swift
│       └── SettingsView.swift
└── README.md
```

## Dependencies

- **F90Shared**: Local Swift package containing shared models and services
  - KalshiModels: Data models for markets, accounts, positions
  - KalshiService: API service layer

## Setup

1. Open the project in Xcode
2. Add the `F90Shared` package as a local dependency:
   - File → Add Package Dependencies
   - Select the `F90Shared` package directory
3. Build and run on an iPhone simulator or device

## Configuration

The app connects to the backend API at `http://127.0.0.1:3000` by default. This can be configured in the `KalshiService` initialization.

## Differences from macOS App

- **Platform-Specific UI**: Optimized for iPhone touch interactions and smaller screens
- **Navigation**: Uses TabView instead of macOS-specific navigation patterns
- **Layout**: Vertical scrolling layouts optimized for portrait orientation
- **Separate Codebase**: Maintains clear separation from FMHubControl while sharing core business logic through F90Shared

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

