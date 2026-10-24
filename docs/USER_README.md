# Using the LLM Gateway

This gateway offers one OpenAI-compatible HTTPS API for approved text-generation and embedding models. It is operated by an administrator and requires an individually issued **LiteLLM virtual API key**. It is not a public anonymous LLM service.

> **Before you start:** you need the administrator-provided gateway HTTPS URL, a virtual API key issued for your account or application, and at least one model alias you are allowed to call. `https://llm.example.com` is a placeholder, **not a live URL**.

## 1. Request an API key

1. Open the **Request Gateway Access** issue form in this repository: **Issues → New issue → Request Gateway Access**. If the form has not yet been enabled, contact the repository administrator through the contact method listed in the repository `README.md`.
2. Provide **your GitHub username/identity**, project or team, purpose, environment (`development`, `staging`, `production`), required operations (`chat`, `embeddings`, or other approved capabilities), preferred model aliases, approximate requests/tokens per minute, monthly USD budget and planned expiration.
3. State whether request content may contain sensitive or regulated data. **Do not post such data or credentials in the issue.** Public issues are visible to everyone; use a private intake arrangement when even project metadata is sensitive.
4. Wait for the administrator's explicit approval. The administrator may reduce scope, set spending limits or request additional information.
5. Receive the key **privately through an administrator-approved secret-sharing channel or password manager**, not from a GitHub issue comment. The issue will show only status and a nonsecret key alias/request ID.
6. Store the key in a server-side secret store or environment variable. Never commit it, paste it into tickets, send it to a browser client, or log it.

### 1.1 Available Model Aliases

When filling out your access request, select from these standard aliases:

| Alias | Purpose | Recommended Use Cases | Supported Operations |
|---|---|---|---|
| `general-fast` | Fast, low-latency, cost-effective chat | Simple Q&A, summarization, classification | `/v1/chat/completions` (streaming & non-streaming) |
| `general-reasoning` | High capability, advanced reasoning | Complex logic, code generation, detailed analysis | `/v1/chat/completions` (streaming & non-streaming) |
| `structured-output` | Strict JSON schema compliance | Schema-validated outputs, structured data extraction | `/v1/chat/completions` (`response_format: {"type": "json_object"}`) |
| `agent-tools` | Function calling & tool use | Multi-step agent workflows, tool calling | `/v1/chat/completions` (`tools`, `tool_choice`) |
| `rag-embedding` | Vector embeddings (1,536 dimensions) | Retrieval-Augmented Generation (RAG), semantic search | `/v1/embeddings` |

> [!NOTE]
> Callers must **always use these alias names** in API calls (e.g. `"model": "general-fast"`), never upstream provider model IDs (`gpt-4o-mini`, `gemini-2.0-flash`, etc.). This enables seamless administrator upgrades and provider migrations without breaking your code.

### 1.2 Step-by-Step Request Instructions

| Field | Example (non-sensitive) |
|---|---|
| Requester | `@github-user` |
| Application/team | `sample-service` |
| Environment | `development` |
| Purpose | `Generate short knowledge-base summaries` |
| Required API | `chat/completions` |
| Model aliases | `general-fast` |
| Approximate usage | `10 requests/min, 2,000 tokens/min` |
| Budget | `USD 5 per month` |
| Expiration | `30 days` |
| Data sensitivity | `Synthetic/non-sensitive only` |

**Key issuance is a controlled administrative action.** A request does not guarantee approval; quotas, upstream-provider availability and permissible data handling apply. Users must not create keys with an administrator's master key.

## 2. Configure the client

The administrator supplies:

- `LLM_GATEWAY_URL` — the public HTTPS base URL, e.g. `https://llm.example.com`.
- `LLM_GATEWAY_KEY` — your personal/application virtual key (`sk-...`). Keep it secret.
- One or more approved **model aliases** such as `general-fast` or `rag-embedding`. Actual aliases are managed by the gateway administrator.

Example terminal environment (do not put actual secrets in a shared shell script):

```bash
export LLM_GATEWAY_URL='https://llm.example.com'
read -rsp 'Enter your LiteLLM virtual key: ' LLM_GATEWAY_KEY
printf '\n'
export LLM_GATEWAY_KEY
```

Better for deployments: inject the key from a managed secret store. Run server-to-server only; do not expose the key through browser JavaScript or public frontend bundles.

## 3. Discover your available models

```bash
curl --fail-with-body --silent --show-error \
  "$LLM_GATEWAY_URL/v1/models" \
  -H "Authorization: Bearer $LLM_GATEWAY_KEY"
```

A key may only access an allowlisted subset. If `/v1/models` is not enabled for your assigned role, ask the administrator for your allowed aliases.

