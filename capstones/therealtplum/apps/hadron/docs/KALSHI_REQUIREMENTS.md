# Kalshi Integration: What We Need to Get Started

## Priority 1: Critical (Need Immediately)

### 1. **Kalshi API Documentation** 📚
**What we need:**
- WebSocket API documentation (most up-to-date version)
- Message format specifications
- Authentication flow details
- Subscription/unsubscription protocols
- Event types and their structures
- Error handling and reconnection logic

**Why it's critical:**
- Can't build ingest without understanding the protocol
- Need to know exact message formats for parsing
- Authentication details are essential (RSA-PSS signing)

**Where to provide:**
- Links to official docs
- Or copy/paste relevant sections
- Or screenshots if docs are behind login

### 2. **RSA Private Key** 🔐
**What we need:**
- RSA private key in PEM format
- Or path to where it's stored
- Or environment variable name where it's set

**Why it's critical:**
- Required for authentication
- Different from Polygon's simple API key approach
- Need to understand key format and loading

**Security note:**
- Don't paste the actual key here!
- We'll load it from environment variable
- Just need to know: format, location, variable name

### 3. **At Least One API Key** 🔑
**What we need:**
- One Kalshi API key to start testing
- More keys can be added later for:
  - Connection pooling/rotation
  - Load testing
  - Redundancy

**Why it's critical:**
- Can't test without it
- Need to verify authentication works
- Need to test WebSocket connection

**How to provide:**
- Add to `.env` file (already gitignored)
- Or tell us the environment variable name
- We'll use it like: `KALSHI_API_KEY` or similar

## Priority 2: Very Helpful (Need Soon)

### 4. **Example WebSocket Messages** 📨
**What we need:**
- Real examples of WebSocket messages from Kalshi
- Trade events
- Order book updates
- Market status changes
- Subscription confirmations
- Error messages

**Why it's helpful:**
- Can build parser with real examples
- Understand exact JSON structure
- See what fields are available
- Handle edge cases

**How to provide:**
- Copy/paste from WebSocket logs
- Or from browser DevTools Network tab
- Or from your existing Python code's logs

### 5. **Market IDs for Testing** 🎯
**What we need:**
- List of 5-10 active market IDs to subscribe to
- Examples of different market types:
  - Index markets (e.g., S&P 500)
  - Event markets
  - Date-based markets

**Why it's helpful:**
- Can test subscriptions immediately
- Understand market ID format
- Test with real data

**Example format:**
```
INX-2024-12-31-UP
BIDEN-2024
SPY-2024-12-31-ABOVE-4500
```

### 6. **WebSocket URL & Environment** 🌐
**What we need:**
- Production WebSocket URL
- Demo/test WebSocket URL (if different)
- Any environment-specific configuration

**From your Python code, I see:**
- Production: `wss://api.elections.kalshi.com/trade-api/ws/v2`
- Demo: `wss://demo-api.kalshi.co/trade-api/ws/v2`

**Confirm:**
- Are these still correct?
- Any other endpoints?
- Environment variable to switch between them?

## Priority 3: Nice to Have (Can Add Later)

### 7. **Additional API Keys** (For Future)
**What we need:**
- 2-5 additional API keys (when ready for multi-connection testing)

**Why it's nice:**
- Test connection pooling
- Load testing
- Redundancy/failover
- But not needed for MVP

### 8. **Rate Limits & Constraints** ⚡
**What we need:**
- WebSocket connection limits per account
- Message rate limits
- Subscription limits
- Any other constraints

**Why it's nice:**
- Design around limitations
- Avoid hitting limits
- Plan for scaling

### 9. **Error Scenarios** ⚠️
**What we need:**
- Common error messages
- What happens on connection loss
- Reconnection behavior
- Authentication failures

**Why it's nice:**
- Build robust error handling
- Test edge cases
- Handle failures gracefully

## What We Already Have ✅

From the `kalshi-integration` branch, we have:
- ✅ Python WebSocket client code (reference)
- ✅ RSA-PSS signing implementation (reference)
- ✅ Basic understanding of Kalshi structure
- ✅ WebSocket URLs (need confirmation)

## Recommended Starting Package

**Minimum to start building:**
1. ✅ Kalshi API documentation (WebSocket section)
2. ✅ One API key + RSA private key (in `.env`)
3. ✅ 3-5 example market IDs
4. ✅ Confirmation of WebSocket URLs

**Ideal starting package:**
1. ✅ All of the above
2. ✅ 5-10 example WebSocket messages
3. ✅ 2-3 API keys (for testing)
4. ✅ Rate limit information

## How to Provide

### Option 1: Documentation
- Links to official docs
- Or copy/paste relevant sections
- Or markdown file with key sections

### Option 2: Environment Variables
Add to `.env` file:
```bash
# Kalshi Configuration
KALSHI_API_KEY=your_key_here
KALSHI_PRIVATE_KEY_PATH=/path/to/private_key.pem
# OR
KALSHI_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
KALSHI_WS_URL=wss://api.elections.kalshi.com/trade-api/ws/v2
KALSHI_USE_DEMO=false
```

### Option 3: Example Messages
Create a file: `apps/hadron/docs/kalshi_examples.json`
```json
{
  "trade_event": { ... },
  "order_update": { ... },
  "market_status": { ... }
}
```

### Option 4: Quick Test
- Run your existing Python WebSocket client
- Capture 10-20 messages
- Share the logs/output

## Next Steps After You Provide

1. **Review documentation** → Understand protocol
2. **Set up environment** → Add keys to `.env`
3. **Build ingest module** → Follow Polygon pattern
4. **Test connection** → Verify authentication works
5. **Parse messages** → Extract trade/order data
6. **Normalize** → Map to `HadronTick`

## Questions to Answer

1. **Authentication:**
   - Is RSA-PSS signing required for WebSocket?
   - Or is it only for REST API?
   - How do you authenticate WebSocket connections?

2. **Message Format:**
   - JSON? Binary? Other?
   - Array of events? Single events?
   - Any framing/protocol overhead?

3. **Subscription:**
   - How do you subscribe to markets?
   - Can you subscribe to multiple at once?
   - What's the subscription message format?

4. **Events:**
   - What event types are available?
   - Trade events? Order book? Market status?
   - What fields are in each event type?

5. **Environment:**
   - Production vs demo - what's the difference?
   - Which should we use for development?
   - Any other environments?

## Summary

**To start building immediately, we need:**
1. 📚 **API Documentation** (WebSocket protocol)
2. 🔐 **RSA Private Key** (format + location)
3. 🔑 **One API Key** (for testing)
4. 🎯 **Market IDs** (3-5 examples)

**Everything else can come later as we build!**

