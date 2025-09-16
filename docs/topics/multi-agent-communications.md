# Multi-Agent Communications (Channels & Messaging) — A2A Extension (Draft)

> Status: Draft (Proposed for protocol version 0.5.0). This extension introduces durable multi-agent channels and streaming event delivery. Feedback welcome before stabilization.

## 1. Overview

This extension adds first-class multi-agent communication primitives to A2A. It enables:

- Durable conversation channels with ordered message events.
- Implicit direct channels (two-party conversations) without explicit creation RPCs.
- Real-time streaming of new events with resume semantics.
- Cursor-based history pagination with sequence or time filters.

The goal is to provide a unified substrate for collaborative agent reasoning, orchestration, and coordination while maintaining backward compatibility with existing `message/send` flows.

## 2. Capability Advertisement

Agents supporting this extension **MUST** advertise a capability declaration within their `AgentCard.capabilities` under a reserved key `messaging.channels`:

```json
{
  "messaging": {
    "channels": {
      "version": "0.1",
      "features": ["create", "publish", "history", "stream", "membership"]
    }
  }
}
```

Clients **MUST** feature-detect before invoking channel methods.

## 3. Core Concepts

| Concept | Description |
|---------|-------------|
| Channel | Durable logical conversation space among two or more principals. |
| Direct Channel | Deterministic implicit channel between exactly two principals. |
| Message Event | Immutable ordered communication entry within a channel. |
| Sequence | Strictly increasing integer per channel defining total order. |
| Cursor Token | Opaque encoded pagination or resume state. |
| Control Event | (Reserved) Non-message structural update (membership, metadata). |

Direct channels re-use all channel semantics but are auto-created. They are never listed via `channels/list` unless a future capability is negotiated.

## 4. Data Model

### 4.1 Channel Object

```jsonc
{
  "id": "chan_123",              // UUID
  "name": "research-collab",     // optional
  "visibility": "private",       // or "public"
  "createdAt": 1737052334123,     // ms epoch
  "createdBy": "agent://founder",
  "members": [
    { "principalId": "agent://founder", "role": "owner", "joinedAt": 1737052334123 }
  ],
  "metadata": { "project": "alpha" },
  "version": 3,                    // increments on membership/metadata changes
  "kind": "channel"
}
```

### 4.2 ChannelMember Object
```jsonc
{
  "principalId": "agent://assistant",
  "role": "member",            // owner | member | moderator (future)
  "joinedAt": 1737052400000
}
```

### 4.3 MessageEvent Object
```jsonc
{
  "id": "msg_456",              // UUID (idempotency identity)
  "channelId": "chan_123",      // always present for durable channels
  "sequence": 42,                 // monotonic per channel
  "timestamp": 1737052500456,     // ms epoch
  "author": "agent://assistant",
  "parts": [ { "type": "text", "text": "Let's enumerate hypotheses." } ],
  "artifactRefs": ["artifact_abc"],
  "metadata": { "phase": "analysis" },
  "idempotencyKey": "client-uuid-123",
  "kind": "messageEvent"
}
```

### 4.4 Event Stream Envelope

Reserved for future inclusion of control events:

```jsonc
{
  "kind": "messageEvent",
  "event": { /* MessageEvent */ }
}
```

## 5. Deterministic Direct Channels

A direct two-party conversation channel ID **MUST** be derived using a stable canonical form:
```
chan:direct:{hash(principalA,principalB)}
```
- `principalA` and `principalB` sorted lexicographically before hashing.
- Hash algorithm **SHOULD** be SHA-256 and truncated (e.g. first 24 hex chars) to keep IDs concise.
- Servers **MUST** reject any operation that attempts to add a third member to a direct channel.

## 6. Ordering & Idempotency

- `sequence` starts at 1 and increments by 1 for each accepted message event.
- Sequences **MUST NOT** reuse or skip; a detected gap in streaming delivery is a protocol error (client MAY close and re-sync).
- If `idempotencyKey` is present and a duplicate submission matches an existing stored event, the server **MUST** return the original event.
- If the existing event differs semantically, the server **MUST** return `ConflictError`.

## 7. Methods (JSON-RPC)

| Method | Description | Required | Notes |
|--------|-------------|----------|-------|
| `channels/create` | Create a new channel | YES | Owner = caller |
| `channels/get` | Fetch channel by ID | YES | Visibility & membership enforced |
| `channels/list` | List channels | YES | Direct channels excluded |
| `channels/update` | Update name/metadata (optimistic) | YES | Requires `expectedVersion` |
| `channels/delete` | Delete channel | YES | MUST clear membership |
| `channels/addMember` | Add member | YES | Owner-only |
| `channels/removeMember` | Remove member | YES | Owner-only (cannot remove last owner) |
| `channels/publish` | Publish message event | YES | Increments sequence |
| `channels/history` | Paginate message events | YES | Cursor or sequence filters |
| `channels/stream` | Stream future events | YES | SSE / server stream |

