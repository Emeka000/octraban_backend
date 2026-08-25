# WebSocket API — Event Stream (`/ws/events`)

Real-time decoded Soroban contract events are pushed over a persistent WebSocket connection at `ws[s]://<host>/ws/events`.

---

## Authentication

Every connection must supply a valid credential. Two methods are accepted:

### 1. API Key

Pass your developer API key (issued via the Developer API console) as the `token` query parameter:

```
ws://localhost:3000/ws/events?token=<your-api-key>
```

Alternatively, non-browser clients can set the `X-Api-Key` header on the HTTP upgrade request:

```http
GET /ws/events HTTP/1.1
Upgrade: websocket
X-Api-Key: <your-api-key>
```

### 2. JWT Bearer Token

Pass a JWT access token obtained from `/api/v1/auth/login` as:

```
ws://localhost:3000/ws/events?token=Bearer%20<jwt-token>
```

Or via the `Authorization` header on the upgrade request:

```http
GET /ws/events HTTP/1.1
Upgrade: websocket
Authorization: Bearer <jwt-token>
```

> **Note:** Most browser `WebSocket` constructors do not support setting custom headers.
> Use the `?token=` query parameter for browser clients.

### Rejection

Connections that present no credentials or invalid/expired credentials are rejected during the HTTP upgrade phase:

| Reason | HTTP status during upgrade | WS close code |
|---|---|---|
| No credentials | `401 Unauthorized` | `4401` |
| Invalid or expired API key / JWT | `401 Unauthorized` | `4401` |
| Origin not in allowlist | `403 Forbidden` | `4403` |
| Connection or subscription cap exceeded | `429 Too Many Requests` | `4429` |

---

## Origin Validation

For browser clients, the server validates the `Origin` header against the `WS_ALLOWED_ORIGINS` allowlist.

- If `WS_ALLOWED_ORIGINS` is set, only the listed origins are accepted. All others receive `4403 Forbidden`.
- If `WS_ALLOWED_ORIGINS` is **empty** (default), all origins are accepted. This is safe for development but **should not be used in production**.
- Server-to-server clients that do not send an `Origin` header are always permitted regardless of the allowlist.

Configure in `.env`:

```env
WS_ALLOWED_ORIGINS=https://app.example.com,https://staging.example.com
```

---

## Filtering

On connection, clients can subscribe to a subset of events using optional query parameters:

| Parameter | Description | Example |
|---|---|---|
| `contract` | Filter by contract address (exact match) | `?contract=CXXX...` |
| `eventType` | Filter by event type (exact match) | `?eventType=token_transfer` |

Both filters are optional. Omitting a filter means "receive all values" for that dimension. They can be combined:

```
ws://localhost:3000/ws/events?token=<key>&contract=CXXX...&eventType=swap
```

### Subscription cap

Each connection may apply at most `WS_MAX_FILTERS_PER_CONNECTION` filters (default `10`). Connections that exceed this limit are immediately closed with `4429`.

---

## Event message format

```json
{
  "type": "event",
  "data": {
    "id": "evt_abc123",
    "contractAddress": "CXXX...",
    "eventType": "token_transfer",
    "decoded": { "from": "GABC...", "to": "GDEF...", "amount": "100" },
    "ledger": 4521983,
    "ledgerCloseTime": "2024-01-01T00:00:00.000Z",
    "transactionHash": "abc123..."
  }
}
```

Emergency broadcast messages use `"type": "emergency"` and are sent to all authenticated connections regardless of filters.

---

## Heartbeat / Ping-Pong

The server sends a WebSocket `ping` frame to every connected client at the configured `WS_HEARTBEAT_INTERVAL_MS` interval (default 30 s). Clients **must** respond with a `pong` frame — the browser `WebSocket` API does this automatically.

Clients that do not respond within one heartbeat interval are terminated and removed. This prevents slow-consumer or zombie sockets from accumulating.

---

## Connection Limits

| Limit | Environment variable | Default |
|---|---|---|
| Global concurrent connections | `WS_MAX_CONNECTIONS_GLOBAL` | `10000` |
| Connections per source IP | `WS_MAX_CONNECTIONS_PER_IP` | `10` |
| Filters per connection | `WS_MAX_FILTERS_PER_CONNECTION` | `10` |

Exceeding any limit closes the connection with close code `4429`.

---

## Configuration Reference

| Variable | Default | Description |
|---|---|---|
| `WS_ALLOWED_ORIGINS` | *(empty — allow all)* | Comma-separated exact Origin URLs for browser clients |
| `WS_MAX_CONNECTIONS_GLOBAL` | `10000` | Hard cap on total concurrent WS connections |
| `WS_MAX_CONNECTIONS_PER_IP` | `10` | Per-IP connection cap |
| `WS_MAX_FILTERS_PER_CONNECTION` | `10` | Maximum active filters per connection |
| `WS_HEARTBEAT_INTERVAL_MS` | `30000` | Ping interval in milliseconds |
| `WS_IDLE_TIMEOUT_MS` | `120000` | Idle timeout before a connection is reaped |

---

## Client Example

```javascript
// Browser / Node.js
const ws = new WebSocket(
  'wss://api.example.com/ws/events?token=<api-key>&contract=CXXX...&eventType=token_transfer'
);

ws.addEventListener('message', (event) => {
  const msg = JSON.parse(event.data);
  if (msg.type === 'event') {
    console.log('Decoded event:', msg.data);
  }
});

ws.addEventListener('close', (event) => {
  // Check close code for actionable information
  if (event.code === 4401) console.error('Auth failed — check your token');
  if (event.code === 4403) console.error('Origin not allowed');
  if (event.code === 4429) console.error('Connection limit reached');
});
```
