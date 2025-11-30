# Polygon/Massive.com Plan Limitations & Implementation Notes

## Current Subscription Status

### Stocks Plan ✅ (Active - WebSocket Enabled)
- **Plan Level**: Active subscription with WebSocket access
- **Data Type**: 15-minute Delayed Data
- **WebSocket**: ✅ Available (`wss://delayed.massive.com/stocks`)
- **Implementation**: ✅ Implemented in Hadron
- **Status**: Working (with delayed endpoint)

### Options Plan ⚠️ (Basic - $0/month)
- **Plan Level**: Basic (Free tier)
- **Data Type**: End of Day Data only
- **WebSocket**: ❌ Not available on Basic plan
- **REST API**: ✅ Available (5 API calls/minute limit)
- **Implementation**: ❌ Not yet implemented in Hadron
- **Next Steps**: Implement REST API polling for End of Day data

### Currencies Plan ⚠️ (Basic - $0/month)
- **Plan Level**: Basic (Free tier)
- **Data Type**: End of Day Data only
- **WebSocket**: ❌ Not available on Basic plan
- **REST API**: ✅ Available (5 API calls/minute limit)
- **Implementation**: ❌ Not yet implemented in Hadron
- **Next Steps**: Implement REST API polling for End of Day data

### Indices Plan ⚠️ (Basic - $0/month)
- **Plan Level**: Basic (Free tier)
- **Data Type**: End of Day Data only
- **WebSocket**: ❌ Not available on Basic plan
- **REST API**: ✅ Available (5 API calls/minute limit)
- **Implementation**: ❌ Not yet implemented in Hadron
- **Next Steps**: Implement REST API polling for End of Day data

## Implementation Strategy

### Phase 1: Stocks (Current - WebSocket)
- ✅ Real-time ingestion via WebSocket
- ✅ 15-minute delayed data
- ✅ Multiple ticker subscriptions
- ✅ Automatic reconnection

### Phase 2: Options/Currencies/Indices (REST API)
- [ ] REST API client for End of Day data
- [ ] Scheduled polling (once per day after market close)
- [ ] Batch data collection
- [ ] Unified normalization pipeline
- [ ] Rate limiting (5 calls/minute for Basic plans)

### Upgrade Path
When upgrading Options/Currencies/Indices plans:
- **Starter Plans**: Enable 15-minute delayed WebSocket access
- **Developer/Advanced Plans**: Enable real-time WebSocket access
- Hadron can be configured to switch from REST to WebSocket automatically

## Rate Limiting Considerations

**Basic Plans (Options/Currencies/Indices):**
- 5 API calls per minute
- Need to implement rate limiting in REST API client
- Batch requests efficiently
- Cache responses where possible

**Stocks Plan:**
- Unlimited API calls
- No rate limiting needed for REST API
- WebSocket has connection limits (1 per asset class)

## Connection Limits

**WebSocket:**
- Polygon/Massive.com allows **1 concurrent WebSocket connection per asset class**
- Current implementation uses only first API key to avoid "max_connections" errors
- Multiple connections will fail with "max_connections" error

**REST API:**
- No connection limits
- Only rate limiting applies (calls per minute)
- Multiple API keys can be used for REST API calls (unlike WebSocket)

## Recommended Next Steps

1. **Implement REST API Ingest Module**
   - Create `ingest/rest.rs` for REST API polling
   - Support Options, Currencies, Indices
   - Implement rate limiting
   - Schedule daily polling after market close

2. **Unified Normalization**
   - Ensure all asset classes flow through same normalization pipeline
   - Handle different data formats (WebSocket vs REST)
   - Maintain consistent `HadronTick` schema

3. **Configuration Management**
   - Add asset class configuration
   - Enable/disable asset classes based on plan availability
   - Automatic fallback from WebSocket to REST if needed

4. **Monitoring & Alerts**
   - Track API call usage (especially for Basic plans)
   - Alert when approaching rate limits
   - Monitor WebSocket connection health

