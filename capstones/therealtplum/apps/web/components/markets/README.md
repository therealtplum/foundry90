# Markets Hub

A modular, widget-based dashboard for monitoring markets, accounts, and insights across multiple asset classes and brokers.

## Overview

The Markets Hub is inspired by professional trading platforms like Bloomberg Terminal, ThinkOrSwim, and Robinhood. It provides a flexible, grid-based layout where users can monitor:

- **Watch Lists** - Custom ticker lists with real-time prices
- **Market News** - Relevant financial news articles
- **Market Insights** - AI-generated insights across asset classes
- **Account Balances** - Multi-broker account aggregation (Kalshi, Robinhood, Schwab, Coinbase, etc.)
- **Positions** - Current positions across all linked accounts
- **Market Overview** - Key metrics and indices by asset class
- **Price Charts** - Interactive price charts (placeholder for charting library integration)

## Architecture

### Widget System

All widgets extend the `BaseWidget` component which provides:
- Consistent header with title and actions
- Loading and error states
- Standardized styling

### Components

- `MarketsHubLayout` - Main layout container with header and navigation
- `BaseWidget` - Base component for all widgets
- Individual widget components in `widgets/` directory

### Styling

The styling is located in `styles/globals.css` under the "MARKETS HUB" section. It uses:
- Dark theme with high contrast
- Grid-based responsive layout
- Professional, data-dense design
- Smooth transitions and hover effects

## Usage

Navigate to `/markets` to view the Markets Hub.

## Future Enhancements

- [ ] Real-time WebSocket updates for prices
- [ ] Drag-and-drop widget reordering
- [ ] Customizable widget layouts (save/load configurations)
- [ ] Integration with charting libraries (TradingView, Chart.js, etc.)
- [ ] Multi-broker API integrations (Robinhood, Schwab, Coinbase)
- [ ] User authentication and personalized watch lists
- [ ] News feed integration (Polygon, Alpha Vantage, etc.)
- [ ] Advanced filtering and search
- [ ] Export functionality (CSV, PDF reports)