## 4. Make a chat completion request

The gateway exposes an OpenAI-compliant `/v1/chat/completions` endpoint. Because it follows standard HTTP API conventions, **you are not locked into any single client library or vendor SDK**.

> [!TIP] No OpenAI SDK Required!
> You do **not** need `ChatOpenAI` or the `openai` package installed. You can call the gateway using the **LiteLLM SDK (`litellm.completion`)**, **LangChain (`ChatLiteLLM`)**, **LangGraph**, **Google Antigravity SDK (ADK)**, **LlamaIndex**, or plain **cURL**.

### 4.1 LiteLLM Python SDK (Zero Vendor Lock-in)

The official `litellm` library makes it trivial to query the gateway without importing `openai` or `ChatOpenAI`. Simply prefix the alias with `openai/` so LiteLLM knows to route the request using OpenAI wire format:

```python
import os
import litellm

gateway_base = os.environ["LLM_GATEWAY_URL"].rstrip("/") + "/v1"
gateway_key = os.environ["LLM_GATEWAY_KEY"]

# 1. Standard Chat Completion
response = litellm.completion(
    model="openai/general-fast",  # or "openai/general-reasoning"
    api_base=gateway_base,
    api_key=gateway_key,
    messages=[
        {"role": "system", "content": "You are a concise tech assistant."},
        {"role": "user", "content": "What is the primary benefit of an API gateway?"},
    ],
    temperature=0.7,
    max_tokens=256,
)
print("Response:", response.choices[0].message.content)

# 2. Real-Time Token Streaming
print("\nStreaming response:")
response_stream = litellm.completion(
    model="openai/general-fast",
    api_base=gateway_base,
    api_key=gateway_key,
    messages=[{"role": "user", "content": "List 3 principles of microservices."}],
    stream=True,
)
for chunk in response_stream:
    token = chunk.choices[0].delta.content or ""
    print(token, end="", flush=True)
print()
```

### 4.2 LangChain (Python) — Using `ChatLiteLLM` or `ChatOpenAI`

LangChain connects cleanly without requiring `langchain-openai`. You can use `ChatLiteLLM` directly:

```python
import os
from langchain_community.chat_models import ChatLiteLLM
from langchain_core.prompts import ChatPromptTemplate

# Initialize with ChatLiteLLM (no ChatOpenAI dependency needed)
llm = ChatLiteLLM(
    model="openai/general-fast",  # or "openai/general-reasoning"
    api_base=os.environ["LLM_GATEWAY_URL"].rstrip("/") + "/v1",
    api_key=os.environ["LLM_GATEWAY_KEY"],
    temperature=0.7,
    max_tokens=256,
)

# 1. Simple Invocation
response = llm.invoke("What are the advantages of an API gateway?")
print("Response:", response.content)

# 2. Streaming Output
print("\nStreaming:")
for chunk in llm.stream("Give me three bullet points on software architecture."):
    print(chunk.content, end="", flush=True)
print()

# 3. Structured Output with Prompt Template
prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a concise data extractor."),
    ("user", "{input}"),
])
chain = prompt | llm
result = chain.invoke({"input": "Extract the company and year: Acme Corp was founded in 1985."})
print("\nChain Output:", result.content)
```

*(Note: If your team already has `langchain-openai` installed, `ChatOpenAI(model="general-fast", base_url=..., api_key=...)` also works drop-in).*

### 4.3 LangGraph (Python) — ReAct Agent with Tool Use

LangGraph agents use the `agent-tools` alias to execute autonomous multi-step reasoning with function/tool execution:

```python
import os
from langchain_community.chat_models import ChatLiteLLM
from langchain_core.tools import tool
from langgraph.prebuilt import create_react_agent

# Define custom tools
@tool
def calculate_vat(amount: float, country: str) -> str:
    """Calculate VAT for a given country code."""
    rates = {"DE": 0.19, "FR": 0.20, "UK": 0.20, "US": 0.0}
    rate = rates.get(country.upper(), 0.15)
    tax = amount * rate
    return f"VAT in {country.upper()} for €{amount:.2f} is €{tax:.2f} (Total: €{amount + tax:.2f})"

# Initialize model with agent-tools alias via ChatLiteLLM
model = ChatLiteLLM(
    model="openai/agent-tools",
    api_base=os.environ["LLM_GATEWAY_URL"].rstrip("/") + "/v1",
    api_key=os.environ["LLM_GATEWAY_KEY"],
    temperature=0.2,
)

# Build and run the ReAct agent graph
agent = create_react_agent(model, tools=[calculate_vat])
inputs = {"messages": [("user", "What is the total cost of a €150 purchase in France including VAT?")]}

print("Running LangGraph Agent:")
for chunk in agent.stream(inputs, stream_mode="values"):
    message = chunk["messages"][-1]
    if message.type == "ai":
        print(f"[{message.type}]: {message.content}")
```

