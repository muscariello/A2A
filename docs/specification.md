# Agent2Agent (A2A) Protocol Official Specification

{% macro render_spec_tabs(region_tag) %}
=== "JSON-RPC"

    ```ts { .no-copy }
    --8<-- "types/src/types.ts:{{ region_tag }}"
    ```

=== "gRPC"

    ```proto { .no-copy }
    --8<-- "specification/grpc/a2a.proto:{{ region_tag }}"
    ```
{% endmacro %}

??? note "**Latest Released Version** [`0.3.0`](https://a2a-protocol.org/v0.3.0/specification)"

    **Previous Versions**

    - [`0.2.6`](https://a2a-protocol.org/v0.2.6/specification)
    - [`0.2.5`](https://a2a-protocol.org/v0.2.5/specification)
    - [`0.2.4`](https://a2a-protocol.org/v0.2.4/specification)
    - [`0.2.0`](https://a2a-protocol.org/v0.2.0/specification)
    - [`0.1.0`](https://a2a-protocol.org/v0.1.0/specification)

See [Release Notes](https://github.com/a2aproject/A2A/releases) for changes made between versions.

## 1. Introduction

The Agent2Agent (A2A) Protocol is an open standard designed to facilitate communication and interoperability between independent, potentially opaque AI agent systems. In an ecosystem where agents might be built using different frameworks, languages, or by different vendors, A2A provides a common language and interaction model.

This document provides the detailed technical specification for the A2A protocol. Its primary goal is to enable agents to:

- Discover each other's capabilities.
- Negotiate interaction modalities (text, files, structured data).
- Manage collaborative tasks.
- Securely exchange information to achieve user goals **without needing access to each other's internal state, memory, or tools.**

### 1.1. Key Goals of A2A

- **Interoperability:** Bridge the communication gap between disparate agentic systems.
- **Collaboration:** Enable agents to delegate tasks, exchange context, and work together on complex user requests.
- **Discovery:** Allow agents to dynamically find and understand the capabilities of other agents.
- **Flexibility:** Support various interaction modes including synchronous request/response, streaming for real-time updates, and asynchronous push notifications for long-running tasks.
- **Security:** Facilitate secure communication patterns suitable for enterprise environments, relying on standard web security practices.
- **Asynchronicity:** Natively support long-running tasks and interactions that may involve human-in-the-loop scenarios.

### 1.2. Guiding Principles

- **Simple:** Reuse existing, well-understood standards (HTTP, JSON-RPC 2.0, Server-Sent Events).
- **Enterprise Ready:** Address authentication, authorization, security, privacy, tracing, and monitoring by aligning with established enterprise practices.
- **Async First:** Designed for (potentially very) long-running tasks and human-in-the-loop interactions.
- **Modality Agnostic:** Support exchange of diverse content types including text, audio/video (via file references), structured data/forms, and potentially embedded UI components (e.g., iframes referenced in parts).
- **Opaque Execution:** Agents collaborate based on declared capabilities and exchanged information, without needing to share their internal thoughts, plans, or tool implementations.

For a broader understanding of A2A's purpose and benefits, see [What is A2A?](./topics/what-is-a2a.md).

### 1.3. Specification Structure

This specification is organized into three distinct layers that work together to provide a complete protocol definition:

```mermaid
graph TB
    subgraph L1 ["A2A Data Model"]
        direction LR
        A[Task] ~~~ B[Message] ~~~ C[AgentCard] ~~~ D[Part] ~~~ E[Artifact] ~~~ F[Extension]
    end

    subgraph L2 ["A2A Operations"]
        direction LR
        G[Send Message] ~~~ H[Stream Message] ~~~ I[Get Task] ~~~ J[List Tasks] ~~~ K[Cancel Task] ~~~ L[Get Agent Card]
    end

    subgraph L3 ["Protocol Bindings"]
        direction LR
        M[JSON-RPC Methods] ~~~ N[gRPC RPCs] ~~~ O[HTTP/REST Endpoints] ~~~ P[Custom Bindings]
    end

    %% Dependencies between layers
    L1 --> L2
    L2 --> L3


    style A fill:#e1f5fe
    style B fill:#e1f5fe
    style C fill:#e1f5fe
    style D fill:#e1f5fe
    style E fill:#e1f5fe
    style F fill:#e1f5fe

    style G fill:#f3e5f5
    style H fill:#f3e5f5
    style I fill:#f3e5f5
    style J fill:#f3e5f5
    style K fill:#f3e5f5
    style L fill:#f3e5f5

    style M fill:#e8f5e8
    style N fill:#e8f5e8
    style O fill:#e8f5e8

    style L1 fill:#f0f8ff,stroke:#333,stroke-width:2px
    style L2 fill:#faf0ff,stroke:#333,stroke-width:2px
    style L3 fill:#f0fff0,stroke:#333,stroke-width:2px
```

**Layer 1: Canonical Data Model** defines the core data structures and message formats that all A2A implementations must understand. These are protocol agnostic definitions expressed as Protocol Buffer messages.

**Layer 2: Abstract Operations** describes the fundamental capabilities and behaviors that A2A agents must support, independent of how they are exposed over specific protocols.

**Layer 3: Protocol Bindings** provides concrete mappings of the abstract operations and data structures to specific protocol bindings (JSON-RPC, gRPC, HTTP/REST), including method names, endpoint patterns, and protocol-specific behaviors.

This layered approach ensures that:

- Core semantics remain consistent across all protocol bindings
- New protocol bindings can be added without changing the fundamental data model
- Developers can reason about A2A operations independently of binding concerns
- Interoperability is maintained through shared understanding of the canonical data model

## 2. Terminology

### 2.1. Requirements Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC 2119](https://tools.ietf.org/html/rfc2119).

### 2.2. Core Concepts

A2A revolves around several key concepts. For detailed explanations, please refer to the [Key Concepts guide](./topics/key-concepts.md).

- **A2A Client:** An application or agent that initiates requests to an A2A Server on behalf of a user or another system.
- **A2A Server (Remote Agent):** An agent or agentic system that exposes an A2A-compliant endpoint, processing tasks and providing responses.
- **Agent Card:** A JSON metadata document published by an A2A Server, describing its identity, capabilities, skills, service endpoint, and authentication requirements.
- **Message:** A communication turn between a client and a remote agent, having a `role` ("user" or "agent") and containing one or more `Parts`.
- **Task:** The fundamental unit of work managed by A2A, identified by a unique ID. Tasks are stateful and progress through a defined lifecycle.
- **Part:** The smallest unit of content within a Message or Artifact (e.g., `TextPart`, `FilePart`, `DataPart`).
- **Artifact:** An output (e.g., a document, image, structured data) generated by the agent as a result of a task, composed of `Parts`.
- **Streaming:** Real-time, incremental updates for tasks (status changes, artifact chunks) delivered via protocol-specific streaming mechanisms.
- **Push Notifications:** Asynchronous task updates delivered via server-initiated HTTP POST requests to a client-provided webhook URL, for long-running or disconnected scenarios.
- **Context:** An optional, server-generated identifier to logically group related tasks.
- **Extension:** A mechanism for agents to provide additional functionality or data beyond the core A2A specification.

## 3. A2A Protocol Operations

This section describes the core operations of the A2A protocol in a binding-independent manner. These operations define the fundamental capabilities that all A2A implementations must support, regardless of the underlying binding mechanism.

### 3.1. Core Operations

#### 3.1.1. Send Message

The primary operation for initiating agent interactions. Clients send a message to an agent and receive either a task that tracks the processing or a direct response message.

**Inputs:**

- [`SendMessageRequest`](#321-sendmessagerequest): Request object containing the message, configuration, and metadata

**Outputs:**

- [`Task`](#411-task): A task object representing the processing of the message, OR
- [`Message`](#414-message): A direct response message (for simple interactions that don't require task tracking)

**Errors:**

- [`ContentTypeNotSupportedError`](#332-error-handling): A Media Type provided in the request's message parts is not supported by the agent.
- [`UnsupportedOperationError`](#332-error-handling): Messages sent to Tasks that are in a terminal state (e.g., completed, canceled, rejected) cannot accept further messages.

**Behavior:**

The agent MAY create a new task to process the provided message asynchronously or MAY return a direct message response for simple interactions. The operation MUST return immediately with either task information or response message. Task processing MAY continue asynchronously after the response when a [`Task`](#411-task) is returned.

**Protocol Bindings:**

- **JSON-RPC**: [`message/send`](#941-messagesend)
- **gRPC**: [`SendMessage`](#1041-sendmessage)
- **HTTP/REST**: [`POST /v1/message:send`](#1131-message-operations)

#### 3.1.2. Stream Message

Similar to Send Message but with real-time streaming of updates during processing.

**Inputs:**

- [`SendMessageRequest`](#321-sendmessagerequest): Request object containing the message, configuration, and metadata

**Outputs:**

- Initial response: [`Task`](#411-task) object OR [`Message`](#414-message) object
- Subsequent events following a `Task` MAY include stream of [`TaskStatusUpdateEvent`](#421-taskstatusupdateevent) and [`TaskArtifactUpdateEvent`](#422-taskartifactupdateevent) objects
- Final completion indicator

**Errors:**

- [`UnsupportedOperationError`](#332-error-handling): Streaming is not supported by the agent (see [Capability Validation](#334-capability-validation)).
- [`UnsupportedOperationError`](#332-error-handling): Messages sent to Tasks that are in a terminal state (e.g., completed, canceled, rejected) cannot accept further messages.
- [`ContentTypeNotSupportedError`](#332-error-handling): A Media Type provided in the request's message parts is not supported by the agent.

**Behavior:**

The operation MUST establish a streaming connection for real-time updates. The agent MAY return a [`Task`](#411-task) for complex processing with status/artifact updates or MAY return a [`Message`](#414-message) for direct streaming responses without task overhead. The implementation MUST provide immediate feedback on progress and intermediate results. The stream MUST terminate when processing reaches a final state.

**Protocol Bindings:**

- **JSON-RPC**: [`message/stream`](#942-messagestream)
- **gRPC**: [`SendStreamingMessage`](#1042-sendstreamingmessage)
- **HTTP/REST**: [`POST /v1/message:stream`](#1131-message-operations)

#### 3.1.3. Get Task

Retrieves the current state (including status, artifacts, and optionally history) of a previously initiated task. This is typically used for polling the status of a task initiated with message/send, or for fetching the final state of a task after being notified via a push notification or after a stream has ended.

**Inputs:**

- `taskId`: Unique identifier of the task to retrieve
- `historyLength` (optional): Number of recent messages to include in the task's history (see [History Length Semantics](#323-history-length-semantics) for details)

**Outputs:**

- [`Task`](#411-task): Current state and artifacts of the requested task

**Errors:**

None specific to this operation beyond standard protocol errors.

**Protocol Bindings:**

- **JSON-RPC**: [`tasks/get`](#943-tasksget)
- **gRPC**: [`GetTask`](#1043-gettask)
- **HTTP/REST**: [`GET /v1/tasks/{id}`](#1132-task-operations)

#### 3.1.4. List Tasks

Retrieves a list of tasks with optional filtering and pagination capabilities. This method allows clients to discover and manage multiple tasks across different contexts or with specific status criteria.

**Inputs:**

- `contextId` (optional): Filter tasks by context ID to get tasks from a specific conversation or session
- `status` (optional): Filter tasks by their current status state
- `pageSize` (optional): Maximum number of tasks to return (must be between 1 and 100, defaults to 50)
- `pageToken` (optional): Token for pagination from a previous response
- `historyLength` (optional): Number of recent messages to include in each task's history (see [History Length Semantics](#323-history-length-semantics) for details, defaults to 0)
- `lastUpdatedAfter` (optional): Filter tasks updated after this timestamp (milliseconds since epoch)
- `includeArtifacts` (optional): Whether to include artifacts in returned tasks (defaults to false)
- [`metadata`](#324-metadata) (optional): Request-specific metadata for extensions or custom parameters

When includeArtifacts is false (the default), the artifacts field MUST be omitted entirely from each Task object in the response. The field should not be present as an empty array or null value. When includeArtifacts is true, the artifacts field should be included with its actual content (which may be an empty array if the task has no artifacts).

**Outputs:**

- `tasks`: Array of [`Task`](#411-task) objects matching the specified criteria
- `totalSize`: Total number of tasks available (before pagination)
- `pageSize`: Maximum number of tasks returned in this response
- `nextPageToken`: Token for retrieving the next page of results (empty if no more results)

Note on nextPageToken: The nextPageToken field MUST always be present in the response. When there are no more results to retrieve (i.e., this is the final page), the field MUST be set to an empty string (""). Clients should check for an empty string to determine if more pages are available.

**Errors:**

None specific to this operation beyond standard protocol errors.

**Behavior:**

The operation MUST return only tasks visible to the authenticated client and MUST use cursor-based pagination for performance and consistency. Tasks MUST be sorted by last update time in descending order. Implementations MUST implement appropriate authorization scoping to ensure clients can only access authorized tasks. See [Section 7.7.1 Data Access and Authorization Scoping](#771-data-access-and-authorization-scoping) for detailed security requirements.

**Pagination Strategy**: This method uses cursor-based pagination (via pageToken/nextPageToken) rather than offset-based pagination for better performance and consistency, especially with large datasets. Cursor-based pagination avoids the "deep pagination problem" where skipping large numbers of records becomes inefficient for databases. This approach is consistent with the gRPC specification, which also uses cursor-based pagination (page_token/next_page_token).

**Ordering**: Implementations MUST return tasks sorted by their last update time in descending order (most recently updated tasks first). This ensures consistent pagination and allows clients to efficiently monitor recent task activity.

**Protocol Bindings:**

- **JSON-RPC**: [`tasks/list`](#944-taskslist)
- **gRPC**: [`ListTasks`](#1044-listtasks)
- **HTTP/REST**: [`GET /v1/tasks`](#1132-task-operations)

#### 3.1.5. Cancel Task

Requests the cancellation of an ongoing task. The server will attempt to cancel the task, but success is not guaranteed (e.g., the task might have already completed or failed, or cancellation might not be supported at its current stage).

**Inputs:**

- `taskId`: Unique identifier of the task to cancel

**Outputs:**

- Updated [`Task`](#411-task) with cancellation status

**Errors:**

- [`TaskNotCancelableError`](#332-error-handling): The task is not in a cancelable state (e.g., already completed, failed, or canceled).
- [`TaskNotFoundError`](#332-error-handling): The task ID does not exist or is not accessible.

**Behavior:**

The operation attempts to cancel the specified task and returns its updated state.


**Protocol Bindings:**

- **JSON-RPC**: [`tasks/cancel`](#945-taskscancel)
- **gRPC**: [`CancelTask`](#1045-canceltask)
- **HTTP/REST**: [`POST /v1/tasks/{id}:cancel`](#1132-task-operations)

#### 3.1.6. Resubscribe to Task
<span id="79-tasksresubscribe"></span><span id="1035-taskresubscription"></span>

Establishes a streaming connection to resume receiving updates for a specific task that was originally created by a streaming operation.

**Inputs:**

- `taskId`: Unique identifier of the task to monitor

**Outputs:**

- [Stream Response](#322-stream-response) object containing:
- Initial response: [`Task`](#411-task) object with current state
- Stream of [`TaskStatusUpdateEvent`](#421-taskstatusupdateevent) and [`TaskArtifactUpdateEvent`](#422-taskartifactupdateevent) objects

**Errors:**

- [`UnsupportedOperationError`](#332-error-handling): Streaming is not supported by the agent (see [Capability Validation](#334-capability-validation)).
- [`TaskNotFoundError`](#332-error-handling): The task ID does not exist or is not accessible.
- [`UnsupportedOperationError`](#332-error-handling): The operation is attempted on a task that was not created by a streaming operation.

**Behavior:**

The operation enables real-time monitoring of task progress but can only be used with tasks created by `message/stream` operations, not `message/send`. This operation SHOULD be used for reconnecting to previously created streaming tasks after connection interruption. The stream MUST terminate when the task reaches a final state.

The operation MUST return a `Task` object as the first event in the stream, representing the current state of the task at the time of resubscription. This prevents a potential loss of information between a call to `tasks/get` and calling `tasks/resubscribe`.

**Protocol Bindings:**

- **JSON-RPC**: [`tasks/resubscribe`](#946-tasksresubscribe)
- **gRPC**: [`TaskResubscription`](#1046-taskresubscription)
- **HTTP/REST**: [`POST /v1/tasks/{id}:resubscribe`](#1132-task-operations)

#### 3.1.7. Set or Update Push Notification Config
<span id="75-taskspushnotificationconfigset"></span>

Creates or updates a push notification configuration for a task to receive asynchronous updates via webhook.

**Inputs:**

- `taskId`: Unique identifier of the task to configure notifications for
- [`PushNotificationConfig`](#431-pushnotificationconfig): Configuration specifying webhook URL and notification preferences

**Outputs:**

- [`TaskPushNotificationConfig`](#432-taskpushnotificationconfig): Created configuration with assigned ID

**Errors:**

- [`PushNotificationNotSupportedError`](#332-error-handling): Push notifications are not supported by the agent (see [Capability Validation](#334-capability-validation)).
- [`TaskNotFoundError`](#332-error-handling): The task ID does not exist or is not accessible.

**Behavior:**

The operation MUST establish a webhook endpoint for task update notifications. When task updates occur, the agent will send HTTP POST requests to the configured webhook URL with [`StreamResponse`](#322-stream-response) payloads (see [Push Notification Payload](#434-push-notification-payload) for details). This operation is only available if the agent supports push notifications capability. The configuration MUST persist until task completion or explicit deletion.

**Protocol Bindings:**

- **JSON-RPC**: [`tasks/pushNotificationConfig/set`](#947-push-notification-configuration-methods)
- **gRPC**: [`SetTaskPushNotificationConfig`](#grpc-push-notification-operations)
- **HTTP/REST**: [`POST /v1/tasks/{id}/pushNotificationConfigs`](#1133-push-notification-configuration)
 <span id="tasks-push-notification-config-operations"></span><span id="grpc-push-notification-operations"></span><span id="push-notification-operations"></span>

#### 3.1.8. Get Push Notification Config
<span id="76-taskspushnotificationconfigget"></span>

Retrieves an existing push notification configuration for a task.

**Inputs:**

- `taskId`: Unique identifier of the task
- `configId`: Unique identifier of the push notification configuration

**Outputs:**

- [`TaskPushNotificationConfig`](#432-taskpushnotificationconfig): The requested configuration

**Errors:**

- [`PushNotificationNotSupportedError`](#332-error-handling): Push notifications are not supported by the agent (see [Capability Validation](#334-capability-validation)).
- [`TaskNotFoundError`](#332-error-handling): The push notification configuration does not exist.

**Behavior:**

The operation MUST return configuration details including webhook URL and notification settings. The operation MUST fail if the configuration does not exist or the client lacks access.

**Protocol Bindings:**

- **JSON-RPC**: [`tasks/pushNotificationConfig/get`](#947-push-notification-configuration-methods)
- **gRPC**: [`GetTaskPushNotificationConfig`](#grpc-push-notification-operations)
- **HTTP/REST**: [`GET /v1/tasks/{id}/pushNotificationConfigs/{configId}`](#1133-push-notification-configuration)

#### 3.1.9. List Push Notification Configs

Retrieves all push notification configurations for a task.

**Inputs:**

- `taskId`: Unique identifier of the task

**Outputs:**

- Array of [`TaskPushNotificationConfig`](#432-taskpushnotificationconfig) objects

**Errors:**

- [`PushNotificationNotSupportedError`](#332-error-handling): Push notifications are not supported by the agent (see [Capability Validation](#334-capability-validation)).
- [`TaskNotFoundError`](#332-error-handling): The task ID does not exist or is not accessible.

**Behavior:**

The operation MUST return all active push notification configurations for the specified task and MAY support pagination for tasks with many configurations.

**Protocol Bindings:**

- **JSON-RPC**: [`tasks/pushNotificationConfig/list`](#947-push-notification-configuration-methods)
- **gRPC**: [`ListTaskPushNotificationConfig`](#grpc-push-notification-operations)
- **HTTP/REST**: [`GET /v1/tasks/{id}/pushNotificationConfigs`](#1133-push-notification-configuration)

#### 3.1.10. Delete Push Notification Config

Removes a push notification configuration for a task.

**Inputs:**

- `taskId`: Unique identifier of the task
- `configId`: Unique identifier of the push notification configuration to delete

**Outputs:**

- Confirmation of deletion (implementation-specific)

**Errors:**

- [`PushNotificationNotSupportedError`](#332-error-handling): Push notifications are not supported by the agent (see [Capability Validation](#334-capability-validation)).
- [`TaskNotFoundError`](#332-error-handling): The task ID does not exist.

**Behavior:**

The operation MUST permanently remove the specified push notification configuration. No further notifications will be sent to the configured webhook after deletion. This operation MUST be idempotent - multiple deletions of the same config have the same effect.

**Protocol Bindings:**

- **JSON-RPC**: [`tasks/pushNotificationConfig/delete`](#947-push-notification-configuration-methods)
- **gRPC**: [`DeleteTaskPushNotificationConfig`](#grpc-push-notification-operations)
- **HTTP/REST**: [`DELETE /v1/tasks/{id}/pushNotificationConfigs/{configId}`](#1133-push-notification-configuration)

#### 3.1.11. Get Extended Agent Card

Retrieves a potentially more detailed version of the Agent Card after the client has authenticated. This endpoint is available only if `AgentCard.supportsAuthenticatedExtendedCard` is `true`.

**Inputs:**

- None (no parameters required)

**Outputs:**

- [`AgentCard`](#441-agentcard): A complete Agent Card object, which may contain additional details or skills not present in the public card

**Errors:**

- [`UnsupportedOperationError`](#332-error-handling): The agent does not support authenticated extended cards (see [Capability Validation](#334-capability-validation)).
- [`ExtendedAgentCardNotConfiguredError`](#332-error-handling): The agent declares support but does not have an extended agent card configured.

**Behavior:**

- **Authentication**: The client MUST authenticate the request using one of the schemes declared in the public `AgentCard.securitySchemes` and `AgentCard.security` fields.
- **Extended Information**: The operation MAY return different details based on client authentication level, including additional skills, capabilities, or configuration not available in the public Agent Card.
- **Card Replacement**: Clients retrieving this extended card SHOULD replace their cached public Agent Card with the content received from this endpoint for the duration of their authenticated session or until the card's version changes.
- **Availability**: This operation is only available if the public Agent Card declares `supportsAuthenticatedExtendedCard: true`.

For detailed security guidance on extended agent cards, see [Section 7.7.3 Extended Agent Card Access Control](#773-extended-agent-card-access-control).

**Protocol Bindings:**

- **JSON-RPC**: [`agent/getExtendedAgentCard`](#948-agentgetextendedagentcard)
- **gRPC**: [`GetExtendedAgentCard`](#10411-getextendedagentcard)
- **HTTP/REST**: [`GET /v1/extendedAgentCard`](#1134-agent-card)

### 3.2. Operation Parameter Objects

This section defines common parameter objects used across multiple operations.

#### 3.2.1. SendMessageRequest

Request object for sending messages to an agent.

```proto
--8<-- "specification/grpc/a2a.proto:SendMessageRequest"
```

#### 3.2.2. Stream Response

A wrapper object used in streaming operations to encapsulate different types of response data.

The Stream Response contains exactly one of the following properties:

- **task**: A [`Task`](#411-task) object containing the current state of the task
- **message**: A [`Message`](#414-message) object containing a message in the conversation
- **taskStatusUpdateEvent**: A [`TaskStatusUpdateEvent`](#421-taskstatusupdateevent) object indicating a change in task status
- **taskArtifactUpdateEvent**: A [`TaskArtifactUpdateEvent`](#422-taskartifactupdateevent) object indicating updates to task artifacts

This wrapper allows streaming endpoints to return different types of updates through a single response stream while maintaining type safety.

```proto
--8<-- "specification/grpc/a2a.proto:StreamResponse"
```

#### 3.2.3. History Length Semantics

The `historyLength` parameter appears in multiple operations and controls how much task history is returned in responses. This parameter follows consistent semantics across all operations:

- **Unset/undefined**: No limit imposed; server returns its default amount of history (implementation-defined, may be all history)
- **0**: No history should be returned; the `history` field SHOULD be omitted or empty
- **> 0**: Return at most this many recent messages from the task's history

**Server Requirements:**
- Servers MAY return fewer history items than requested (e.g., if fewer items exist or for performance reasons)
- Servers MUST NOT return more history items than requested when a positive limit is specified
- When `historyLength` is 0, servers SHOULD omit the `history` field entirely rather than including an empty array

#### 3.2.4. Metadata

A flexible key-value map for passing additional context or parameters with operations. Metadata keys and are strings and values can be any valid value that can be represented in JSON. [`Extensions`](#46-extensions) can be used to strongly type metadata values for specific use cases.

#### 3.2.5 Service Parameters

A key-value map for passing horizontally applicable context or parameters with case-insensitive string keys and case-sensitive string values. The transmission mechanism for these service parameter key-value pairs is defined by the specific protocol binding (e.g., HTTP headers for HTTP-based bindings, gRPC metadata for gRPC bindings). Custom protocol bindings **MUST** specify how service parameters are transmitted in their binding specification.

**Standard A2A Service Parameters:**

| Header Name | Description | Example Value |
| :---------- | :---------- | :------------ |
| `A2A-Extensions` | Comma-separated list of extension URIs that the client wants to use for the request | `https://example.com/extensions/geolocation/v1,https://standards.org/extensions/citations/v1` |
| `A2A-Version` | The A2A protocol version that the client is using. If the version is not supported, the agent returns [`VersionNotSupportedError`](#332-error-handling) | `0.3` |

As service parameter names MAY need to co-exist with other parameters defined by the underlying transport protocol or infrastructure, all service parameters defined by this specification will be prefixed with `a2a-`.

### 3.3. Operation Semantics

#### 3.3.1. Idempotency

- **Get operations** (Get Task, List Tasks, Get Extended Agent Card) are naturally idempotent
- **Send Message** operations MAY be idempotent. Agents may utilize the messageId to detect duplicate messages.
- **Cancel Task** operations are idempotent - multiple cancellation requests have the same effect. A duplicate cancellation request MAY return `TaskNotFoundError` if a the task has already been canceled and purged.

#### 3.3.2. Error Handling

All operations may return errors in the following categories. Servers **MUST** return appropriate errors and **SHOULD** provide actionable information to help clients resolve issues.

**Error Categories and Server Requirements:**

- **Authentication Errors**: Invalid or missing credentials
    - Servers **MUST** reject requests with invalid or missing authentication credentials
    - Servers **SHOULD** include authentication challenge information in the error response
    - Servers **SHOULD** specify which authentication scheme is required
    - Example error codes: HTTP `401 Unauthorized`, gRPC `UNAUTHENTICATED`, JSON-RPC custom error
    - Example scenarios: Missing bearer token, expired API key, invalid OAuth token

- **Authorization Errors**: Insufficient permissions for requested operation
    - Servers **MUST** return an authorization error when the authenticated client lacks required permissions
    - Servers **SHOULD** indicate what permission or scope is missing (without leaking sensitive information about resources the client cannot access)
    - Servers **MUST NOT** reveal the existence of resources the client is not authorized to access
    - Example error codes: HTTP `403 Forbidden`, gRPC `PERMISSION_DENIED`, JSON-RPC custom error
    - Example scenarios: Attempting to access a task created by another user, insufficient OAuth scopes

- **Validation Errors**: Invalid input parameters or message format
    - Servers **MUST** validate all input parameters before processing
    - Servers **SHOULD** specify which parameter(s) failed validation and why
    - Servers **SHOULD** provide guidance on valid parameter values or formats
    - Example error codes: HTTP `400 Bad Request`, gRPC `INVALID_ARGUMENT`, JSON-RPC `-32602 Invalid params`
    - Example scenarios: Invalid task ID format, missing required message parts, unsupported content type

- **Resource Errors**: Requested task not found or not accessible
    - Servers **MUST** return a not found error when a requested resource does not exist or is not accessible to the authenticated client
    - Servers **SHOULD NOT** distinguish between "does not exist" and "not authorized" to prevent information leakage
    - Example error codes: HTTP `404 Not Found`, gRPC `NOT_FOUND`, JSON-RPC custom error (see A2A-specific errors)
    - Example scenarios: Task ID does not exist, task has been deleted, configuration not found

- **System Errors**: Internal agent failures or temporary unavailability
    - Servers **SHOULD** return appropriate error codes for temporary failures vs. permanent errors
    - Servers **MAY** include retry guidance (e.g., Retry-After header in HTTP)
    - Servers **SHOULD** log system errors for diagnostic purposes
    - Example error codes: HTTP `500 Internal Server Error` or `503 Service Unavailable`, gRPC `INTERNAL` or `UNAVAILABLE`, JSON-RPC `-32603 Internal error`
    - Example scenarios: Database connection failure, downstream service timeout, rate limit exceeded

**Error Payload Structure:**

All error responses in the A2A protocol, regardless of binding, **MUST** convey the following information:

1. **Error Code**: A machine-readable identifier for the error type (e.g., string code, numeric code, or protocol-specific status)
2. **Error Message**: A human-readable description of the error
3. **Error Details** (optional): Additional structured information about the error, such as:
    - Affected fields or parameters
    - Contextual information (e.g., task ID, timestamp)
    - Suggestions for resolution

Protocol bindings **MUST** map these elements to their native error representations while preserving semantic meaning. See binding-specific sections for concrete error format examples: [JSON-RPC Error Handling](#95-error-handling), [gRPC Error Handling](#105-error-handling), and [HTTP/REST Error Handling](#116-error-handling).

**A2A-Specific Errors:**

| Error Name                          | Description                                                                                                                                                       |
| :---------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TaskNotFoundError`                 | The specified task ID does not correspond to an existing or accessible task. It might be invalid, expired, or already completed and purged.                       |
| `TaskNotCancelableError`            | An attempt was made to cancel a task that is not in a cancelable state (e.g., it has already reached a terminal state like `completed`, `failed`, or `canceled`). |
| `PushNotificationNotSupportedError` | Client attempted to use push notification features but the server agent does not support them (i.e., `AgentCard.capabilities.pushNotifications` is `false`).      |
| `UnsupportedOperationError`         | The requested operation or a specific aspect of it is not supported by this server agent implementation.                                                          |
| `ContentTypeNotSupportedError`      | A Media Type provided in the request's message parts or implied for an artifact is not supported by the agent or the specific skill being invoked.                |
| `InvalidAgentResponseError`         | An agent returned a response that does not conform to the specification for the current method.                                                                    |
| `ExtendedAgentCardNotConfiguredError` | The agent does not have an extended agent card configured when one is required for the requested operation.                                     |
| `ExtensionSupportRequiredError`     | Client requested use of an extension marked as `required: true` in the Agent Card but the client did not declare support for it in the request.                  |
| `VersionNotSupportedError`          | The A2A protocol version specified in the request (via `A2A-Version` service parameter) is not supported by the agent. |

#### 3.3.3. Asynchronous Processing

- [`Task`](#411-task) objects represent asynchronous work units
- Operations return immediately with task information
- Clients must poll or stream to get completion status
- Agents may continue processing after initial response

#### 3.3.4. Capability Validation

Agents declare optional capabilities in their [`AgentCard`](#441-agentcard). When clients attempt to use operations or features that require capabilities not declared as supported in the Agent Card, the agent **MUST** return an appropriate error response:

- **Push Notifications**: If `AgentCard.capabilities.pushNotifications` is `false` or not present, operations related to push notification configuration (Set, Get, List, Delete) **MUST** return [`PushNotificationNotSupportedError`](#332-error-handling).
- **Streaming**: If `AgentCard.capabilities.streaming` is `false` or not present, attempts to use `message/stream` or `tasks/resubscribe` operations **MUST** return [`UnsupportedOperationError`](#332-error-handling).
- **Extended Agent Card**: If `AgentCard.supportsAuthenticatedExtendedCard` is `false` or not present, attempts to call the Get Extended Agent Card operation **MUST** return [`UnsupportedOperationError`](#332-error-handling). If the agent declares support but has not configured an extended card, it **MUST** return [`ExtendedAgentCardNotConfiguredError`](#332-error-handling).
- **Extensions**: When a client requests use of an extension marked as `required: true` in the Agent Card but the client does not declare support for it, the agent **MUST** return [`ExtensionSupportRequiredError`](#332-error-handling).

Clients **SHOULD** validate capability support by examining the Agent Card before attempting operations that require optional capabilities.

### 3.4. Multi-Turn Interactions

The A2A protocol supports multi-turn conversations through context identifiers and task references, enabling agents to maintain conversational continuity across multiple interactions.

#### 3.4.1. Context Identifier Semantics

A `contextId` is an identifier that logically groups multiple related [`Task`](#411-task) and [`Message`](#414-message) objects, providing continuity across a series of interactions.

**Generation and Assignment:**

- Agents **MUST** generate a new `contextId` when processing a [`Message`](#414-message) that does not include a `contextId` field
- The generated `contextId` **MUST** be included in the response (either [`Task`](#411-task) or [`Message`](#414-message))
- Agents **MUST** accept and preserve client-provided `contextId` values in subsequent messages within the same conversation
- `contextId` values **SHOULD** be treated as opaque identifiers by clients

**Grouping and Scope:**

- A `contextId` logically groups multiple [`Task`](#411-task) objects and [`Message`](#414-message) objects that are part of the same conversational context
- All tasks and messages with the same `contextId` **SHOULD** be treated as part of the same conversational session
- Agents **MAY** use the `contextId` to maintain internal state, conversational history, or LLM context across multiple interactions
- Agents **MAY** implement context expiration or cleanup policies and **SHOULD** document any such policies

#### 3.4.2. Multi-Turn Conversation Patterns

The A2A protocol supports several patterns for multi-turn interactions:

**Context Continuity:**

- [`Task`](#411-task) objects maintain conversation context through the `contextId` field
- Clients **MAY** include the `contextId` in subsequent messages to indicate continuation of a previous interaction
- Clients **MAY** combine `contextId` with `taskId` references to continue or refine a specific task
- Clients **MAY** use `contextId` without `taskId` to start a new task within an existing conversation context

**Input Required State:**

- Agents can request additional input mid-processing by transitioning a task to the `input-required` state
- The client continues the interaction by sending a new message with the same `taskId` and `contextId`

**Follow-up Messages:**

- Clients can send additional messages with `taskId` references to continue or refine existing tasks
- Clients **SHOULD** use the `referenceTaskIds` field in [`Message`](#414-message) to explicitly reference related tasks
- Agents **SHOULD** use referenced tasks to understand the context and intent of follow-up requests

**Context Inheritance:**

- New tasks created within the same `contextId` can inherit context from previous interactions
- Agents **SHOULD** leverage the shared `contextId` to provide contextually relevant responses

### 3.5. Streaming and Real-Time Updates

Real-time capabilities are provided through:

- **Streaming Operations**: Stream Message and Resubscribe to Task
- **Event Types**: Status updates and artifact updates
- **Connection Management**: Proper handling of connection interruption and reconnection
- **Buffering**: Events may be buffered during connection outages

This specification defines three standard protocol bindings: [JSON-RPC Protocol Binding](#9-json-rpc-protocol-binding), [gRPC Protocol Binding](#10-grpc-protocol-binding), and [HTTP+JSON/REST Protocol Binding](#11-httpjsonrest-protocol-binding). Alternative protocol bindings **MAY** be supported as long as they comply with the constraints defined in [Section 3 (A2A Protocol Operations)](#3-a2a-protocol-operations), [Section 4 (Protocol Data Model)](#4-protocol-data-model), and [Section 5 (Binding Compliance and Interoperability)](#5-protocol-binding-compliance-and-interoperability).

### 3.6 Versioning

The specific version of the A2A protocol in use is identified using the `Major.Minor` elements (e.g. `1.0`) of the corresponding A2A specification version. Patch version numbers do not affect protocol compatibility, SHOULD NOT be included in requests and reponses, and MUST not be considered when clients and servers negotiate protocol versions.

Agents declare support for latest supported protocol version in the `protocolVersion` field in the Agent Card. Agents MAY also support earlier protocol versions. Clients SHOULD specify the desired protocol version in requests using the `A2A-Version` header. If the requested version is not supported by the agent, the agent MUST return a `VersionNotSupportedError`.

It is RECOMMENDED that clients send the `A2A-Version` header with each request to reduce the chances of being broken if an agent upgrades to a new version of the protocol. Sending the `A2A-Version` header provides visibility to agents about version usage in the ecosystem, which can help inform the risks of inplace version upgrades.

## 4. Protocol Data Model

The A2A protocol defines a canonical data model using Protocol Buffers. All protocol bindings **MUST** provide functionally equivalent representations of these data structures.

**"Normative Source" Principle:**

The file `specification/grpc/a2a.proto` is the single authoritative normative definition of all protocol data objects and request/response messages. A generated JSON artifact (`specification/json/a2a.json`, produced at build time and not committed) MAY be published for convenience to tooling and the website, but it is a non-normative build artifact. SDK language bindings, schemas, and any other derived forms **MUST** be regenerated from the proto (directly or via code generation) rather than edited manually.

** Change Control and Deprecation Lifecycle:**

- Introduction: When a proto message or field is renamed, the new name is added while existing published names remain available until the next major release.
- Documentation: This specification MUST include a Migration Appendix (Appendix A) enumerating legacy→current name mappings with planned removal versions.
- Anchors: Legacy documentation anchors MUST be preserved (as hidden HTML anchors) to avoid breaking inbound links.
- SDK/Schema Aliases: SDKs and JSON Schemas SHOULD provide deprecated alias types/definitions to maintain backward compatibility.
- Removal: A deprecated name SHOULD NOT be removed earlier than two minor versions after introduction of its replacement and MUST appear in at least one stable tagged release containing both forms.

Automated Generation:

The documentation build generates `specification/json/a2a.json` on-the-fly (the file is not tracked in source control). Future improvements may publish an OpenAPI v3 + JSON Schema bundle for enhanced tooling.

Rationale:

Centering the proto file as the normative source ensures protocol neutrality, reduces specification drift, and provides a deterministic evolution path for the ecosystem.

### 4.1. Core Objects

<span id="61-task-object"></span>
#### 4.1.1. Task

Represents the stateful unit of work being processed by the A2A Server for an A2A Client.

```proto
--8<-- "specification/grpc/a2a.proto:Task"
```

**JSON Example:**
```json
{
  "id": "task-12345",
  "contextId": "context-67890",
  "status": {
    "state": "completed",
    "message": {
      "messageId": "msg-98765",
      "role": "agent",
      "parts": [
        {
          "text": "Task completed successfully"
        }
      ]
    },
    "timestamp": "2025-10-28T10:30:00Z"
  },
  "artifacts": [
    {
      "artifactId": "artifact-001",
      "name": "Weather Report",
      "description": "Current weather conditions",
      "parts": [
        {
          "text": "Today will be sunny with a high of 75°F"
        }
      ],
      "metadata": {
        "location": "San Francisco",
        "source": "weather-api"
      }
    }
  ],
  "history": [
    {
      "messageId": "msg-11111",
      "role": "user",
      "parts": [
        {
          "text": "What's the weather like today?"
        }
      ]
    }
  ],
  "metadata": {
    "priority": "normal",
    "startTime": "2025-10-28T10:29:45Z",
    "endTime": "2025-10-28T10:30:00Z"
  }
}
```

#### 4.1.2. TaskStatus

Represents the current state and associated context of a Task.

```proto
--8<-- "specification/grpc/a2a.proto:TaskStatus"
```

**JSON Example:**
```json
{
  "state": "working",
  "message": {
    "messageId": "msg-status-001",
    "role": "agent",
    "parts": [
      {
        "text": "Processing your request, gathering weather data..."
      }
    ]
  },
  "timestamp": "2025-10-28T10:29:55Z"
}
```

<span id="63-taskstate-enum"></span>
#### 4.1.3. TaskState

Defines the possible lifecycle states of a Task.

```proto
--8<-- "specification/grpc/a2a.proto:TaskState"
```

**JSON Examples:**
```json
// Terminal states
"completed"
"failed"
"cancelled"
"rejected"

// Interrupted states
"input-required"
"auth-required"

// Working states
"submitted"
"working"
```

#### 4.1.4. Message
<span id="4241-messagesendconfiguration"></span>

Represents a single communication turn between a client and an agent.

```proto
--8<-- "specification/grpc/a2a.proto:Message"
```

**JSON Example:**
```json
{
  "messageId": "msg-12345",
  "contextId": "context-67890",
  "taskId": "task-98765",
  "role": "user",
  "parts": [
    {
      "text": "Find me restaurants near Times Square with good reviews"
    },
    {
      "data": {
        "preferences": {
          "cuisine": ["italian", "american"],
          "maxPrice": 50,
          "rating": 4.0
        }
      }
    }
  ],
  "metadata": {
    "timestamp": "2025-10-28T10:30:00Z",
    "userAgent": "A2A-Client/1.0"
  },
  "referenceTaskIds": [
    "task-previous-001"
  ]
}
```

#### 4.1.5. Role

Defines the sender of a message in the A2A protocol communication.

```proto
--8<-- "specification/grpc/a2a.proto:Role"
```

**JSON Examples:**
```json
// User role - client to server communication
"user"

// Agent role - server to client communication
"agent"
```

The Role enum distinguishes between messages sent by clients(`user`) and responses from agents (`agent`). This is used in the [`Message`](#414-message) object to identify the source of each communication turn.

#### 4.1.6. Part

Represents a distinct piece of content within a Message or Artifact.

```proto
--8<-- "specification/grpc/a2a.proto:Part"
```

**JSON Examples:**

*Text Part:*
```json
{
  "text": "Hello, how can I help you today?",
  "metadata": {
    "lang": "en",
    "tone": "friendly"
  }
}
```

*File Part:*
```json
{
  "file": {
    "fileWithUri": "https://example.com/documents/report.pdf",
    "mimeType": "application/pdf",
    "name": "quarterly-report.pdf"
  },
  "metadata": {
    "size": 2048576,
    "uploadedAt": "2025-10-28T10:30:00Z"
  }
}
```

*Data Part:*
```json
{
  "data": {
    "temperature": 72.5,
    "humidity": 45,
    "conditions": "sunny",
    "location": {
      "city": "San Francisco",
      "coordinates": {
        "lat": 37.7749,
        "lng": -122.4194
      }
    }
  },
  "metadata": {
    "source": "weather-api",
    "timestamp": "2025-10-28T10:30:00Z"
  }
}
```

#### 4.1.6. FilePart

Represents file-based content within a Part.

```proto
--8<-- "specification/grpc/a2a.proto:FilePart"
```

**JSON Examples:**

*File with URI:*
```json
{
  "fileWithUri": "https://example.com/uploads/document.pdf",
  "mimeType": "application/pdf",
  "name": "project-proposal.pdf"
}
```

*File with bytes (base64 encoded):*
```json
{
  "fileWithBytes": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  "mimeType": "image/png",
  "name": "sample-image.png"
}
```

#### 4.1.7. DataPart

Represents structured JSON data within a Part.

```proto
--8<-- "specification/grpc/a2a.proto:DataPart"
```

**JSON Example:**
```json
{
  "data": {
    "searchResults": [
      {
        "name": "Tony's Little Star Pizza",
        "rating": 4.5,
        "cuisine": "italian",
        "price": 25,
        "address": "1556 Stockton St, San Francisco, CA 94133",
        "distance": 0.3
      },
      {
        "name": "The Smith",
        "rating": 4.2,
        "cuisine": "american",
        "price": 35,
        "address": "956 2nd Ave, New York, NY 10022",
        "distance": 0.1
      }
    ],
    "totalResults": 127,
    "searchCriteria": {
      "location": "Times Square",
      "radius": 1.0,
      "minRating": 4.0
    }
  }
}
```

#### 4.1.8. Artifact

Represents a tangible output generated by the agent during a task.

```proto
--8<-- "specification/grpc/a2a.proto:Artifact"
```

**JSON Example:**
```json
{
  "artifactId": "artifact-restaurant-list-001",
  "name": "Restaurant Recommendations",
  "description": "List of highly rated restaurants near Times Square matching your preferences",
  "parts": [
    {
      "text": "# Top Restaurant Recommendations\n\nBased on your criteria, here are the best restaurants near Times Square:\n\n## 1. Tony's Little Star Pizza\n**Rating:** 4.5/5 | **Cuisine:** Italian | **Price:** $25\n**Address:** 1556 Stockton St, San Francisco, CA 94133\n\nAuthentic Italian pizza with excellent reviews for quality ingredients and atmosphere.\n\n## 2. The Smith\n**Rating:** 4.2/5 | **Cuisine:** American | **Price:** $35\n**Address:** 956 2nd Ave, New York, NY 10022\n\nUpscale American bistro known for excellent service and diverse menu options."
    },
    {
      "data": {
        "restaurants": [
          {
            "id": "rest-001",
            "name": "Tony's Little Star Pizza",
            "rating": 4.5,
            "cuisine": "italian",
            "averagePrice": 25,
            "coordinates": {
              "lat": 40.7589,
              "lng": -73.9851
            }
          },
          {
            "id": "rest-002",
            "name": "The Smith",
            "rating": 4.2,
            "cuisine": "american",
            "averagePrice": 35,
            "coordinates": {
              "lat": 40.7614,
              "lng": -73.9776
            }
          }
        ]
      }
    }
  ],
  "metadata": {
    "searchRadius": 1.0,
    "totalCandidates": 127,
    "filteredBy": ["rating >= 4.0", "price <= $50"],
    "generatedAt": "2025-10-28T10:30:00Z"
  }
}
```

### 4.2. Streaming Events

<span id="4192-taskstatusupdateevent"></span>
<span id="722-taskstatusupdateevent-object"></span>
#### 4.2.1. TaskStatusUpdateEvent

Carries information about a change in task status during streaming.

```proto
--8<-- "specification/grpc/a2a.proto:TaskStatusUpdateEvent"
```

**JSON Example:**
```json
{
  "taskId": "task-12345",
  "contextId": "context-67890",
  "status": {
    "state": "working",
    "message": {
      "messageId": "msg-status-update-001",
      "role": "agent",
      "parts": [
        {
          "text": "Searching for restaurants in your area..."
        }
      ]
    },
    "timestamp": "2025-10-28T10:29:55Z"
  },
  "final": false,
  "metadata": {
    "progress": 0.3,
    "estimatedTimeRemaining": "15s"
  }
}
```

<span id="4193-taskartifactupdateevent"></span>
<span id="723-taskartifactupdateevent-object"></span>
#### 4.2.2. TaskArtifactUpdateEvent

Carries a new or updated artifact generated during streaming.

```proto
--8<-- "specification/grpc/a2a.proto:TaskArtifactUpdateEvent"
```

**JSON Example:**
```json
{
  "taskId": "task-12345",
  "contextId": "context-67890",
  "artifact": {
    "artifactId": "artifact-streaming-001",
    "name": "Search Results",
    "parts": [
      {
        "text": "Found 3 restaurants matching your criteria:\n\n1. Tony's Little Star Pizza (4.5★)"
      }
    ]
  },
  "append": true,
  "lastChunk": false
}
```

### 4.3. Push Notification Objects

#### 4.3.1. PushNotificationConfig
<span id="68-pushnotificationconfig-object"></span>

Configuration for setting up push notifications for task updates.

```proto
--8<-- "specification/grpc/a2a.proto:PushNotificationConfig"
```

**JSON Example:**
```json
{
  "id": "push-config-001",
  "url": "https://client-webhook.example.com/a2a/notifications",
  "token": "webhook-token-abc123",
  "authentication": {
    "schemes": ["Bearer"],
    "credentials": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### 4.3.2. TaskPushNotificationConfig

Resource wrapper for push notification configurations.

```proto
--8<-- "specification/grpc/a2a.proto:TaskPushNotificationConfig"
```

**JSON Example:**
```json
{
  "name": "tasks/task-12345/pushNotificationConfigs/config-001",
  "pushNotificationConfig": {
    "id": "push-config-001",
    "url": "https://client-webhook.example.com/a2a/notifications",
    "token": "webhook-token-abc123",
    "authentication": {
      "schemes": ["Bearer"],
      "credentials": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
  }
}
```

#### 4.3.3. AuthenticationInfo

Defines authentication details for push notifications.

```proto
--8<-- "specification/grpc/a2a.proto:PushNotificationAuthenticationInfo"
```

**JSON Example:**
```json
{
  "schemes": ["Bearer", "Basic"],
  "credentials": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
}
```

#### 4.3.4. Push Notification Payload
<span id="434-push-notification-payload"></span>

When a task update occurs, the agent sends an HTTP POST request to the configured webhook URL. The payload uses the same [`StreamResponse`](#322-stream-response) format as streaming operations, allowing push notifications to deliver the same event types as real-time streams.

**Request Format:**

```http
POST {webhook_url}
Authorization: {authentication_scheme} {credentials}
Content-Type: application/json

{
  /* StreamResponse object - one of: */
  "task": { /* Task object */ },
  "message": { /* Message object */ },
  "statusUpdate": { /* TaskStatusUpdateEvent object */ },
  "artifactUpdate": { /* TaskArtifactUpdateEvent object */ }
}
```

**Payload Structure:**

The webhook payload is a [`StreamResponse`](#322-stream-response) object containing exactly one of the following:

- **task**: A [`Task`](#411-task) object with the current task state
- **message**: A [`Message`](#414-message) object containing a message response
- **statusUpdate**: A [`TaskStatusUpdateEvent`](#421-taskstatusupdateevent) indicating a status change
- **artifactUpdate**: A [`TaskArtifactUpdateEvent`](#422-taskartifactupdateevent) indicating artifact updates

**JSON Example (Status Update):**

```json
{
  "statusUpdate": {
    "taskId": "task-12345",
    "contextId": "context-67890",
    "status": {
      "state": "completed",
      "message": {
        "messageId": "msg-final-001",
        "role": "agent",
        "parts": [
          {
            "text": "Task completed successfully"
          }
        ]
      },
      "timestamp": "2025-10-28T10:30:00Z"
    },
    "final": true
  }
}
```

**JSON Example (Artifact Update):**

```json
{
  "artifactUpdate": {
    "taskId": "task-12345",
    "contextId": "context-67890",
    "artifact": {
      "artifactId": "artifact-001",
      "name": "Final Report",
      "parts": [
        {
          "text": "Report content here..."
        }
      ]
    },
    "append": false,
    "lastChunk": true
  }
}
```

**Authentication:**

The agent MUST include authentication credentials in the request headers as specified in the [`PushNotificationConfig.authentication`](#433-authenticationinfo) field. The format follows standard HTTP authentication patterns (Bearer tokens, Basic auth, etc.).

**Client Responsibilities:**

- Clients MUST respond with HTTP 2xx status codes to acknowledge successful receipt
- Clients SHOULD process notifications idempotently, as duplicate deliveries may occur
- Clients MUST validate the task ID matches an expected task
- Clients SHOULD implement appropriate security measures to verify the notification source

**Server Guarantees:**

- Agents MUST attempt delivery at least once for each configured webhook
- Agents MAY implement retry logic with exponential backoff for failed deliveries
- Agents SHOULD include a reasonable timeout for webhook requests (recommended: 10-30 seconds)
- Agents MAY stop attempting delivery after a configured number of consecutive failures

For detailed security guidance on push notifications, see [Section 7.7.2 Push Notification Security](#772-push-notification-security).

### 4.4. Agent Discovery Objects

<span id="441-agentcard"></span>
<span id="710-agentgetauthenticatedextendedcard"></span>
#### 4.4.1. AgentCard
<span id="421-agentcard"></span>

The primary metadata document describing an agent's capabilities and interface.

```proto
--8<-- "specification/grpc/a2a.proto:AgentCard"
```

**JSON Example:**
```json
{
  "protocolVersion": "0.3.0",
  "name": "Restaurant Finder Agent",
  "description": "AI agent specialized in finding and recommending restaurants based on user preferences, location, and dietary requirements",
  "url": "https://restaurant-agent.example.com/a2a/v1",
  "preferredTransport": "JSONRPC",
  "additionalInterfaces": [
    {
      "url": "https://restaurant-agent.example.com/a2a/grpc",
      "transport": "GRPC"
    },
    {
      "url": "https://restaurant-agent.example.com/a2a/rest",
      "transport": "HTTP+JSON"
    }
  ],
  "provider": {
    "organization": "Foodie AI Inc.",
    "url": "https://www.foodieai.com"
  },
  "version": "2.1.0",
  "documentationUrl": "https://docs.foodieai.com/restaurant-agent",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true,
    "extensions": [
      {
        "uri": "https://example.com/extensions/geolocation/v1",
        "description": "Location-based restaurant search",
        "required": false
      }
    ],
    "stateTransitionHistory": true
  },
  "securitySchemes": {
    "api_key": {
      "apiKeySecurityScheme": {
        "description": "API key authentication",
        "location": "header",
        "name": "X-API-Key"
      }
    }
  },
  "security": [
    {
      "schemes": {
        "api_key": {
          "list": []
        }
      }
    }
  ],
  "defaultInputModes": ["text/plain", "application/json"],
  "defaultOutputModes": ["text/plain", "application/json", "text/html"],
  "skills": [
    {
      "id": "restaurant-search",
      "name": "Restaurant Search and Recommendations",
      "description": "Find restaurants based on location, cuisine preferences, price range, and dietary restrictions",
      "tags": ["restaurants", "food", "search", "recommendations"],
      "examples": [
        "Find Italian restaurants near Times Square under $50",
        "Show me vegan-friendly places within 1 mile"
      ],
      "inputModes": ["text/plain", "application/json"],
      "outputModes": ["text/plain", "application/json"]
    }
  ],
  "supportsAuthenticatedExtendedCard": true,
  "iconUrl": "https://restaurant-agent.example.com/icon.png"
}
```

#### 4.4.2. AgentProvider

Information about the organization providing the agent.

```proto
--8<-- "specification/grpc/a2a.proto:AgentProvider"
```

**JSON Example:**
```json
{
  "organization": "Foodie AI Inc.",
  "url": "https://www.foodieai.com"
}
```

#### 4.4.3. AgentCapabilities

Defines optional A2A protocol features supported by the agent.

```proto
--8<-- "specification/grpc/a2a.proto:AgentCapabilities"
```

**JSON Example:**
```json
{
  "streaming": true,
  "pushNotifications": true,
  "extensions": [
    {
      "uri": "https://example.com/extensions/geolocation/v1",
      "description": "Location-based search capabilities",
      "required": false,
      "params": {
        "maxRadius": 10,
        "units": "miles"
      }
    }
  ],
  "stateTransitionHistory": true
}
```

#### 4.4.4. AgentExtension

Specifies a protocol extension supported by the agent.

```proto
--8<-- "specification/grpc/a2a.proto:AgentExtension"
```

**JSON Example:**
```json
{
  "uri": "https://example.com/extensions/geolocation/v1",
  "description": "Provides location-based search and filtering capabilities for enhanced geographic relevance",
  "required": false,
  "params": {
    "supportedUnits": ["miles", "kilometers"],
    "maxRadius": 50,
    "precisionLevel": "high"
  }
}
```

#### 4.4.5. AgentSkill

Describes a specific capability or area of expertise the agent can perform.

```proto
--8<-- "specification/grpc/a2a.proto:AgentSkill"
```

**JSON Example:**
```json
{
  "id": "restaurant-search",
  "name": "Restaurant Search and Recommendations",
  "description": "Comprehensive restaurant discovery service that finds dining establishments based on user preferences including cuisine type, price range, location, dietary restrictions, and ratings. Provides detailed information including menus, hours, and reservation options.",
  "tags": ["restaurants", "food", "dining", "search", "recommendations", "local"],
  "examples": [
    "Find Italian restaurants near Times Square under $50 per person",
    "Show me vegan-friendly places within 2 miles with 4+ star ratings",
    "{\"cuisine\": \"mexican\", \"location\": \"downtown\", \"maxPrice\": 30, \"dietary\": [\"vegetarian\"]}"
  ],
  "inputModes": ["text/plain", "application/json"],
  "outputModes": ["text/plain", "application/json", "text/html"],
  "security": [
    {
      "schemes": {
        "api_key": {
          "list": []
        }
      }
    }
  ]
}
```

#### 4.4.6. AgentInterface

Declares additional protocols supported by the agent.

```proto
--8<-- "specification/grpc/a2a.proto:AgentInterface"
```

**JSON Example:**
```json
{
  "url": "https://restaurant-agent.example.com/a2a/grpc",
  "transport": "GRPC"
}
```

#### 4.4.7. AgentCardSignature

Represents a JSON Web Signature for Agent Card verification.

```proto
--8<-- "specification/grpc/a2a.proto:AgentCardSignature"
```

**JSON Example:**
```json
{
  "protected": "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpPU0UiLCJraWQiOiJrZXktMSIsImprdSI6Imh0dHBzOi8vZXhhbXBsZS5jb20vYWdlbnQvandrcy5qc29uIn0",
  "signature": "QFdkNLNszlGj3z3u0YQGt_T9LixY3qtdQpZmsTdDHDe3fXV9y9-B3m2-XgCpzuhiLt8E0tV6HXoZKHv4GtHgKQ",
  "header": {
    "x5c": ["MIIBdjCCAR2gAwIBAgIJAK..."],
    "custom": "additional-header-data"
  }
}
```

### 4.5. Security Objects

#### 4.5.1. SecurityScheme

Base security scheme definition supporting multiple authentication types.

```proto
--8<-- "specification/grpc/a2a.proto:SecurityScheme"
```

**JSON Examples:**

*API Key Security Scheme:*
```json
{
  "apiKeySecurityScheme": {
    "description": "API key for server authentication",
    "location": "header",
    "name": "X-API-Key"
  }
}
```

*OAuth2 Security Scheme:*
```json
{
  "oauth2SecurityScheme": {
    "description": "OAuth 2.0 authorization",
    "flows": {
      "authorizationCode": {
        "authorizationUrl": "https://auth.example.com/oauth/authorize",
        "tokenUrl": "https://auth.example.com/oauth/token",
        "scopes": {
          "read": "Read access to agent capabilities",
          "write": "Write access to submit tasks"
        }
      }
    }
  }
}
```

#### 4.5.2. APIKeySecurityScheme

API key-based authentication scheme.

```proto
--8<-- "specification/grpc/a2a.proto:APIKeySecurityScheme"
```

**JSON Example:**
```json
{
  "description": "API key authentication for secure access",
  "location": "header",
  "name": "X-API-Key"
}
```

#### 4.5.3. HTTPAuthSecurityScheme

HTTP authentication scheme (Basic, Bearer, etc.).

```proto
--8<-- "specification/grpc/a2a.proto:HTTPAuthSecurityScheme"
```

**JSON Examples:**

*Bearer Token:*
```json
{
  "description": "Bearer token authentication",
  "scheme": "Bearer",
  "bearerFormat": "JWT"
}
```

*Basic Authentication:*
```json
{
  "description": "Basic HTTP authentication",
  "scheme": "Basic"
}
```

#### 4.5.4. OAuth2SecurityScheme

OAuth 2.0 authentication scheme.

```proto
--8<-- "specification/grpc/a2a.proto:OAuth2SecurityScheme"
```

**JSON Example:**
```json
{
  "description": "OAuth 2.0 authentication with authorization code flow",
  "flows": {
    "authorizationCode": {
      "authorizationUrl": "https://auth.example.com/oauth/authorize",
      "tokenUrl": "https://auth.example.com/oauth/token",
      "refreshUrl": "https://auth.example.com/oauth/refresh",
      "scopes": {
        "read": "Read access to agent capabilities",
        "write": "Submit tasks and receive responses",
        "admin": "Administrative access to agent configuration"
      }
    }
  },
  "oauth2MetadataUrl": "https://auth.example.com/.well-known/oauth-authorization-server"
}
```

#### 4.5.5. OpenIdConnectSecurityScheme

OpenID Connect authentication scheme.

```proto
--8<-- "specification/grpc/a2a.proto:OpenIdConnectSecurityScheme"
```

**JSON Example:**
```json
{
  "description": "OpenID Connect authentication",
  "openIdConnectUrl": "https://accounts.google.com/.well-known/openid-configuration"
}
```

#### 4.5.6. MutualTLSSecurityScheme

Mutual TLS authentication scheme.

```proto
--8<-- "specification/grpc/a2a.proto:MutualTLSSecurityScheme"
```

**JSON Example:**
```json
{
  "description": "Mutual TLS authentication using client certificates"
}
```

### 4.6. Extensions

The A2A protocol supports extensions to provide additional functionality or data beyond the core specification while maintaining backward compatibility and interoperability. Extensions allow agents to declare additional capabilities such as protocol enhancements or vendor-specific features, maintain compatibility with clients that don't support specific extensions, enable innovation through experimental or domain-specific features without modifying the core protocol, and facilitate standardization by providing a pathway for community-developed features to become part of the core specification.

#### 4.6.1. Extension Declaration

Agents declare their supported extensions in the [`AgentCard`](#441-agentcard) using the `extensions` field, which contains an array of [`AgentExtension`](#444-agentextension) objects.

*Example: Agent declaring extension support in AgentCard:*
```json
{
  "protocolVersion": "0.3.0",
  "name": "Research Assistant Agent",
  "description": "AI agent for academic research and fact-checking",
  "url": "https://research-agent.example.com/a2a/v1",
  "preferredTransport": "HTTP+JSON",
  "capabilities": {
    "streaming": false,
    "pushNotifications": false,
    "extensions": [
      {
        "uri": "https://standards.org/extensions/citations/v1",
        "description": "Provides citation formatting and source verification",
        "required": false
      },
      {
        "uri": "https://example.com/extensions/geolocation/v1",
        "description": "Location-based search capabilities",
        "required": false
      }
    ]
  },
  "defaultInputModes": ["text/plain"],
  "defaultOutputModes": ["text/plain"],
  "skills": [
    {
      "id": "academic-research",
      "name": "Academic Research Assistant",
      "description": "Provides research assistance with citations and source verification",
      "tags": ["research", "citations", "academic"],
      "examples": ["Find peer-reviewed articles on climate change"],
      "inputModes": ["text/plain"],
      "outputModes": ["text/plain"]
    }
  ]
}
```

Clients indicate their desire to opt into the use of specific extensions through binding-specific mechanisms such as HTTP headers, gRPC metadata, or JSON-RPC request parameters that identify the extension identifiers they wish to utilize during the interaction.

*Example: HTTP client opting into extensions using headers:*
```http
POST /v1/message:send HTTP/1.1
Host: agent.example.com
Content-Type: application/json
Authorization: Bearer token
A2A-Extensions: https://example.com/extensions/geolocation/v1,https://standards.org/extensions/citations/v1

{
  "message": {
    "role": "user",
    "parts": [{"text": "Find restaurants near me"}],
    "extensions": ["https://example.com/extensions/geolocation/v1"],
    "metadata": {
      "https://example.com/extensions/geolocation/v1": {
        "latitude": 37.7749,
        "longitude": -122.4194
      }
    }
  }
}
```

#### 4.6.2. Extensions Points

Extensions can be integrated into the A2A protocol at several well-defined extension points:

**Message Extensions:**

Messages can be extended to allow clients to provide additional strongly typed context or parameters relevant to the message being sent, or TaskStatus Messages to include extra information about the task's progress.

*Example: A location extension using the extensions and metadata arrays:*
```json
{
  "role": "user",
  "parts": [
    {"text": "Find restaurants near me"}
  ],
  "extensions": ["https://example.com/extensions/geolocation/v1"],
  "metadata": {
    "https://example.com/extensions/geolocation/v1": {
      "latitude": 37.7749,
      "longitude": -122.4194,
      "accuracy": 10.0,
      "timestamp": "2025-10-21T14:30:00Z"
    }
  }
}
```

**Artifact Extensions:**

Artifacts can include extension data to provide strongly typed context or metadata about the generated content.

*Example: An artifact with citation extension for research sources:*
```json
{
  "artifactId": "research-summary-001",
  "name": "Climate Change Summary",
  "parts": [
    {
      "text": "Global temperatures have risen by 1.1°C since pre-industrial times, with significant impacts on weather patterns and sea levels."
    }
  ],
  "extensions": ["https://standards.org/extensions/citations/v1"],
  "metadata": {
    "https://standards.org/extensions/citations/v1": {
      "sources": [
        {
          "title": "Global Temperature Anomalies - 2023 Report",
          "authors": ["Smith, J.", "Johnson, M."],
          "url": "https://climate.gov/reports/2023-temperature",
          "accessDate": "2025-10-21",
          "relevantText": "Global temperatures have risen by 1.1°C"
        }
      ]
    }
  }
}
```

#### 4.6.3. Extension Versioning and Compatibility

Extensions **SHOULD** include version information in their URI identifier. This allows clients and agents to negotiate compatible versions of extensions during interactions. A new URI **MUST** be created for breaking changes to an extension.

If a client requests a versions of an extension that the agent does not support, the agent **SHOULD** ignore the extension for that interaction and proceed without it, unless the extension is marked as `required` in the AgentCard, in which case the agent **MUST** return an error indicating unsupported extension. It **MUST NOT** fall back to a previous version of the extension automatically.

## 5. Protocol Binding Requirements and Interoperability

### 5.1. Functional Equivalence Requirements

When an agent supports multiple protocols, all supported protocols **MUST**:

- **Identical Functionality**: Provide the same set of operations and capabilities
- **Consistent Behavior**: Return semantically equivalent results for the same requests
- **Same Error Handling**: Map errors consistently using appropriate protocol-specific codes
- **Equivalent Authentication**: Support the same authentication schemes declared in the AgentCard

### 5.2. Protocol Selection and Negotiation

- **Agent Declaration**: Agents **MUST** declare all supported protocols in their AgentCard
- **Client Choice**: Clients **MAY** choose any protocol declared by the agent
- **No Dynamic Negotiation**: A2A does not define runtime protocol negotiation
- **Fallback Behavior**: Clients **SHOULD** implement fallback logic for alternative protocols

### 5.3. Method Mapping Reference

| Functionality                        | JSON-RPC Method                          | gRPC Method                          | REST Endpoint                                        |
| :----------------------------------- | :--------------------------------------- | :----------------------------------- | :--------------------------------------------------- |
| Send message                         | `message/send`                           | `SendMessage`                        | `POST /v1/message:send`                              |
| Stream message                       | `message/stream`                         | `SendStreamingMessage`               | `POST /v1/message:stream`                            |
| Get task                             | `tasks/get`                              | `GetTask`                            | `GET /v1/tasks/{id}`                                 |
| List tasks                           | `tasks/list`                             | `ListTasks`                          | `GET /v1/tasks`                                      |
| Cancel task                          | `tasks/cancel`                           | `CancelTask`                         | `POST /v1/tasks/{id}:cancel`                         |
| Resubscribe to task                  | `tasks/resubscribe`                      | `TaskResubscription`                 | `POST /v1/tasks/{id}:resubscribe`                    |
| Set push notification config         | `tasks/pushNotificationConfig/set`       | `SetTaskPushNotificationConfig`      | `POST /v1/tasks/{id}/pushNotificationConfigs`        |
| Get push notification config         | `tasks/pushNotificationConfig/get`       | `GetTaskPushNotificationConfig`      | `GET /v1/tasks/{id}/pushNotificationConfigs/{configId}` |
| List push notification configs       | `tasks/pushNotificationConfig/list`      | `ListTaskPushNotificationConfig`     | `GET /v1/tasks/{id}/pushNotificationConfigs`         |
| Delete push notification config      | `tasks/pushNotificationConfig/delete`    | `DeleteTaskPushNotificationConfig`   | `DELETE /v1/tasks/{id}/pushNotificationConfigs/{configId}` |
| Get extended Agent Card | `agent/getExtendedAgentCard`     | `GetExtendedAgentCard`               | `GET /v1/extendedAgentCard`                          |

### 5.4. JSON Field Naming Convention

All JSON serializations of the A2A protocol data model **MUST** use **camelCase** naming for field names, not the snake_case convention used in Protocol Buffer definitions.

**Naming Convention:**

- Protocol Buffer field: `protocol_version` → JSON field: `protocolVersion`
- Protocol Buffer field: `context_id` → JSON field: `contextId`
- Protocol Buffer field: `default_input_modes` → JSON field: `defaultInputModes`
- Protocol Buffer field: `push_notification_config` → JSON field: `pushNotificationConfig`

** Enum Values:**

- Enum values **MUST** be represented as their string names in JSON, using lower kebab-case after removing any type name prefixes.

**Examples:**

- Protocol Buffer enum: `TASK_STATE_INPUT_REQUIRED` → JSON value: `input-required`
- Protocol Buffer enum: `ROLE_USER` → JSON value: `user`

### 5.5. Data Type Conventions

This section documents conventions for common data types used throughout the A2A protocol, particularly as they apply to protocol bindings.

#### 5.5.1. Timestamps

The A2A protocol uses [`google.protobuf.Timestamp`](https://protobuf.dev/reference/protobuf/google.protobuf/#timestamp) for all timestamp fields in the Protocol Buffer definitions. When serialized to JSON (in JSON-RPC, HTTP/REST, or other JSON-based bindings), these timestamps **MUST** be represented as ISO 8601 formatted strings in UTC timezone.

**Format Requirements:**

- **Format:** ISO 8601 combined date and time representation
- **Timezone:** UTC (denoted by 'Z' suffix)
- **Precision:** Millisecond precision **SHOULD** be used where available
- **Pattern:** `YYYY-MM-DDTHH:mm:ss.sssZ`

**Examples:**

```json
{
  "timestamp": "2025-10-28T10:30:00.000Z",
  "createdAt": "2025-10-28T14:25:33.142Z",
  "lastModified": "2025-10-31T17:45:22.891Z"
}
```

**Implementation Notes:**

- Protocol Buffer's `google.protobuf.Timestamp` represents time as seconds since Unix epoch (January 1, 1970, 00:00:00 UTC) plus nanoseconds
- JSON serialization automatically converts this to ISO 8601 format when using standard Protocol Buffer JSON encoding
- Clients and servers **MUST** parse and generate ISO 8601 timestamps correctly
- When millisecond precision is not available, the fractional seconds portion **MAY** be omitted or zero-filled
- Timestamps **MUST NOT** include timezone offsets other than 'Z' (all times are UTC)

## 6. Common Workflows & Examples

This section provides illustrative examples of common A2A interactions across different bindings.

### 6.1. Basic Task Execution

**Scenario:** Client asks a question and receives a completed task response.

#### HTTP Example

**Request:**
```http
POST /v1/message:send HTTP/1.1
Host: agent.example.com
Content-Type: application/json
Authorization: Bearer token

{
  "message": {
    "role": "user",
    "parts": [{"text": "What is the weather today?"}],
    "messageId": "msg-uuid"
  }
}
```

**Response:**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "task": {
    "id": "task-uuid",
    "contextId": "context-uuid",
    "status": {"state": "completed"},
    "artifacts": [{
      "artifactId": "artifact-uuid",
      "name": "Weather Report",
      "parts": [{"text": "Today will be sunny with a high of 75°F"}]
    }]
  }
}
```

### 6.2. Streaming Task Execution

**Scenario:** Client requests a long-running task with real-time updates.

#### HTTP SSE Example

**Request:**
```http
POST /v1/message:stream HTTP/1.1
Host: agent.example.com
Content-Type: application/json
Authorization: Bearer token

{
  "message": {
    "role": "user",
    "parts": [{"text": "Write a detailed report on climate change"}],
    "messageId": "msg-uuid"
  }
}
```

**SSE Response Stream:**
```http
HTTP/1.1 200 OK
Content-Type: text/event-stream

data: {"task": {"id": "task-uuid", "status": {"state": "working"}}}

data: {"artifactUpdate": {"taskId": "task-uuid", "artifact": {"parts": [{"text": "# Climate Change Report\n\n"}]}}}

data: {"statusUpdate": {"taskId": "task-uuid", "status": {"state": "completed"}, "final": true}}
```

### 6.3. Multi-Turn Interaction

**Scenario:** Agent requires additional input to complete a task.

**Initial Request:**
```http
POST /v1/message:send HTTP/1.1
Host: agent.example.com
Content-Type: application/json
Authorization: Bearer token

{
  "message": {
    "role": "user",
    "parts": [{"text": "Book me a flight"}],
    "messageId": "msg-1"
  }
}
```

**Response (Input Required):**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "task": {
    "id": "task-uuid",
    "status": {
      "state": "input-required",
      "message": {
        "role": "agent",
        "parts": [{"text": "I need more details. Where would you like to fly from and to?"}]
      }
    }
  }
}
```

**Follow-up Request:**
```http
POST /v1/message:send HTTP/1.1
Host: agent.example.com
Content-Type: application/json
Authorization: Bearer token

{
  "message": {
    "taskId": "task-uuid",
    "role": "user",
    "parts": [{"text": "From San Francisco to New York"}],
    "messageId": "msg-2"
  }
}
```

### 6.4. Version Negotiation Error

**Scenario:** Client requests an unsupported protocol version.

**Request:**
```http
POST /v1/message:send HTTP/1.1
Host: agent.example.com
Content-Type: application/json
Authorization: Bearer token
A2A-Version: 0.5

{
  "message": {
    "role": "user",
    "parts": [{"text": "Hello"}],
    "messageId": "msg-uuid"
  }
}
```

**Response:**
```http
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "type": "https://a2a-protocol.org/errors/version-not-supported",
  "title": "Protocol Version Not Supported",
  "status": 400,
  "detail": "The requested A2A protocol version 0.5 is not supported by this agent",
  "supportedVersions": ["0.3"]
}
```

## 7. Authentication and Authorization

A2A treats agents as standard enterprise applications, relying on established web security practices. Identity information is handled at the protocol layer, not within A2A semantics.

For a comprehensive guide on enterprise security aspects, see [Enterprise-Ready Features](./topics/enterprise-ready.md).

### 7.1. Protocol Security

Production deployments **MUST** use encrypted communication (HTTPS for HTTP-based bindings, TLS for gRPC). Implementations **SHOULD** use modern TLS configurations (TLS 1.3+ recommended) with strong cipher suites.

### 7.2. Server Identity Verification

A2A Clients **SHOULD** verify the A2A Server's identity by validating its TLS certificate against trusted certificate authorities (CAs) during the TLS handshake.

### 7.3. Client Authentication Process

1. **Discovery of Requirements:** The client discovers the server's required authentication schemes via the `security_schemes` field in the AgentCard.
2. **Credential Acquisition (Out-of-Band):** The client obtains the necessary credentials through an out-of-band process specific to the required authentication scheme.
3. **Credential Transmission:** The client includes these credentials in protocol-appropriate headers or metadata for every A2A request.

### 7.4. Server Authentication Responsibilities

The A2A Server:

- **MUST** authenticate every incoming request based on the provided credentials and its declared authentication requirements.
- **SHOULD** use appropriate binding-specific error codes for authentication challenges or rejections.
- **SHOULD** provide relevant authentication challenge information with error responses.

### 7.5. In-Task Authentication (Secondary Credentials)

If an agent requires additional credentials during task execution:

1. It **SHOULD** transition the A2A task to the `TASK_STATE_AUTH_REQUIRED` state.
2. The accompanying `TaskStatus.update` **SHOULD** provide details about the required secondary authentication.
3. The A2A Client obtains these credentials out-of-band and provides them in a subsequent message request.

### 7.6. Authorization

Once authenticated, the A2A Server authorizes requests based on the authenticated identity and its own policies. Authorization logic is implementation-specific and **MAY** consider:

- Specific skills requested
- Actions attempted within tasks
- Data access policies
- OAuth scopes (if applicable)

### 7.7. Security Considerations

This section consolidates security guidance and best practices for implementing and operating A2A agents. For additional enterprise security considerations, see [Enterprise-Ready Features](./topics/enterprise-ready.md).

#### 7.7.1. Data Access and Authorization Scoping

Implementations **MUST** ensure appropriate scope limitation based on the authenticated caller's authorization boundaries. This applies to all operations that access or list tasks and other resources.

**Authorization Principles:**

- Servers **MUST** implement authorization checks on every [A2A Protocol Operations](#3-a2a-protocol-operations) request
- Implementations **MUST** scope results to the caller's authorized access boundaries as defined by the agent's authorization model
- Even when `contextId` or other filter parameters are not specified in requests, implementations **MUST** scope results to the caller's authorized access boundaries
- Authorization models are agent-defined and **MAY** be based on:
    - User identity (user-based authorization)
    - Organizational roles or groups (role-based authorization)
    - Project or workspace membership (project-based authorization)
    - Organizational or tenant boundaries (multi-tenant authorization)
    - Custom authorization logic specific to the agent's domain

**Operations Requiring Scope Limitation:**

- [`List Tasks`](#314-list-tasks): **MUST** only return tasks visible to the authenticated client according to the agent's authorization model
- [`Get Task`](#313-get-task): **MUST** verify the authenticated client has access to the requested task according to the agent's authorization model
- Task-related operations (Cancel, Resubscribe, Push Notification Config): **MUST** verify the client has appropriate access rights according to the agent's authorization model

**Implementation Requirements:**

- Authorization boundaries are defined by each agent's authorization model, not prescribed by the protocol
- Authorization checks **MUST** occur before any database queries or operations that could leak information about the existence of resources outside the caller's authorization scope
- Agents **SHOULD** document their authorization model and access control policies

See also: [Section 3.1.4 List Tasks (Security Note)](#314-list-tasks) for operation-specific requirements.

#### 7.7.2. Push Notification Security

When implementing push notifications, both agents (as webhook callers) and clients (as webhook receivers) have security responsibilities.

**Agent (Webhook Caller) Requirements:**

- Agents **MUST** include authentication credentials in webhook requests as specified in [`PushNotificationConfig.authentication`](#433-authenticationinfo)
- Agents **SHOULD** implement reasonable timeout values for webhook requests (recommended: 10-30 seconds)
- Agents **SHOULD** implement retry logic with exponential backoff for failed deliveries
- Agents **MAY** stop attempting delivery after a configured number of consecutive failures
- Agents **SHOULD** validate webhook URLs to prevent SSRF (Server-Side Request Forgery) attacks:
    - Reject private IP ranges (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
    - Reject localhost and link-local addresses
    - Implement URL allowlists where appropriate

**Client (Webhook Receiver) Requirements:**

- Clients **MUST** validate webhook authenticity using the provided authentication credentials
- Clients **SHOULD** verify the task ID in the payload matches an expected task they created
- Clients **MUST** respond with HTTP 2xx status codes to acknowledge successful receipt
- Clients **SHOULD** process notifications idempotently, as duplicate deliveries may occur
- Clients **SHOULD** implement rate limiting to prevent webhook flooding
- Clients **SHOULD** use HTTPS endpoints for webhook URLs to ensure confidentiality

**Configuration Security:**

- Webhook URLs **SHOULD** use HTTPS to protect payload confidentiality in transit
- Authentication tokens in [`PushNotificationConfig`](#431-pushnotificationconfig) **SHOULD** be treated as secrets and rotated periodically
- Agents **SHOULD** securely store push notification configurations and credentials
- Clients **SHOULD** use unique, single-purpose tokens for each push notification configuration

See also: [Section 4.3 Push Notification Objects](#43-push-notification-objects) and [Section 4.3.4 Push Notification Payload](#434-push-notification-payload).

#### 7.7.3. Extended Agent Card Access Control

The extended Agent Card feature allows agents to provide additional capabilities or information to authenticated clients beyond what is available in the public Agent Card.

**Access Control Requirements:**

- The [`Get Extended Agent Card`](#3111-get-extended-agent-card) operation **MUST** require authentication
- Agents **MUST** authenticate requests using one of the schemes declared in the public `AgentCard.securitySchemes` and `AgentCard.security` fields
- Agents **MAY** return different extended card content based on the authenticated client's identity or authorization level
- Agents **SHOULD** implement appropriate caching headers to control client-side caching of extended cards

**Capability-Based Access:**

- Extended cards **MAY** include additional skills not present in the public card
- Extended cards **MAY** expose more detailed capability information (e.g., rate limits, quotas)
- Extended cards **MAY** include organization-specific or user-specific configuration
- Agents **SHOULD** document which capabilities are available at different authentication levels

**Security Considerations:**

- Extended cards **SHOULD NOT** include sensitive information that could be exploited if leaked (e.g., internal service URLs, unmasked credentials)
- Agents **MUST** validate that clients have appropriate permissions before returning privileged information in extended cards
- Clients retrieving extended cards **SHOULD** replace their cached public Agent Card with the extended version for the duration of their authenticated session
- Agents **SHOULD** version extended cards appropriately and honor client cache invalidation

**Availability Declaration:**

- Agents declare extended card support via `AgentCard.supportsAuthenticatedExtendedCard`
- When `supportsAuthenticatedExtendedCard` is `false` or not present, the operation **MUST** return [`UnsupportedOperationError`](#332-error-handling)
- When support is declared but no extended card is configured, the operation **MUST** return [`ExtendedAgentCardNotConfiguredError`](#332-error-handling)

See also: [Section 3.1.11 Get Extended Agent Card](#3111-get-extended-agent-card) and [Section 3.3.4 Capability Validation](#334-capability-validation).

#### 7.7.4. General Security Best Practices

**Transport Security:**

- Production deployments **MUST** use encrypted communication (HTTPS for HTTP-based bindings, TLS for gRPC)
- Implementations **SHOULD** use modern TLS configurations (TLS 1.3+ recommended) with strong cipher suites
- Agents **SHOULD** enforce HSTS (HTTP Strict Transport Security) headers when using HTTP-based bindings
- Implementations **SHOULD** disable support for deprecated SSL/TLS versions (SSLv3, TLS 1.0, TLS 1.1)

**Input Validation:**

- Agents **MUST** validate all input parameters before processing
- Agents **SHOULD** implement appropriate limits on message sizes, file sizes, and request complexity
- Agents **SHOULD** sanitize or validate file content types and reject unexpected MIME types

**Credential Management:**

- API keys, tokens, and other credentials **MUST** be treated as secrets
- Credentials **SHOULD** be rotated periodically
- Credentials **SHOULD** be transmitted only over encrypted connections
- Agents **SHOULD** implement credential revocation mechanisms
- Agents **SHOULD** log authentication failures and implement rate limiting to prevent brute-force attacks

**Audit and Monitoring:**

- Agents **SHOULD** log security-relevant events (authentication failures, authorization denials, suspicious requests)
- Agents **SHOULD** implement monitoring for unusual patterns (rapid task creation, excessive cancellations)
- Agents **SHOULD** provide audit trails for sensitive operations
- Logs **MUST NOT** include sensitive information (credentials, personal data) unless required and properly protected

**Rate Limiting and Abuse Prevention:**

- Agents **SHOULD** implement rate limiting on all operations
- Agents **SHOULD** return appropriate error responses when rate limits are exceeded
- Agents **MAY** implement different rate limits for different operations or user tiers

**Data Privacy:**

- Agents **MUST** comply with applicable data protection regulations
- Agents **SHOULD** provide mechanisms for users to request deletion of their data
- Agents **SHOULD** implement appropriate data retention policies
- Agents **SHOULD** minimize logging of sensitive or personal information

**Custom Binding Security:**

- Custom protocol bindings **MUST** address security considerations in their specification
- Custom bindings **SHOULD** follow the same security principles as standard bindings
- Custom bindings **MUST** document authentication integration and credential transmission

See also: [Section 12.6 Authentication and Authorization (Custom Bindings)](#126-authentication-and-authorization).

## 8. Agent Discovery: The Agent Card

### 8.1. Purpose

A2A Servers **MUST** make an Agent Card available. The Agent Card describes the server's identity, capabilities, skills, and interaction requirements. Clients use this information for discovering suitable agents and configuring interactions.

For more on discovery strategies, see the [Agent Discovery guide](./topics/agent-discovery.md).

### 8.2. Discovery Mechanisms

Clients can find Agent Cards through:

- **Well-Known URI:** Accessing `https://{server_domain}/.well-known/agent-card.json`
- **Registries/Catalogs:** Querying curated catalogs of agents
- **Direct Configuration:** Pre-configured Agent Card URLs or content

### 8.3. Protocol Declaration Requirements

The AgentCard **MUST** properly declare supported protocols:

#### 8.3.1. Primary Interface Declaration

- The `url` field **MUST** specify the primary endpoint
- The `preferred_transport` field **MUST** match the binding available at the primary URL
- The primary URL **MUST** support the declared preferred binding

#### 8.3.2. Additional Interfaces

- `additional_interfaces` **SHOULD** declare all supported protocol combinations
- Each interface **MUST** accurately declare its protocol binding
- URLs **MAY** be reused if multiple protocols are available at the same endpoint

#### 8.3.3. Client Protocol Selection

Clients **MUST** follow these rules:

1. Parse available protocols from the AgentCard
2. Prefer the `preferred_transport` if supported
3. Fall back to any supported protocol from `additional_interfaces`
4. Use the correct URL for the selected protocol

### 8.4. Agent Card Signing

Agent Cards **MAY** be digitally signed using JSON Web Signature (JWS) as defined in [RFC 7515](https://tools.ietf.org/html/rfc7515) to ensure authenticity and integrity. Signatures allow clients to verify that an Agent Card has not been tampered with and originates from the claimed provider.

#### 8.4.1. Canonicalization Requirements

Before signing, the Agent Card content **MUST** be canonicalized using the JSON Canonicalization Scheme (JCS) as defined in [RFC 8785](https://tools.ietf.org/html/rfc8785). This ensures consistent signature generation and verification across different JSON implementations.

**Canonicalization Rules:**

1. **RFC 8785 Compliance**: The Agent Card JSON **MUST** be canonicalized according to RFC 8785, which specifies:
   - Predictable ordering of object properties (lexicographic by key)
   - Consistent representation of numbers, strings, and other primitive values
   - Removal of insignificant whitespace

2. **Default Value Omission**: Before canonicalization, all properties with default values **MUST** be omitted from the JSON object. This includes:
   - Properties set to their default values as defined in the Protocol Buffer schema
   - Empty arrays (`[]`)
   - Empty strings (`""`)
   - Properties with `null` values
   - Optional properties that are not explicitly set

3. **Signature Field Exclusion**: The `signatures` field itself **MUST** be excluded from the content being signed to avoid circular dependencies.

**Example of Default Value Removal:**

Original Agent Card fragment:
```json
{
  "name": "Example Agent",
  "description": "",
  "capabilities": {
    "streaming": false,
    "pushNotifications": false,
    "extensions": []
  },
  "skills": []  // It is not currently clear is skills is optional or required
}
```

After removing default/empty values:
```json
{
  "name": "Example Agent",
  "capabilities": {}
}
```

#### 8.4.2. Signature Format

Signatures **MUST** use the JWS Compact Serialization or JWS JSON Serialization format. The [`AgentCardSignature`](#447-agentcardsignature) object contains the signature components.

**Required JWS Header Parameters:**

- `alg`: Algorithm used for signing (e.g., "ES256", "RS256")
- `typ`: **SHOULD** be set to "JOSE" for JWS
- `kid`: Key ID for identifying the signing key
- `jku` (optional): URL to JSON Web Key Set (JWKS) containing the public key

**Example Signature Generation Process:**

1. Remove properties with default values from the Agent Card
2. Exclude the `signatures` field
3. Canonicalize the resulting JSON using RFC 8785
4. Create JWS protected header with `alg`, `typ`, `kid`, and optionally `jku`
5. Sign the canonicalized payload using the private key
6. Encode the signature components

#### 8.4.3. Signature Verification

Clients verifying Agent Card signatures **MUST**:

1. Extract the signature from the `signatures` array
2. Retrieve the public key using the `kid` and `jku` (or from a trusted key store)
3. Remove properties with default values from the received Agent Card
4. Exclude the `signatures` field
5. Canonicalize the resulting JSON using RFC 8785
6. Verify the signature against the canonicalized payload

**Security Considerations:**

- Clients **SHOULD** verify at least one signature before trusting an Agent Card
- Public keys **SHOULD** be retrieved over secure channels (HTTPS)
- Clients **MAY** maintain a trusted key store for known agent providers
- Expired or revoked keys **MUST NOT** be used for verification
- Multiple signatures **MAY** be present to support key rotation

### 8.5. Sample Agent Card

```json
{
  "protocolVersion": "0.3.0",
  "name": "GeoSpatial Route Planner Agent",
  "description": "Provides advanced route planning, traffic analysis, and custom map generation services. This agent can calculate optimal routes, estimate travel times considering real-time traffic, and create personalized maps with points of interest.",
  "url": "https://georoute-agent.example.com/a2a/v1",
  "preferredTransport": "JSONRPC",
  "additionalInterfaces" : [
    {"url": "https://georoute-agent.example.com/a2a/v1", "transport": "JSONRPC"},
    {"url": "https://georoute-agent.example.com/a2a/grpc", "transport": "GRPC"},
    {"url": "https://georoute-agent.example.com/a2a/json", "transport": "HTTP+JSON"}
  ],
  "provider": {
    "organization": "Example Geo Services Inc.",
    "url": "https://www.examplegeoservices.com"
  },
  "iconUrl": "https://georoute-agent.example.com/icon.png",
  "version": "1.2.0",
  "documentationUrl": "https://docs.examplegeoservices.com/georoute-agent/api",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true,
    "stateTransitionHistory": false
  },
  "securitySchemes": {
    "google": {
      "type": "openIdConnect",
      "openIdConnectUrl": "https://accounts.google.com/.well-known/openid-configuration"
    }
  },
  "security": [{ "google": ["openid", "profile", "email"] }],
  "defaultInputModes": ["application/json", "text/plain"],
  "defaultOutputModes": ["application/json", "image/png"],
  "skills": [
    {
      "id": "route-optimizer-traffic",
      "name": "Traffic-Aware Route Optimizer",
      "description": "Calculates the optimal driving route between two or more locations, taking into account real-time traffic conditions, road closures, and user preferences (e.g., avoid tolls, prefer highways).",
      "tags": ["maps", "routing", "navigation", "directions", "traffic"],
      "examples": [
        "Plan a route from '1600 Amphitheatre Parkway, Mountain View, CA' to 'San Francisco International Airport' avoiding tolls.",
        "{\"origin\": {\"lat\": 37.422, \"lng\": -122.084}, \"destination\": {\"lat\": 37.7749, \"lng\": -122.4194}, \"preferences\": [\"avoid_ferries\"]}"
      ],
      "inputModes": ["application/json", "text/plain"],
      "outputModes": [
        "application/json",
        "application/vnd.geo+json",
        "text/html"
      ]
    },
    {
      "id": "custom-map-generator",
      "name": "Personalized Map Generator",
      "description": "Creates custom map images or interactive map views based on user-defined points of interest, routes, and style preferences. Can overlay data layers.",
      "tags": ["maps", "customization", "visualization", "cartography"],
      "examples": [
        "Generate a map of my upcoming road trip with all planned stops highlighted.",
        "Show me a map visualizing all coffee shops within a 1-mile radius of my current location."
      ],
      "inputModes": ["application/json"],
      "outputModes": [
        "image/png",
        "image/jpeg",
        "application/json",
        "text/html"
      ]
    }
  ],
  "supportsAuthenticatedExtendedCard": true,
  "signatures": [
    {
      "protected": "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpPU0UiLCJraWQiOiJrZXktMSIsImprdSI6Imh0dHBzOi8vZXhhbXBsZS5jb20vYWdlbnQvandrcy5qc29uIn0",
      "signature": "QFdkNLNszlGj3z3u0YQGt_T9LixY3qtdQpZmsTdDHDe3fXV9y9-B3m2-XgCpzuhiLt8E0tV6HXoZKHv4GtHgKQ"
    }
  ]
}
```

## 9. JSON-RPC Protocol Binding

The JSON-RPC protocol binding provides a simple, HTTP-based interface using JSON-RPC 2.0 for method calls and Server-Sent Events for streaming.

### 9.1. Protocol Requirements

- **Protocol:** JSON-RPC 2.0 over HTTP(S)
- **Content-Type:** `application/json` for requests and responses
- **Method Naming:** `{category}/{action}` pattern (e.g., `message/send`, `tasks/get`)
- **Streaming:** Server-Sent Events (`text/event-stream`)

### 9.2. Service Parameter Transmission

A2A service parameters defined in [Section 3.2.5](#325-service-parameters) **MUST** be transmitted using standard HTTP request headers, as JSON-RPC 2.0 operates over HTTP(S).

**Service Parameter Requirements:**

- Service parameter names **MUST** be transmitted as HTTP header fields
- Service parameter keys are case-insensitive per HTTP specification (RFC 7230)
- Multiple values for the same service parameter (e.g., `A2A-Extensions`) **SHOULD** be comma-separated in a single header field

**Example Request with A2A Service Parameters:**

```http
POST /rpc HTTP/1.1
Host: agent.example.com
Content-Type: application/json
Authorization: Bearer token
A2A-Version: 0.3
A2A-Extensions: https://example.com/extensions/geolocation/v1,https://standards.org/extensions/citations/v1

{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "message/send",
  "params": { /* SendMessageRequest */ }
}
```

### 9.3. Base Request Structure

All JSON-RPC requests **MUST** follow the standard JSON-RPC 2.0 format:

```json
{
  "jsonrpc": "2.0",
  "id": "unique-request-id",
  "method": "category/action",
  "params": { /* method-specific parameters */ }
}
```

### 9.4. Core Methods

#### 9.4.1. `message/send`

Sends a message to initiate or continue a task.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "message/send",
  "params": { /* SendMessageRequest object */ }
}
```

**Referenced Objects:** [`SendMessageRequest`](#321-sendmessagerequest), [`Message`](#414-message)

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": { /* Task or Message object */ }
}
```

**Referenced Objects:** [`Task`](#411-task), [`Message`](#414-message)

#### 9.4.2. `message/stream`

Sends a message and subscribes to real-time updates via Server-Sent Events.

**Request:** Same as `message/send`

**Response:** HTTP 200 with `Content-Type: text/event-stream`
```
data: {"jsonrpc": "2.0", "id": 1, "result": { /* Task | Message | TaskArtifactUpdateEvent | TaskStatusUpdateEvent */ }}

data: {"jsonrpc": "2.0", "id": 1, "result": { /* Task | Message | TaskArtifactUpdateEvent | TaskStatusUpdateEvent */ }}
```

Referenced Objects: [`Task`](#411-task), [`Message`](#414-message), [`TaskArtifactUpdateEvent`](#422-taskartifactupdateevent), [`TaskStatusUpdateEvent`](#421-taskstatusupdateevent)

#### 9.4.3. `tasks/get`

Retrieves the current state of a task.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tasks/get",
  "params": {
    "id": "task-uuid",
    "historyLength": 10
  }
}
```

#### 9.4.4. `tasks/list`

Lists tasks with optional filtering and pagination.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tasks/list",
  "params": {
    "contextId": "context-uuid",
    "status": "working",
    "pageSize": 50,
    "pageToken": "cursor-token"
  }
}
```

#### 9.4.5. `tasks/cancel`

Cancels an ongoing task.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tasks/cancel",
  "params": {
    "id": "task-uuid"
  }
}
```

#### 9.4.6. `tasks/resubscribe`
<span id="936-tasksresubscribe"></span>

Reconnects to an SSE stream for an ongoing task.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "tasks/resubscribe",
  "params": {
    "id": "task-uuid"
  }
}
```

**Response:** SSE stream (same format as `message/stream`)

#### 9.4.7. Push Notification Configuration Methods

- `tasks/pushNotificationConfig/set` - Set push notification configuration
- `tasks/pushNotificationConfig/get` - Get push notification configuration
- `tasks/pushNotificationConfig/list` - List push notification configurations
- `tasks/pushNotificationConfig/delete` - Delete push notification configuration

#### 9.4.8. `agent/getExtendedAgentCard`

Retrieves an extended Agent Card.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "agent/getExtendedAgentCard"
}
```

### 9.5. Error Handling

A2A uses standard [JSON-RPC 2.0 error handling](https://www.jsonrpc.org/specification#error_object) with additional A2A-specific error codes. The JSON-RPC error structure maps to the generic error model defined in [Section 3.2.2](#332-error-handling) as follows:

- **Error Code**: Mapped to the `error.code` field (numeric JSON-RPC error code)
- **Error Message**: Mapped to the `error.message` field (human-readable string)
- **Error Details**: Mapped to the `error.data` field (optional structured object)

**Standard JSON-RPC Error Codes:**

| JSON-RPC Error Code | Error Name            | Standard Message                        | Description                                           |
| :------------------ | :-------------------- | :-------------------------------------- | :---------------------------------------------------- |
| `-32700`            | `JSONParseError`      | "Invalid JSON payload"                  | The server received invalid JSON                      |
| `-32600`            | `InvalidRequestError` | "Request payload validation error"      | The JSON sent is not a valid Request object          |
| `-32601`            | `MethodNotFoundError` | "Method not found"                      | The requested method does not exist or is not available |
| `-32602`            | `InvalidParamsError`  | "Invalid parameters"                    | The method parameters are invalid                     |
| `-32603`            | `InternalError`       | "Internal error"                        | An internal error occurred on the server             |

**A2A-Specific Error Codes:**

| A2A Error Type                      | JSON-RPC Error Code | Standard Message                                 | Description                                          |
| :---------------------------------- | :------------------ | :----------------------------------------------- | :--------------------------------------------------- |
| `TaskNotFoundError`                 | `-32001`            | "Task not found"                                 | The specified task ID does not exist or is not accessible |
| `TaskNotCancelableError`            | `-32002`            | "Task cannot be canceled"                        | Task is not in a cancelable state                   |
| `PushNotificationNotSupportedError` | `-32003`            | "Push Notification is not supported"             | Agent does not support push notifications           |
| `UnsupportedOperationError`         | `-32004`            | "This operation is not supported"                | The requested operation is not supported             |
| `ContentTypeNotSupportedError`      | `-32005`            | "Incompatible content types"                     | Content type is not supported by the agent          |
| `InvalidAgentResponseError`         | `-32006`            | "Invalid agent response"                         | Agent response does not conform to specification     |
| `ExtendedAgentCardNotConfiguredError` | `-32007` | "Extended Agent Card is not configured" | Agent does not have extended agent card configured |
| `ExtensionSupportRequiredError`     | `-32008`            | "Required extension not supported by client"     | Client must support required extension              |
| `VersionNotSupportedError`          | `-32009`            | "Protocol version not supported"                 | The A2A protocol version is not supported            |

**Example Standard JSON-RPC Error Response:**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32601,
    "message": "Method not found",
    "data": {
      "method": "invalid/method"
    }
  }
}
```

**Example A2A-Specific Error Response:**

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "error": {
    "code": -32001,
    "message": "Task not found",
    "data": {
      "taskId": "nonexistent-task-id"
    }
  }
}
```

## 10. gRPC Protocol Binding

The gRPC Protocol Binding provides a high-performance, strongly-typed interface using Protocol Buffers over HTTP/2. The gRPC Protocol Binding leverages the [API guidelines](https://google.aip.dev/general) to simplify gRPC to HTTP mapping.

### 10.1. Protocol Requirements

- **Protocol:** gRPC over HTTP/2 with TLS
- **Definition:** Use the normative Protocol Buffers definition in `specification/grpc/a2a.proto`
- **Serialization:** Protocol Buffers version 3
- **Service:** Implement the `A2AService` gRPC service

### 10.2. Service Parameter Transmission

A2A service parameters defined in [Section 3.2.5](#325-service-parameters) **MUST** be transmitted using gRPC metadata (headers).

**Service Parameter Requirements:**

- Service parameter names **MUST** be transmitted as gRPC metadata keys
- Metadata keys are case-insensitive and automatically converted to lowercase by gRPC
- Multiple values for the same service parameter (e.g., `A2A-Extensions`) **SHOULD** be comma-separated in a single metadata entry

**Example gRPC Request with A2A Service Parameters:**

```go
// Go example using gRPC metadata
md := metadata.Pairs(
    "authorization", "Bearer token",
    "a2a-version", "0.3",
    "a2a-extensions", "https://example.com/extensions/geolocation/v1,https://standards.org/extensions/citations/v1",
)
ctx := metadata.NewOutgoingContext(context.Background(), md)

// Make the RPC call with the context containing metadata
response, err := client.SendMessage(ctx, request)
```

**Metadata Handling:**

- Implementations **MUST** extract A2A service parameters from gRPC metadata for processing
- Servers **SHOULD** validate required service parameters (e.g., `A2A-Version`) from metadata
- Service parameter keys in metadata are normalized to lowercase per gRPC conventions

### 10.3. Service Definition

```proto
service A2AService {
  rpc SendMessage(SendMessageRequest) returns (SendMessageResponse);
  rpc SendStreamingMessage(SendMessageRequest) returns (stream StreamResponse);
  rpc GetTask(GetTaskRequest) returns (Task);
  rpc ListTasks(ListTasksRequest) returns (ListTasksResponse);
  rpc CancelTask(CancelTaskRequest) returns (Task);
  rpc TaskResubscription(TaskResubscriptionRequest) returns (stream StreamResponse);
  rpc SetTaskPushNotificationConfig(SetTaskPushNotificationConfigRequest) returns (TaskPushNotificationConfig);
  rpc GetTaskPushNotificationConfig(GetTaskPushNotificationConfigRequest) returns (TaskPushNotificationConfig);
  rpc ListTaskPushNotificationConfig(ListTaskPushNotificationConfigRequest) returns (ListTaskPushNotificationConfigResponse);
  rpc DeleteTaskPushNotificationConfig(DeleteTaskPushNotificationConfigRequest) returns (google.protobuf.Empty);
  rpc GetExtendedAgentCard(GetExtendedAgentCardRequest) returns (AgentCard);
}
```

### 10.4. Core Methods

#### 10.4.1. SendMessage

Sends a message to an agent.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:SendMessageRequest"
```

**Response:**
```proto
--8<-- "specification/grpc/a2a.proto:SendMessageResponse"
```

#### 10.4.2. SendStreamingMessage

Sends a message with streaming updates.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:SendMessageRequest"
```

**Response:** Server streaming [`StreamResponse`](#stream-response) objects.

#### 10.4.3. GetTask

Retrieves task status.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:GetTaskRequest"
```

**Response:** See [`Task`](#411-task) object definition.

#### 10.4.4. ListTasks

Lists tasks with filtering.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:ListTasksRequest"
```

**Response:**
```proto
--8<-- "specification/grpc/a2a.proto:ListTasksResponse"
```

#### 10.4.5. CancelTask

Cancels a running task.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:CancelTaskRequest"
```

**Response:** See [`Task`](#411-task) object definition.

#### 10.4.6. TaskResubscription

Resubscribe to task updates via streaming.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:TaskResubscriptionRequest"
```

**Response:** Server streaming [`StreamResponse`](#stream-response) objects.

#### 10.4.7. SetTaskPushNotificationConfig

Creates a push notification configuration for a task.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:SetTaskPushNotificationConfigRequest"
```

**Response:** See [`TaskPushNotificationConfig`](#432-taskpushnotificationconfig) object definition.

#### 10.4.8. GetTaskPushNotificationConfig

Retrieves an existing push notification configuration for a task.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:GetTaskPushNotificationConfigRequest"
```

**Response:** See [`TaskPushNotificationConfig`](#432-taskpushnotificationconfig) object definition.

#### 10.4.9. ListTaskPushNotificationConfig

Lists all push notification configurations for a task.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:ListTaskPushNotificationConfigRequest"
```

**Response:**
```proto
--8<-- "specification/grpc/a2a.proto:ListTaskPushNotificationConfigResponse"
```

#### 10.4.10. DeleteTaskPushNotificationConfig

Removes a push notification configuration for a task.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:DeleteTaskPushNotificationConfigRequest"
```

**Response:** `google.protobuf.Empty`

#### 10.4.11. GetExtendedAgentCard

Retrieves the agent's extended capability card after authentication.

**Request:**
```proto
--8<-- "specification/grpc/a2a.proto:GetExtendedAgentCardRequest"
```

**Response:** See [`AgentCard`](#441-agentcard) object definition.

### 10.5. Error Handling

A2A gRPC leverages the API [error standard](https://google.aip.dev/193) for formatting errors. The gRPC error structure maps to the generic error model defined in [Section 3.2.2](#332-error-handling) as follows:

- **Error Code**: Mapped to the `status.code` field (gRPC status code enum)
- **Error Message**: Mapped to the `status.message` field (human-readable string)
- **Error Details**: Mapped to the `status.details` array (repeated structured error information)

For A2A-specific errors, the `google.rpc.ErrorInfo` type **MUST** be used within the `status.details` array to provide structured error information. The `reason` field in `ErrorInfo` **MUST** correspond to the A2A error type using uppercase snake_case without the "Error" suffix. The `domain` field **MUST** be set to `"a2a-protocol.org"`.

#### 10.4.1. A2A Error Mappings

| A2A Error Type                      | Description                      | gRPC Status Code      |
| :---------------------------------- | :------------------------------- | :-------------------- |
| `TaskNotFoundError`                 | Task ID not found                | `NOT_FOUND`           |
| `TaskNotCancelableError`            | Task not in cancelable state     | `FAILED_PRECONDITION` |
| `PushNotificationNotSupportedError` | Push notifications not supported | `UNIMPLEMENTED`       |
| `UnsupportedOperationError`         | Operation not supported          | `UNIMPLEMENTED`       |
| `ContentTypeNotSupportedError`      | Unsupported content type         | `INVALID_ARGUMENT`    |
| `InvalidAgentResponseError`         | Invalid agent response           | `INTERNAL`            |
| `ExtendedAgentCardNotConfiguredError` | Extended agent card not configured | `FAILED_PRECONDITION` |
| `ExtensionSupportRequiredError`     | Required extension not supported | `FAILED_PRECONDITION` |
| `VersionNotSupportedError`          | Protocol version not supported   | `UNIMPLEMENTED`       |

**Example Standard gRPC Error Response:**

```proto
// Standard gRPC invalid argument error
status {
  code: INVALID_ARGUMENT
  message: "Invalid request parameters"
  details: [
    {
      type: "type.googleapis.com/google.rpc.BadRequest"
      field_violations: [
        {
          field: "message.parts"
          description: "At least one part is required"
        }
      ]
    }
  ]
}
```

**Example A2A-Specific Error Response:**

```proto
// A2A-specific task not found error
status {
  code: NOT_FOUND
  message: "Task with ID 'task-123' not found"
  details: [
    {
      type: "type.googleapis.com/google.rpc.ErrorInfo"
      reason: "TASK_NOT_FOUND"
      domain: "a2a-protocol.org"
      metadata: {
        task_id: "task-123"
        timestamp: "2025-10-19T14:30:00Z"
      }
    }
  ]
}
```


### 10.6. Streaming

gRPC streaming uses server streaming RPCs for real-time updates. The `StreamResponse` message provides a union of possible streaming events:


```proto
--8<-- "specification/grpc/a2a.proto:StreamResponse"
```

## 11. HTTP+JSON/REST Protocol Binding

The HTTP+JSON protocol binding provides a RESTful interface using standard HTTP methods and JSON payloads.

### 11.1. Protocol Requirements

- **Protocol:** HTTP(S) with JSON payloads
- **Content-Type:** `application/json` for requests and responses
- **Methods:** Standard HTTP verbs (GET, POST, PUT, DELETE)
- **URL Patterns:** RESTful resource-based URLs
- **Streaming:** Server-Sent Events for real-time updates

### 11.2. Service Parameter Transmission

A2A service parameters defined in [Section 3.2.5](#325-service-parameters) **MUST** be transmitted using standard HTTP request headers.

**Service Parameter Requirements:**

- Service parameter names **MUST** be transmitted as HTTP header fields
- Service parameter keys are case-insensitive per HTTP specification (RFC 9110)
- Multiple values for the same service parameter (e.g., `A2A-Extensions`) **SHOULD** be comma-separated in a single header field

**Example Request with A2A Service Parameters:**

```http
POST /v1/message:send HTTP/1.1
Host: agent.example.com
Content-Type: application/json
Authorization: Bearer token
A2A-Version: 0.3
A2A-Extensions: https://example.com/extensions/geolocation/v1,https://standards.org/extensions/citations/v1

{
  "message": {
    "role": "user",
    "parts": [{"text": "Find restaurants near me"}]
  }
}
```

### 11.3. URL Patterns and HTTP Methods

#### 11.3.1. Message Operations

- `POST /v1/message:send` - Send message
- `POST /v1/message:stream` - Send message with streaming (SSE response)

#### 11.3.2. Task Operations

- `GET /v1/tasks/{id}` - Get task status
- `GET /v1/tasks` - List tasks (with query parameters)
- `POST /v1/tasks/{id}:cancel` - Cancel task
- `POST /v1/tasks/{id}:resubscribe` - Resubscribe to task updates (SSE response, streaming tasks only)

#### 11.3.3. Push Notification Configuration

- `POST /v1/tasks/{id}/pushNotificationConfigs` - Create configuration
- `GET /v1/tasks/{id}/pushNotificationConfigs/{configId}` - Get configuration
- `GET /v1/tasks/{id}/pushNotificationConfigs` - List configurations
- `DELETE /v1/tasks/{id}/pushNotificationConfigs/{configId}` - Delete configuration

#### 11.3.4. Agent Card

- `GET /v1/extendedAgentCard` - Get authenticated extended Agent Card

### 11.4. Request/Response Format

All requests and responses use JSON objects structurally equivalent to the Protocol Buffer definitions.

**Example Send Message:**
```http
POST /v1/message:send
Content-Type: application/json

{
  "message": {
    "messageId": "uuid",
    "role": "user",
    "parts": [{"text": "Hello"}]
  },
  "configuration": {
    "acceptedOutputModes": ["text/plain"]
  }
}
```

**Referenced Objects:** [`SendMessageRequest`](#321-sendmessagerequest), [`Message`](#414-message)

**Response:**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "task": {
    "id": "task-uuid",
    "contextId": "context-uuid",
    "status": {
      "state": "completed"
    }
  }
}
```

**Referenced Objects:** [`Task`](#411-task)

### 11.5. Query Parameters

For GET operations, use query parameters for filtering and pagination:

```http
GET /v1/tasks?contextId=uuid&status=working&pageSize=50&pageToken=cursor
```

### 11.6. Error Handling

HTTP implementations **MUST** map A2A-specific error codes to appropriate HTTP status codes while preserving semantic meaning. The HTTP+JSON error structure maps to the generic error model defined in [Section 3.2.2](#332-error-handling) as follows:

- **Error Code**: Mapped to the `error.code` field (string error code) and HTTP status code
- **Error Message**: Mapped to the `error.message` field (human-readable string)
- **Error Details**: Mapped to the `error.details` object (optional structured information)

#### 11.6.1. A2A Error Mappings

| A2A Error Type                      | HTTP Status Code             | Type URI                                              | Description                      |
| :---------------------------------- | :--------------------------- | :---------------------------------------------------- | :------------------------------- |
| `TaskNotFoundError`                 | `404 Not Found`              | `https://a2a-protocol.org/errors/task-not-found`      | Task not found                   |
| `TaskNotCancelableError`            | `409 Conflict`               | `https://a2a-protocol.org/errors/task-not-cancelable` | Task cannot be canceled          |
| `PushNotificationNotSupportedError` | `400 Bad Request`            | `https://a2a-protocol.org/errors/push-notification-not-supported` | Push notifications not supported |
| `UnsupportedOperationError`         | `400 Bad Request`            | `https://a2a-protocol.org/errors/unsupported-operation` | Operation not supported          |
| `ContentTypeNotSupportedError`      | `415 Unsupported Media Type` | `https://a2a-protocol.org/errors/content-type-not-supported` | Content type not supported       |
| `InvalidAgentResponseError`         | `502 Bad Gateway`            | `https://a2a-protocol.org/errors/invalid-agent-response` | Invalid agent response           |
| `ExtendedAgentCardNotConfiguredError` | `400 Bad Request`          | `https://a2a-protocol.org/errors/extended-agent-card-not-configured` | Extended agent card not configured |
| `ExtensionSupportRequiredError`     | `400 Bad Request`            | `https://a2a-protocol.org/errors/extension-support-required` | Required extension not supported |
| `VersionNotSupportedError`          | `400 Bad Request`            | `https://a2a-protocol.org/errors/version-not-supported` | Protocol version not supported   |

#### 11.6.2. Error Response Format

All error responses **MUST** use the RFC 9457 Problem Details format with `Content-Type: application/problem+json`. The abstract `error.code` maps to the `status` field, and the `error.message` maps to the `detail` field. For A2A-specific errors, the `type` field **MUST** use the corresponding URI from the table above, and additional context **MAY** be included in the `details` object.

**Standard HTTP Error Response:**

```http
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "status": 400,
  "detail": "The request payload is invalid: At least one part is required in message.parts",
}
```

**A2A-Specific Error Response:**

```http
HTTP/1.1 404 Not Found
Content-Type: application/problem+json

{
  "type": "https://a2a-protocol.org/errors/task-not-found",
  "title": "Task Not Found",
  "status": 404,
  "detail": "The specified task ID does not exist or is not accessible",
  "taskId": "invalid-task-id"
}
```



### 11.7. Streaming
<span id="stream-response"></span>

REST streaming uses Server-Sent Events with the `data` field containing JSON serializations of the protocol data objects:

```http
POST /v1/message:stream
Content-Type: application/json

{ /* SendMessageRequest object */ }
```

**Referenced Objects:** [`SendMessageRequest`](#321-sendmessagerequest)

**Response:**
```http
HTTP/1.1 200 OK
Content-Type: text/event-stream

data: {"task": { /* Task object */ }}

data: {"artifactUpdate": { /* TaskArtifactUpdateEvent */ }}

data: {"statusUpdate": { /* TaskStatusUpdateEvent */ }}
```
**Referenced Objects:** [`Task`](#411-task), [`TaskStatusUpdateEvent`](#421-taskstatusupdateevent), [`TaskArtifactUpdateEvent`](#422-taskartifactupdateevent)
<span id="4192-taskstatusupdateevent"></span><span id="4193-taskartifactupdateevent"></span>
Streaming responses are simple, linearly ordered sequences: first a `Task` (or single `Message`), then zero or more status or artifact update events until the task reaches a terminal or interrupted state, at which point the stream closes. Implementations SHOULD avoid re-ordering events and MAY optionally resend a final `Task` snapshot before closing.

## 12. Custom Binding Guidelines

While the A2A protocol provides three standard bindings (JSON-RPC, gRPC, and HTTP+JSON/REST), implementers **MAY** create custom protocol bindings to support additional transport mechanisms or communication patterns. Custom bindings **MUST** comply with all requirements defined in [Section 5 (Protocol Binding Requirements and Interoperability)](#5-protocol-binding-requirements-and-interoperability). This section provides additional guidelines specific to developing custom bindings.

### 12.1. Binding Requirements

Custom protocol bindings **MUST**:

1. **Implement All Core Operations**: Support all operations defined in [Section 3 (A2A Protocol Operations)](#3-a2a-protocol-operations)
2. **Preserve Data Model**: Use data structures functionally equivalent to those defined in [Section 4 (Protocol Data Model)](#4-protocol-data-model)
3. **Maintain Semantics**: Ensure operations behave consistently with the abstract operation definitions
4. **Document Completely**: Provide comprehensive documentation of the binding specification

### 12.2. Data Type Mappings

Custom bindings **MUST** provide clear mappings for:

- **Protocol Buffer Types**: Define how each Protocol Buffer message type is represented
- **Timestamps**: Follow the conventions in [Section 5.5.1 (Timestamps)](#551-timestamps)
- **Binary Data**: Specify encoding for binary content (e.g., base64 for text-based protocols)
- **Enumerations**: Define representation of enum values (e.g., strings, integers)

### 12.3. Service Parameter Transmission

As specified in [Section 3.2.5 (Service Parameters)](#325-service-parameters), custom protocol bindings **MUST** document how service parameters are transmitted. The binding specification **MUST** address:

1. **Transmission Mechanism**: The protocol-specific method for transmitting service parameter key-value pairs
2. **Value Constraints**: Any limitations on service parameter values (e.g., character encoding, size limits)
3. **Reserved Names**: Any service parameter names reserved by the binding itself
4. **Fallback Strategy**: What happens when the protocol lacks native header support (e.g., passing service parameters in metadata)

**Example Documentation Requirements:**

- **For native header support**: "Service parameters are transmitted using HTTP request headers. Service parameter keys are case-insensitive and must conform to RFC 7230. Service parameter values must be UTF-8 strings."
- **For protocols without headers**: "Service parameters are serialized as a JSON object and transmitted in the request metadata field `a2a-service-parameters`."

### 12.4. Error Mapping

Custom bindings **MUST**:

1. **Map Standard Errors**: Provide mappings for all A2A-specific error types defined in [Section 3.2.2 (Error Handling)](#332-error-handling)
2. **Preserve Error Information**: Ensure error details are accessible to clients
3. **Use Appropriate Codes**: Map to protocol-native error codes where applicable
4. **Document Error Format**: Specify the structure of error responses

### 12.5. Streaming Support

If the binding supports streaming operations:

1. **Define Stream Mechanism**: Document how streaming is implemented (e.g., WebSockets, long-polling, chunked encoding)
2. **Event Ordering**: Specify ordering guarantees for streaming events
3. **Reconnection**: Define behavior for connection interruption and resumption
4. **Stream Termination**: Specify how stream completion is signaled

If streaming is not supported, the binding **MUST** clearly document this limitation in the Agent Card.

### 12.6. Authentication and Authorization

Custom bindings **MUST**:

1. **Support Standard Schemes**: Implement authentication schemes declared in the Agent Card
2. **Document Integration**: Specify how credentials are transmitted in the protocol
3. **Handle Challenges**: Define how authentication challenges are communicated
4. **Maintain Security**: Follow security best practices for the transport protocol

### 12.7. Agent Card Declaration

Custom bindings **MUST** be declared in the Agent Card:

1. **Transport Identifier**: Use a clear, descriptive transport name
2. **Endpoint URL**: Provide the full URL where the binding is available
3. **Documentation Link**: Include a URL to the complete binding specification

**Example:**
```json
{
  "url": "wss://agent.example.com/a2a/websocket",
  "preferredTransport": "WEBSOCKET",
  "additionalInterfaces": [
    {
      "url": "wss://agent.example.com/a2a/websocket",
      "transport": "WEBSOCKET"
    }
  ]
}
```

### 12.8. Interoperability Testing

Custom binding implementers **SHOULD**:

1. **Test Against Reference**: Verify behavior matches standard bindings
2. **Document Differences**: Clearly note any deviations from standard binding behavior
3. **Provide Examples**: Include sample requests and responses
4. **Test Edge Cases**: Verify handling of error conditions, large payloads, and long-running tasks



## 13. IANA Considerations

This section provides registration templates for the A2A protocol's media type, HTTP headers, and well-known URI, intended for submission to the Internet Assigned Numbers Authority (IANA).

### 13.1. Media Type Registration

#### 13.1.1. application/a2a+json

**Type name:** `application`

**Subtype name:** `a2a+json`

**Required parameters:** None

**Optional parameters:**
- None

**Encoding considerations:** Binary (UTF-8 encoding MUST be used for JSON text)

**Security considerations:**
This media type shares security considerations common to all JSON-based formats as described in RFC 8259, Section 12. Additionally:

- Content MUST be validated against the A2A protocol schema before processing
- Implementations MUST sanitize user-provided content to prevent injection attacks
- File references within A2A messages MUST be validated to prevent server-side request forgery (SSRF)
- Authentication and authorization MUST be enforced as specified in Section 7 of the A2A specification
- Sensitive information in task history and artifacts MUST be protected according to applicable data protection regulations

**Interoperability considerations:**
The A2A protocol supports multiple protocol bindings. This media type is intended for the HTTP+JSON/REST binding.

**Published specification:**
Agent2Agent (A2A) Protocol Specification, available at: https://a2a-protocol.org/specification

**Applications that use this media type:**
AI agent platforms, agentic workflow systems, multi-agent collaboration tools, and enterprise automation systems that implement the A2A protocol for agent-to-agent communication.

**Fragment identifier considerations:** None

**Additional information:**
- **Deprecated alias names for this type:** None
- **Magic number(s):** None
- **File extension(s):** .a2a.json
- **Macintosh file type code(s):** TEXT

**Person & email address to contact for further information:**
A2A Protocol Working Group, a2a-protocol@example.org

**Intended usage:** COMMON

**Restrictions on usage:** None

**Author:** A2A Protocol Working Group

**Change controller:** A2A Protocol Working Group

**Provisional registration:** No

### 13.2. HTTP Header Field Registrations

**Note:** The following HTTP headers represent the HTTP-based protocol binding implementation of the abstract A2A service parameters defined in [Section 3.2.5](#325-service-parameters). These registrations are specific to HTTP/HTTPS transports.

#### 13.2.1. A2A-Version Header

**Header field name:** A2A-Version

**Applicable protocol:** HTTP

**Status:** Standard

**Author/Change controller:** A2A Protocol Working Group

**Specification document:** Section 3.2.5 of the A2A Protocol Specification (https://a2a-protocol.org/specification)

**Related information:**
The A2A-Version header field indicates the A2A protocol version that the client is using. The value MUST be in the format `Major.Minor` (e.g., "0.3"). If the version is not supported by the agent, the agent returns a `VersionNotSupportedError`.

**Example:**
```
A2A-Version: 0.3
```

#### 13.2.2. A2A-Extensions Header

**Header field name:** A2A-Extensions

**Applicable protocol:** HTTP

**Status:** Standard

**Author/Change controller:** A2A Protocol Working Group

**Specification document:** Section 3.2.5 of the A2A Protocol Specification (https://a2a-protocol.org/specification)

**Related information:**
The A2A-Extensions header field contains a comma-separated list of extension URIs that the client wants to use for the request. Extensions allow agents to provide additional functionality beyond the core A2A specification while maintaining backward compatibility.

**Example:**
```
A2A-Extensions: https://example.com/extensions/geolocation/v1,https://standards.org/extensions/citations/v1
```

### 13.3. Well-Known URI Registration

**URI suffix:** agent-card.json

**Change controller:** A2A Protocol Working Group

**Specification document:** Section 8.2 of the A2A Protocol Specification (https://a2a-protocol.org/specification)

**Related information:**
The `.well-known/agent-card.json` URI provides a standardized location for discovering an A2A agent's capabilities, supported protocols, authentication requirements, and available skills. The resource at this URI MUST return an AgentCard object as defined in Section 4.4.1 of the A2A specification.

**Status:** Permanent

**Security considerations:**
- The Agent Card MAY contain public information about an agent's capabilities and SHOULD NOT include sensitive credentials or internal implementation details
- Implementations SHOULD support HTTPS to ensure authenticity and integrity of the Agent Card
- Agent Cards MAY be signed using JSON Web Signatures (JWS) as specified in the AgentCardSignature object (Section 4.4.7)
- Clients SHOULD verify signatures when present to ensure the Agent Card has not been tampered with
- Extended Agent Cards retrieved via authenticated endpoints (Section 3.1.11) MAY contain additional information and MUST enforce appropriate access controls

**Example:**
```
https://agent.example.com/.well-known/agent-card.json
```

---

## Appendix A. Migration & Legacy Compatibility

This appendix catalogs renamed protocol messages and objects, their legacy identifiers, and the planned deprecation/removal schedule. All legacy names and anchors MUST remain resolvable until the stated earliest removal version.

| Legacy Name                                     | Current Name                              | Earliest Removal Version | Notes                                                  |
| ----------------------------------------------- | ----------------------------------------- | ------------------------ | ------------------------------------------------------ |
| `MessageSendParams`                             | `SendMessageRequest`                      | >= 0.5.0                 | Request payload rename for clarity (request vs params) |
| `SendMessageSuccessResponse`                    | `SendMessageResponse`                     | >= 0.5.0                 | Unified success response naming                        |
| `SendStreamingMessageSuccessResponse`           | `StreamResponse`                          | >= 0.5.0                 | Shorter, binding-agnostic streaming response         |
| `SetTaskPushNotificationConfigRequest`          | `CreateTaskPushNotificationConfigRequest` | >= 0.5.0                 | Explicit creation intent                               |
| `ListTaskPushNotificationConfigSuccessResponse` | `ListTaskPushNotificationConfigResponse`  | >= 0.5.0                 | Consistent response suffix removal                     |
| `GetAuthenticatedExtendedCardRequest`           | `GetExtendedAgentCardRequest`             | >= 0.5.0                 | Removed "Authenticated" from naming                    |

Planned Lifecycle (example timeline; adjust per release strategy):

1. 0.3.x: New names introduced; legacy names documented; aliases added.
2. 0.4.x: Legacy names marked "deprecated" in SDKs and schemas; warning notes added.
3. ≥0.5.0: Legacy names eligible for removal after review; migration appendix updated.

### A.1 Legacy Documentation Anchors

Hidden anchor spans preserve old inbound links:

<!-- Legacy inbound link compatibility anchors (old spec numbering & names) -->
<span id="32-supported-transport-protocols"></span>
<span id="324-transport-extensions"></span>
<span id="35-method-mapping-and-naming-conventions"></span>
<span id="5-agent-discovery-the-agent-card"></span>
<span id="53-recommended-location"></span>
<span id="55-agentcard-object-structure"></span>
<span id="56-transport-declaration-and-url-relationships"></span>
<span id="563-client-transport-selection-rules"></span>
<span id="57-sample-agent-card"></span>
<span id="6-protocol-data-objects"></span>
<span id="61-task-object"></span>
<span id="610-taskpushnotificationconfig-object"></span>
<span id="611-json-rpc-structures"></span>
<span id="612-jsonrpcerror-object"></span>
<span id="63-taskstate-enum"></span>
<span id="69-pushnotificationauthenticationinfo-object"></span>
<span id="711-messagesendparams-object"></span>
<span id="72-messagestream"></span>
<span id="721-sendstreamingmessageresponse-object"></span>
<span id="731-taskqueryparams-object"></span>
<span id="741-listtasksparams-object"></span>
<span id="742-listtasksresult-object"></span>
<span id="751-taskidparams-object-for-taskscancel-and-taskspushnotificationconfigget"></span>
<span id="77-taskspushnotificationconfigget"></span>
<span id="771-gettaskpushnotificationconfigparams-object-taskspushnotificationconfigget"></span>
<span id="781-listtaskpushnotificationconfigparams-object-taskspushnotificationconfiglist"></span>
<span id="791-deletetaskpushnotificationconfigparams-object-taskspushnotificationconfigdelete"></span>
<span id="8-error-handling"></span>
<span id="82-a2a-specific-errors"></span>
<!-- Legacy renamed message/object name anchors -->
<span id="messagesendparams"></span>
<span id="sendmessagesuccessresponse"></span>
<span id="sendstreamingmessagesuccessresponse"></span>
<span id="settaskpushnotificationconfigrequest"></span>
<span id="listtaskpushnotificationconfigsuccessresponse"></span>
<span id="getauthenticatedextendedcardrequest"></span>
<span id="938-agentgetauthenticatedextendedcard"></span>

Each legacy span SHOULD be placed adjacent to the current object's heading (to be inserted during detailed object section edits). If an exact numeric-prefixed anchor existed (e.g., `#414-message`), add an additional span matching that historical form if known.

### A.2 Migration Guidance

Client Implementations SHOULD:

- Prefer new names immediately for all new integrations.
- Implement dual-handling where schemas/types permit (e.g., union type or backward-compatible decoder).
- Log a warning when receiving legacy-named objects after the first deprecation announcement release.

Server Implementations MAY:

- Accept both legacy and current request message forms during the overlap period.
- Emit only current form in responses (recommended) while providing explicit upgrade notes.

### A.3 Future Automation

Once the proto→schema generation pipeline lands, this appendix will be partially auto-generated (legacy mapping table sourced from a maintained manifest). Until then, edits MUST be manual and reviewed in PRs affecting `a2a.proto`.


---
