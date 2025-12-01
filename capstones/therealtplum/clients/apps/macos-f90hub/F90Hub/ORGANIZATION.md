# F90Hub App Organization

## Directory Structure

```
F90Hub/
├── views/                    # All SwiftUI views
│   ├── F90HubApp.swift      # App entry point
│   ├── RootView.swift
│   ├── SystemHealthView.swift
│   ├── OperationsView.swift
│   ├── MarketsHubView.swift
│   ├── MarketsHubOverviewView.swift
│   ├── MarketsPlaceholderView.swift
│   ├── KalshiAccountView.swift
│   ├── KalshiLoginView.swift
│   ├── KalshiMarketsView.swift
│   └── BlackProgressView.swift
├── viewmodels/              # All view models (MVVM pattern)
│   ├── SystemHealthViewModel.swift
│   ├── MarketStatusViewModel.swift
│   ├── OperationsViewModel.swift
│   ├── KalshiAccountViewModel.swift
│   ├── KalshiLoginViewModel.swift
│   └── KalshiMarketsViewModel.swift
├── widgets/                 # Reusable widget components
│   ├── BaseWidgetView.swift
│   ├── MarketStatusWidget.swift
│   ├── FredReleasesWidget.swift
│   └── AccountBalancesWidget.swift
└── Assets.xcassets/         # App assets
```

## Naming Conventions

### Views
- **Format**: `{Feature}View.swift`
- **Examples**:
  - `SystemHealthView.swift` - System health display view
  - `KalshiMarketsView.swift` - Kalshi markets display view
  - `OperationsView.swift` - Operations control view

### ViewModels
- **Format**: `{Feature}ViewModel.swift`
- **Examples**:
  - `SystemHealthViewModel.swift` - System health view model
  - `KalshiMarketsViewModel.swift` - Kalshi markets view model
  - `OperationsViewModel.swift` - Operations view model

### Widgets
- **Format**: `{Feature}Widget.swift`
- **Examples**:
  - `MarketStatusWidget.swift` - Market status widget
  - `FredReleasesWidget.swift` - FRED releases widget
  - `AccountBalancesWidget.swift` - Account balances widget

## Organization Principles

1. **Separation of Concerns**: Views and ViewModels are in separate directories
2. **Grouped by Type**: All views together, all view models together, all widgets together
3. **Consistent Naming**: All files follow consistent naming patterns
4. **Widget ViewModels**: Widget ViewModels (like `FredReleasesViewModel`, `AccountBalancesViewModel`) are kept in the same file as their widget since widgets are self-contained components

## Notes

- **Widget ViewModels**: Some widgets have ViewModels embedded in the same file (e.g., `FredReleasesWidget.swift` contains `FredReleasesViewModel`). This is acceptable for widgets as they are smaller, self-contained components.
- **Shared Code**: All services, models, and shared UI components are in `clients/shared/` and imported via `import F90Shared`