### 4.4 Google Antigravity SDK / Agent Development Kit (ADK)

You can configure agents in the Google Antigravity (AGY) SDK or ADK to route LLM reasoning through your gateway:

```python
import os
from openai import OpenAI

# The gateway serves as the inference backend for Antigravity agents
gateway_client = OpenAI(
    base_url=os.environ["LLM_GATEWAY_URL"].rstrip("/") + "/v1",
    api_key=os.environ["LLM_GATEWAY_KEY"],
)

def agent_reasoning_step(system_instruction: str, user_input: str) -> str:
    """Agentic decision-making step using the general-reasoning alias."""
    response = gateway_client.chat.completions.create(
        model="general-reasoning",
        messages=[
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": user_input},
        ],
        temperature=0.2,
    )
    return response.choices[0].message.content or ""

action_plan = agent_reasoning_step(
    system_instruction="You are an autonomous DevOps planner. Output concise execution steps.",
    user_input="We need to deploy a canary release of service auth-v2.",
)
print("Agent Action Plan:\n", action_plan)
```

### 4.5 TypeScript / Node.js (LangChain or OpenAI SDK)

#### Using LangChain.js:
```typescript
import { ChatOpenAI } from "@langchain/openai";

const model = new ChatOpenAI({
  model: "general-fast",
  configuration: {
    baseURL: `${process.env.LLM_GATEWAY_URL?.replace(/\/$/, "")}/v1`,
    apiKey: process.env.LLM_GATEWAY_KEY,
  },
  temperature: 0.7,
});

const response = await model.invoke("Hello from LangChain TypeScript!");
console.log(response.content);
```

#### Using Standard OpenAI Node SDK:
```typescript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: `${process.env.LLM_GATEWAY_URL?.replace(/\/$/, "")}/v1`,
  apiKey: process.env.LLM_GATEWAY_KEY,
});

const response = await client.chat.completions.create({
  model: "general-fast",
  messages: [{ role: "user", content: "Tell me a short programming joke." }],
  max_tokens: 50,
});
console.log(response.choices[0].message.content);
```

### 4.6 Raw cURL / HTTP (Any Language)

```bash
curl --fail-with-body --silent --show-error \
  "$LLM_GATEWAY_URL/v1/chat/completions" \
  -H "Authorization: Bearer $LLM_GATEWAY_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "general-fast",
    "messages": [{"role": "user", "content": "Reply with the word ready."}],
    "max_tokens": 20
  }'
```

---

## 5. Generate embeddings (if granted)

The `/v1/embeddings` endpoint converts text into high-dimensional vector representations for semantic search, document clustering, and RAG (Retrieval-Augmented Generation).

### 5.1 LiteLLM Python SDK (`litellm.embedding`) — Zero Vendor Lock-in

```python
import os
import litellm

# Generate high-dimensional vector embeddings with zero OpenAI dependencies
response = litellm.embedding(
    model="openai/rag-embedding",
    api_base=os.environ["LLM_GATEWAY_URL"].rstrip("/") + "/v1",
    api_key=os.environ["LLM_GATEWAY_KEY"],
    input=[
        "LiteLLM centralizes model authentication.",
        "PostgreSQL stores spend and key audit records.",
    ],
)

vectors = [item["embedding"] for item in response.data]
print(f"Generated {len(vectors)} embeddings. Dimensions: {len(vectors[0])}")
```

### 5.2 LlamaIndex (Python) — RAG Indexing & Querying

```python
import os
from llama_index.core import VectorStoreIndex, Document
from llama_index.llms.openai import OpenAI
from llama_index.embeddings.openai import OpenAIEmbedding

gateway_base_url = os.environ["LLM_GATEWAY_URL"].rstrip("/") + "/v1"
gateway_key = os.environ["LLM_GATEWAY_KEY"]

# Configure LlamaIndex to use gateway for both embedding and synthesis
embed_model = OpenAIEmbedding(
    model="rag-embedding",
    api_base=gateway_base_url,
    api_key=gateway_key,
)

llm = OpenAI(
    model="general-fast",
    api_base=gateway_base_url,
    api_key=gateway_key,
)

documents = [
    Document(text="The gateway VM runs on OCI Ampere A1 ARM64 architecture."),
    Document(text="Ingress traffic is secured with TLS 1.3 through Caddy reverse proxy."),
]

# Create index using the gateway embeddings
index = VectorStoreIndex.from_documents(documents, embed_model=embed_model)

# Query the index using the gateway LLM
query_engine = index.as_query_engine(llm=llm)
response = query_engine.query("What compute architecture does the gateway run on?")
print("LlamaIndex Answer:", response)
```

