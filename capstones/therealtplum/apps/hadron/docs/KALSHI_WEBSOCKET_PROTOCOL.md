# Kalshi WebSocket Protocol Reference

Based on official documentation: https://docs.kalshi.com/getting_started/quick_start_websockets

## Connection

**Production URL:**
```
wss://api.elections.kalshi.com/trade-api/ws/v2
```

**Demo URL:**
```
wss://demo-api.kalshi.co/trade-api/ws/v2
```

## Authentication

Kalshi uses RSA-PSS signing for WebSocket authentication, same as REST API.

### Required Headers
```
KALSHI-ACCESS-KEY: your_api_key_id
KALSHI-ACCESS-SIGNATURE: request_signature
KALSHI-ACCESS-TIMESTAMP: unix_timestamp_in_milliseconds
```

### Signature Generation
1. Create message to sign:
   ```
   timestamp + "GET" + "/trade-api/ws/v2"
   ```
2. Sign with RSA-PSS using private key
3. Base64 encode the signature
4. Include in headers when opening WebSocket

## Subscription Model

### Subscribe Command Format
```json
{
  "id": 1,
  "cmd": "subscribe",
  "params": {
    "channels": ["ticker", "orderbook_delta", "trades"],
    "market_ticker": "KXHARRIS24-LSV"  // Optional: specific market
  }
}
```

### Available Channels
- `ticker` - Real-time ticker updates for all markets
- `orderbook_delta` - Incremental orderbook updates
- `orderbook_snapshot` - Full orderbook state
- `trades` - Trade execution events

### Subscribe to All Markets
```json
{
  "id": 1,
  "cmd": "subscribe",
  "params": {
    "channels": ["ticker"]
  }
}
```

### Subscribe to Specific Markets
```json
{
  "id": 2,
  "cmd": "subscribe",
  "params": {
    "channels": ["orderbook_delta", "trades"],
    "market_ticker": "KXHARRIS24-LSV"
  }
}
```

## Message Types

### Ticker Update
```json
{
  "type": "ticker",
  "data": {
    "market_ticker": "KXHARRIS24-LSV",
    "bid": 45,
    "ask": 46,
    "last_price": 45,
    "volume": 1234
  }
}
```

### Orderbook Snapshot
```json
{
  "type": "orderbook_snapshot",
  "data": {
    "market_ticker": "KXHARRIS24-LSV",
    "yes": [[45, 100], [44, 200]],  // [price_cents, quantity]
    "no": [[55, 150], [56, 250]]
  }
}
```

### Orderbook Delta (Update)
```json
{
  "type": "orderbook_delta",
  "data": {
    "market_ticker": "KXHARRIS24-LSV",
    "yes": [[45, 100]],  // Updated price/quantity
    "no": [[55, 150]],
    "client_order_id": "optional"  // Only if your order caused this
  }
}
```

### Trade Event
```json
{
  "type": "trades",
  "data": {
    "market_ticker": "KXHARRIS24-LSV",
    "price": 45,  // Price in cents
    "quantity": 10,
    "side": "yes",  // or "no"
    "timestamp": 1234567890
  }
}
```

### Subscription Confirmation
```json
{
  "type": "subscribed",
  "id": 1,
  "data": {
    "channels": ["ticker"],
    "market_ticker": "KXHARRIS24-LSV"
  }
}
```

### Error Message
```json
{
  "id": 123,
  "type": "error",
  "msg": {
    "code": 6,
    "msg": "Params required"
  }
}
```

## Error Codes

| Code | Error                                | Description                             |
| ---- | ------------------------------------ | --------------------------------------- |
| 1    | Unable to process message            | General processing error                |
| 2    | Params required                      | Missing params object in command        |
| 3    | Channels required                    | Missing channels array in subscribe     |
| 4    | Subscription IDs required            | Missing sids in unsubscribe             |
| 5    | Unknown command                      | Invalid command name                    |
| 6    | Authentication required              | Private channel without auth            |
| 7    | Unknown subscription ID              | Subscription ID not found                |
| 8    | Unknown channel name                 | Invalid channel in subscribe            |
| 9    | Channel error                        | Channel-specific error                  |
| 10   | Invalid parameter                    | Malformed parameter value              |
| 11   | Market ticker required               | Missing market specification            |
| 12   | Market not found                     | Invalid market ticker                   |
| 13   | Internal error                       | Server-side processing error            |

## Key Differences from Polygon

| Aspect | Polygon | Kalshi |
|--------|---------|--------|
| **Auth** | API key in message | RSA-PSS in headers |
| **Connection** | Auth after connect | Auth in headers |
| **Subscriptions** | Ticker symbols | Market tickers |
| **Price Format** | Dollars | Cents (0-100) |
| **Orderbook** | Bids + Asks | YES bids + NO bids (reciprocal) |
| **Events** | T, Q, A | ticker, orderbook_delta, trades |

## Implementation Notes

1. **Authentication**: Must sign connection request, not post-connect
2. **Message IDs**: Use incrementing IDs for subscription commands
3. **Keep-Alive**: WebSocket library handles ping/pong automatically
4. **Reconnection**: Implement exponential backoff on disconnect
5. **Price Normalization**: Kalshi prices are in cents (0-100), need to normalize to Decimal

## References

- [WebSocket Quick Start](https://docs.kalshi.com/getting_started/quick_start_websockets)
- [Market Data Quick Start](https://docs.kalshi.com/getting_started/quick_start_market_data)
- [Authenticated Requests](https://docs.kalshi.com/getting_started/quick_start_authenticated_requests)
- [API Reference](https://docs.kalshi.com/api-reference/)
- [Rate Limits](https://docs.kalshi.com/getting_started/rate_limits)