### 7.1 `channels/publish`
Params:
```jsonc
{
  "channelId": "chan_123",
  "parts": [ { "type": "text", "text": "Draft summary?" } ],
  "artifactRefs": ["artifact_abc"],
  "idempotencyKey": "uuid-1",
  "metadata": { "phase": "synthesis" }
}
```
Result:
```jsonc
{ "event": { /* MessageEvent */ } }
```

Errors:
- `ChannelNotFoundError`
- `PermissionDeniedError`
- `ConflictError` (idempotency mismatch)
- `LimitExceededError` (payload too large)

### 7.2 `channels/history`
Params:
```jsonc
{
  "channelId": "chan_123",
  "pageSize": 50,
  "pageToken": "opaqueCursor",
  "sinceSequence": 10,
  "authorIds": ["agent://assistant"]
}
```
Result:
```jsonc
{
  "events": [ /* MessageEvent[] */ ],
  "nextPageToken": "opaqueNext"
}
```
Rules:
- `sinceSequence` and `sinceTimestamp` are mutually exclusive.
- If both supplied → `InvalidParamsError`.

### 7.3 `channels/stream`
Params:
```jsonc
{
  "channelId": "chan_123",
  "sinceSequence": 40,
  "heartbeatIntervalMs": 15000
}
```
Stream Events:
- `messageEvent` objects.
- Optional heartbeat events (future) with `kind: "heartbeat"` (reserved).

### 7.4 `channels/update`
Params:
```jsonc
{
  "channelId": "chan_123",
  "expectedVersion": 3,
  "name": "research-collab-phase2",
  "metadataPatch": {
    "set": { "phase": "iteration" },
    "remove": ["deprecatedKey"]
  }
}
```
Conflict if `expectedVersion` mismatches current channel `version`.

## 8. Constraints & Defaults

| Item | Default | Bounds | Notes |
|------|---------|--------|-------|
| pageSize | 50 | 1–200 | Server MAY clamp |
| name length | — | ≤128 chars | Server MAY reject longer |
| metadata size | — | ≤16KB | Combined serialized size |
| parts per publish | — | ≤32 | Recommendation |
| idempotencyKey length | — | ≤128 chars | Optional |

## 9. Errors

| Error | Condition |
|-------|-----------|
| `ChannelNotFoundError` | Unknown channelId |
| `PermissionDeniedError` | Caller not member or visibility restriction |
| `ConflictError` | Version mismatch / idempotency semantic mismatch |
| `InvalidParamsError` | Mutually exclusive filters or malformed cursor |
| `LimitExceededError` | Payload or metadata exceeds limits |
| `RateLimitError` | Server throttling publish or history |

## 10. Security

- Private channels MUST NOT leak existence (return `ChannelNotFoundError` to unauthorized callers).
- Direct channels restricted to exactly two principals.
- Audit entries SHOULD include: channelId, eventId, actor, action type.
- Streaming endpoints MUST apply same auth as unary calls.

## 11. Interoperability & Backward Compatibility

- Existing `message/send` remains valid for single-turn or task-centric flows.
- Tasks MAY reference artifacts also linked in channel discussions by ID (no duplication).
- Agents MAY use channels to coordinate before emitting a consolidated Task.

## 12. Future Extensions (Non-Normative)

- Presence events (`presenceEvent`).
- Topic broadcasts (`topics/*`).
- Threading (`replyToId` explicit semantics + `threadId`).
- Projection parameters for selective fields.
- Encryption envelope for payload confidentiality.

## 13. Versioning

- Proposed protocol minor bump: `0.5.0`.
- Capability key version (`0.1`) can advance independently while protocol stabilizes.

## 14. Open Questions

1. Should backward pagination (reverse direction) be in MVP? (Currently excluded.)
2. Include `totalSize` in history responses? (Costs vs utility.)
3. Add `controlEvent` early for membership changes? (Currently reserved.)
4. Should direct channel IDs be explicitly prefixed differently (e.g., `chan:dm:`)?

## 15. Implementation Guidance (Informative)

- Store sequences in contiguous integer columns for efficient range scans.
- Maintain composite index `(channel_id, sequence)`.
- Cursor token can be base64url of JSON payload; include HMAC to prevent tampering.

---
*End of Draft Extension*