### 5.3 LangChain (Python) — Vector Store Embeddings

```python
import os
from langchain_openai import OpenAIEmbeddings

embeddings = OpenAIEmbeddings(
    model="rag-embedding",
    base_url=os.environ["LLM_GATEWAY_URL"].rstrip("/") + "/v1",
    api_key=os.environ["LLM_GATEWAY_KEY"],
)

doc_vectors = embeddings.embed_documents([
    "LiteLLM centralizes model authentication.",
    "PostgreSQL stores spend and key audit records."
])

print(f"Generated {len(doc_vectors)} embeddings. Dimensions: {len(doc_vectors[0])}")
```

### 5.4 TypeScript / Node.js (LangChain or OpenAI SDK)

```typescript
import { OpenAIEmbeddings } from "@langchain/openai";

const embeddings = new OpenAIEmbeddings({
  model: "rag-embedding",
  configuration: {
    baseURL: `${process.env.LLM_GATEWAY_URL?.replace(/\/$/, "")}/v1`,
    apiKey: process.env.LLM_GATEWAY_KEY,
  },
});

const vector = await embeddings.embedQuery("Semantic retrieval search query");
console.log(`Generated embedding with ${vector.length} dimensions`);
```

### 5.5 Raw cURL

```bash
curl --fail-with-body --silent --show-error \
  "$LLM_GATEWAY_URL/v1/embeddings" \
  -H "Authorization: Bearer $LLM_GATEWAY_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "rag-embedding",
    "input": "This is a document to be embedded for RAG search."
  }'
```

> [!IMPORTANT]
> The `rag-embedding` alias outputs fixed 1,536-dimensional vectors. When configuring your vector store (Pinecone, Qdrant, Milvus, pgvector, Chroma, etc.), set your collection dimension to **1536**.

## 6. Usage, quotas and failures

| Result | Meaning / recommended action |
|---|---|
| 401 or 403 | Key is missing, expired, revoked, wrong for this environment, or model/route is not permitted. Confirm alias and request an access review; never retry with the master key. |
| 429 | Rate limit/concurrency exceeded. Apply bounded exponential backoff with jitter and respect `Retry-After` if provided. |
| Budget exceeded response | Stop automated retries; ask the administrator to review usage and budget. |
| 5xx / timeout | Gateway or provider is unavailable. Retry only idempotent operations with a strict retry budget; do not overwhelm the service. |
| TLS failure | Verify the HTTPS hostname and certificate; do not disable TLS validation. |

**Usage reporting:** ask the administrator for usage and cost reports for your key/team until a safe, restricted self-service reporting endpoint is explicitly enabled. Proxy estimates may differ from actual provider bills.

## 7. Renew, rotate or revoke a key

- **Renewal:** comment on the original request issue **without disclosing the key**, stating the approved key alias and requested new expiry or scope. A new approval may be required.
- **Rotation:** request a replacement key; update the server-side secret store; test the replacement; acknowledge the switchover; administrator revokes the old key.
- **Compromise/loss:** immediately alert the administrator via the designated private security contact and reference the nonsecret key alias. Do not paste the leaked key into the report. Admin will revoke it and review logs.
- **No longer needed:** request revocation to remove unnecessary access.

The key may be revoked without warning for abuse, policy breach or compromised credentials. Each environment should use a different key.

## 8. Service guarantees and acceptable use

- The gateway is initially a **single Oracle Always Free VM**, not a guaranteed high-availability commercial API. Planned downtime or free-VM reclamation is possible.
- Upstream providers charge for model usage; the gateway enforces approved budgets and requests where supported, but cost accounting can lag. Providers may have their own rate and billing limits.
- Never send sensitive personal, regulated, or confidential data unless your access request explicitly obtained approval for its handling and the configured upstream provider policy permits it.
- Do not send the virtual key to a browser, mobile public application, or untrusted third party; build a backend relay for end-user applications.

## 9. Administrator contact and access-request link

**To complete after repository creation:** maintainers must add an actual monitored support/security contact in the root `README.md` and ensure the **Request Gateway Access** issue form is enabled. No real deployment URL or administrator contact has been provided in this planning pack.

Further details: root `README.md` for service status and `docs/KEY_POLICY.md` for the approved model/quota policies. Official LiteLLM client help: https://docs.litellm.ai/docs/proxy/client_setup/overview
