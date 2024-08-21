> [!WARNING]
> This README was written by Gemini after a quick chat :)
> 
> I'll rewrite it myself after the project is "live".

---

`ichibase` is a component-based engine for **Just-In-Time (JIT) Applications**. It provides an Elixir+Luerl+SQLite+DuckDB core that executes LLM-generated logic and mounts frontends on-demand within a sandboxed environment.

---

## 🗺 Strategic Roadmap

### Stage 1: Foundation

*Focus: Turning Japanese intent into verifiable SQLite/Lua services.*

* [ ] **Minimal Host:** Single **Docker** container.
* [ ] **SQL-over-HTTP:** A ClickHouse-style POST interface for raw/parameterized SQL.
* [ ] **Native RLS:** Permanent SQL views using `auth_userid()`-like session hooks for multi-user/multi-device safety.
* [ ] **Luerl Sandbox:** Secure Lua 5.2 environment for LLM-generated glue logic.
* [ ] **Deep Trace Engine:** Line-by-line state capturing in Lua for real-time debugging and variable hovering.
* [ ] **Dual-Storage:** **SQLite** for transactions and **DuckDB** for analytical "posterity" logs.
* [ ] **S3 Offloading:** Streaming WAL backups (Litestream) and Parquet archival for "Life Memory."
* [ ] **Simple WS:** Lightweight WebSocket broadcasting.
* [ ] **Autonomous Repair Loop:** RLVR loop that feeds `PropCheck` or Lua errors back to the LLM for self-correction.
* [ ] **Branch & Merge:** Automated SQLite cloning to test logic/schema changes in isolation before commit.

### Stage 2: Lego

*Focus: Provide the "Batteries" for real-world apps (Auth, Notify, Analytics).*

* [ ] **Auth:** Integrated JWT, sessions, and WebAuthn (Passkey) support.
* [ ] **Notify:** One-line Lua calls for Push (WebPush), Email (SMTP), and SMS.
* [ ] **Analytics:** High-performance OLAP queries via DuckDB over the Parquet "Posterity" logs.
* [ ] **WS:** Lightweight WebSocket broadcasting and presence.
* [ ] **CDC:** Real-time change notifications from SQLite.
* [ ] **Chats:** Native module for two-way Telegram/Discord/Slack communication.

### Stage 3: AI

*Focus: ChatGPT-wrappers.*

* [ ] **Unified AI Module:** Vercel-style Lua SDK (`ai.*`) for multi-model text/object generation.
* [ ] **OpenRouter-style Observability:** Automated tracking of token costs, latency, and quality per request.

### Stage 4: UI

*Focus: Interactive apps generated on-the-fly.*

* [ ] **Canvas Shell:** A tiny frontend loader that receives and mounts React/Tailwind components.
* [ ] **`ui.deploy()`:** Lua function to push AI-generated UI code directly to the user’s screen.
* [ ] **Spatial Debugging:** A visual debugger where you can see data flow and code execution side-by-side.

### Stage 5: IRL

*Focus: Connecting ichi to the outside.*

* [ ] **Secure HTTP Egress:** Policy-based `http` module that redacts secrets/OTPs before they reach APIs.
* [ ] **Credential Vault:** Scoped token management for Gmail, Pocket, Spotify, YouTube, and Goodreads.
* [ ] **Durable Workflows:** SQLite-persisted state machines (`flow.*`) for long-running tasks (e.g., "Morning Digest").
* [ ] **SQLite Extentions:** vectors/http/s3/etc.

### Stage 6: Local

*Focus: Seamless state sync between phone, desktop, and cloud.*

* [ ] **CR-SQLite Integration:** Opt-in CRDT support for conflict-free sync between local and cloud instances.
* [ ] **Livebook-style Distribution:** Packaging as a single-binary "App" for local use via Burrito/Bakeware.

---

## 🛠 Available Lua Components

| Component | Responsibility |
| --- | --- |
| `db` | Secure SQL execution, migrations, and vector search. |
| `auth` | Identity and RLS enforcement. |
| `file` | S3/Object-Storage integration. |
| `ai` | LLM orchestration with built-in observability. |
| `notify` | Dispatching WS, Push, Email, and SMS notifications. |
| `analytics` | Running complex OLAP queries over DuckDB/Parquet logs. |
| `ui` | On-demand UI deployment (React/Tailwind). |
| `http` | Privacy-aware external API calls (Sanitized). |
| `flow` | Durable cron jobs and long-running state. |
| `debug` | Line-by-line tracing and variable inspection. |
| ... | ... |

---

## 🚀 [Uryi](https://github.com/ruslandoga/uryi) (aka example app) Flow

1. **Ingest:** ichibase-powered Uryi fetches my newsletters, pocket, goodreads, podcases via `smtp` and `http`.
2. **Filter:** The Privacy Guard redacts personal codes; `ai` ranks articles based on my preferences.
3. **UI Deployment:** `ui.deploy()` pushes a generated summary dashboard or sends it to me via some chat-app or notification or email.
4. **Feedback:** I read, go through my day, tell it what I liked/disliked, complain a lot, via chat or email or its generated ui.
5. **Preferences:** It stores and recalls "what I like/dislike" in a bunch of Obsidian-like Markdown files.
6. **Loop:** Preferences -- updated, evening work-out and wind-down routine -- created. I complain a bit more and go to sleep.
