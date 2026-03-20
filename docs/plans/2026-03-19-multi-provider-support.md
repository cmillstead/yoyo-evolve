# Multi-Provider Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `--provider` and `--base-url` CLI flags so yoyo can use OpenRouter, OpenAI, Ollama, and other OpenAI-compatible APIs instead of being locked to Anthropic.

**Architecture:** Upgrade yoagent 0.5→0.7 (adds `with_model_config`). Add a `--provider` flag that selects the right `OpenAiCompat` preset and constructs a `ModelConfig`. When provider is not `anthropic`, use `OpenAiCompatProvider` instead of `AnthropicProvider`. The `--base-url` flag overrides the default URL for any provider.

**Tech Stack:** Rust, yoagent 0.7, tokio 1, serde_json 1

---

### Task 1: Upgrade yoagent from 0.5 to 0.7

**Files:**
- Modify: `Cargo.toml:10`
- Modify: `Cargo.lock` (auto-updated)

- [ ] **Step 1: Update the dependency**

In `Cargo.toml`, change:
```toml
yoagent = "0.7"
```

- [ ] **Step 2: Build to check for breaking changes**

Run: `cargo build 2>&1`
Expected: PASS — the 0.5→0.7 API is compatible for yoyo's usage. `Agent::new`, `with_system_prompt`, `with_model`, `with_api_key`, `with_thinking`, `with_tools`, `with_skills`, `with_max_tokens`, `prompt()`, `abort()`, `messages()`, `replace_messages()`, `save_messages()`, `restore_messages()` all still exist with the same signatures.

- [ ] **Step 3: Run full CI checks**

Run: `cargo fmt -- --check && cargo clippy --all-targets -- -D warnings && cargo test`
Expected: All pass. If any yoagent type changes cause issues, fix them here.

- [ ] **Step 4: Commit**

```bash
git add Cargo.toml Cargo.lock
git commit -m "feat: upgrade yoagent 0.5 -> 0.7 (adds with_model_config)"
```

---

### Task 2: Add provider parsing to CLI

**Files:**
- Modify: `src/cli.rs` — add `provider` and `base_url` fields to `Config`, parse new flags
- Test: `src/cli.rs` (inline tests module)

**Context:** `src/cli.rs` owns the `Config` struct (line 20) and `parse_args` function (line 236). The config file parser at line 175 already handles arbitrary `key = "value"` pairs, so `provider` and `base_url` config file support comes free.

- [ ] **Step 1: Write tests for provider flag parsing**

Add to the `#[cfg(test)] mod tests` block at the bottom of `src/cli.rs`:

```rust
#[test]
fn test_provider_flag_parsing() {
    let args = [
        "yoyo".to_string(),
        "--provider".to_string(),
        "openrouter".to_string(),
    ];
    let provider = args
        .iter()
        .position(|a| a == "--provider")
        .and_then(|i| args.get(i + 1))
        .cloned();
    assert_eq!(provider, Some("openrouter".to_string()));
}

#[test]
fn test_base_url_flag_parsing() {
    let args = [
        "yoyo".to_string(),
        "--base-url".to_string(),
        "http://localhost:11434/v1".to_string(),
    ];
    let base_url = args
        .iter()
        .position(|a| a == "--base-url")
        .and_then(|i| args.get(i + 1))
        .cloned();
    assert_eq!(base_url, Some("http://localhost:11434/v1".to_string()));
}

#[test]
fn test_provider_config_file() {
    let content = r#"
provider = "openrouter"
base_url = "https://openrouter.ai/api/v1"
"#;
    let config = parse_config_file(content);
    assert_eq!(config.get("provider").unwrap(), "openrouter");
    assert_eq!(config.get("base_url").unwrap(), "https://openrouter.ai/api/v1");
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `cargo test -- test_provider_flag_parsing test_base_url_flag_parsing test_provider_config_file`
Expected: All 3 PASS (they test arg/config parsing logic, not Config struct fields yet).

- [ ] **Step 3: Add fields to Config and parse them in parse_args**

In `src/cli.rs`, add to the `Config` struct (after `output_path`):

```rust
pub provider: String,
pub base_url: Option<String>,
```

Add `--provider` and `--base-url` to `flags_needing_values` array (around line 251):

```rust
let flags_needing_values = [
    "--model",
    "--thinking",
    "--max-tokens",
    "--skills",
    "--system",
    "--system-file",
    "--prompt",
    "-p",
    "--output",
    "-o",
    "--provider",
    "--base-url",
];
```

Add `base_url` parsing after `output_path` parsing (around line 383), before the final `Some(Config { ... })`. Note: `provider` was already parsed early (before `api_key`), so only `base_url` is needed here:

```rust
let base_url = args
    .iter()
    .position(|a| a == "--base-url")
    .and_then(|i| args.get(i + 1))
    .cloned()
    .or_else(|| file_config.get("base_url").cloned());
```

Add the fields to the `Config` return:

```rust
Some(Config {
    model,
    api_key,
    skills,
    system_prompt,
    thinking,
    max_tokens,
    continue_session,
    output_path,
    prompt_arg,
    provider,
    base_url,
})
```

Parse `provider` early (before the `api_key` block) so we can use it to decide whether an API key is required. Add this right after `let file_config = load_config_file();` (around line 248):

```rust
let provider = args
    .iter()
    .position(|a| a == "--provider")
    .and_then(|i| args.get(i + 1))
    .cloned()
    .or_else(|| file_config.get("provider").cloned())
    .unwrap_or_else(|| "anthropic".into());
```

Then replace the `api_key` block (lines 284-292) with:

```rust
let api_key = match read_and_clear_api_key() {
    Some(key) => key,
    None => {
        if provider == "ollama" {
            "ollama".to_string()
        } else {
            eprintln!("{RED}error:{RESET} No API key found.");
            eprintln!("Set ANTHROPIC_API_KEY or API_KEY environment variable.");
            eprintln!("Example: ANTHROPIC_API_KEY=sk-ant-... cargo run");
            std::process::exit(1);
        }
    }
};
```

- [ ] **Step 4: Update help text**

In `print_help()`, add after the `--no-color` line:

```rust
println!("  --provider <name> Provider: anthropic (default), openrouter, openai, ollama,");
println!("                    groq, deepseek, mistral, xai");
println!("  --base-url <url>  Override API base URL for the provider");
```

Update the Environment section:

```rust
println!("Environment:");
println!("  ANTHROPIC_API_KEY  API key (required, or API_KEY)");
println!("  API_KEY            Alternative env var for API key");
println!("  Note: ollama provider does not require an API key");
```

- [ ] **Step 5: Run full CI checks**

Run: `cargo fmt && cargo clippy --all-targets -- -D warnings && cargo test`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add src/cli.rs
git commit -m "feat: add --provider and --base-url CLI flags"
```

---

### Task 3: Build agent with provider-specific ModelConfig

**Files:**
- Modify: `src/main.rs` — update `build_agent` to accept provider config and construct the right provider
- Test: `src/main.rs` (inline tests module)

**Context:** `build_agent` is at line 38 of `src/main.rs`. Currently hardcodes `Agent::new(AnthropicProvider)`. We need it to conditionally use `OpenAiCompatProvider` with a `ModelConfig` when provider != "anthropic".

- [ ] **Step 1: Write test for provider-to-ModelConfig mapping**

Add a helper function and tests. In the `#[cfg(test)] mod tests` block of `src/main.rs`:

```rust
#[test]
fn test_default_base_url_known_providers() {
    let known = ["anthropic", "openrouter", "openai", "ollama", "groq", "deepseek", "mistral", "xai"];
    for p in known {
        let url = default_base_url(p);
        assert!(url.starts_with("http"), "Provider {p} should have a valid URL, got: {url}");
    }
}

#[test]
fn test_default_base_url_unknown_provider() {
    // Unknown providers fall back to OpenAI-compatible default
    let url = default_base_url("foobar");
    assert_eq!(url, "https://api.openai.com/v1");
}

#[test]
fn test_compat_for_provider_returns_defaults_for_unknown() {
    // Unknown providers should get OpenAiCompat::default() without panicking
    let _compat = compat_for_provider("foobar");
}
```

- [ ] **Step 2: Add imports and create `make_model_config` function**

At the top of `src/main.rs`, update the imports:

```rust
use yoagent::provider::{AnthropicProvider, ModelConfig, OpenAiCompat, OpenAiCompatProvider};
```

Add a new function before `build_agent`:

```rust
/// Default base URLs for each provider.
fn default_base_url(provider: &str) -> &str {
    match provider {
        "anthropic" => "https://api.anthropic.com",
        "openrouter" => "https://openrouter.ai/api/v1",
        "openai" => "https://api.openai.com/v1",
        "ollama" => "http://localhost:11434/v1",
        "groq" => "https://api.groq.com/openai/v1",
        "deepseek" => "https://api.deepseek.com/v1",
        "mistral" => "https://api.mistral.ai/v1",
        "xai" => "https://api.x.ai/v1",
        _ => "https://api.openai.com/v1",
    }
}

/// Build an OpenAiCompat preset for the given provider name.
fn compat_for_provider(provider: &str) -> OpenAiCompat {
    match provider {
        "openrouter" => OpenAiCompat::openrouter(),
        "openai" => OpenAiCompat::openai(),
        "groq" => OpenAiCompat::groq(),
        "deepseek" => OpenAiCompat::deepseek(),
        "mistral" => OpenAiCompat::mistral(),
        "xai" => OpenAiCompat::xai(),
        // ollama and unknown providers use sensible defaults
        _ => OpenAiCompat::default(),
    }
}
```

- [ ] **Step 3: Update `build_agent` signature and implementation**

Replace the existing `build_agent` function:

```rust
fn build_agent(
    model: &str,
    api_key: &str,
    skills: &yoagent::skills::SkillSet,
    system_prompt: &str,
    thinking: ThinkingLevel,
    max_tokens: Option<u32>,
    provider: &str,
    base_url: Option<&str>,
) -> Agent {
    let mut agent = if provider == "anthropic" {
        Agent::new(AnthropicProvider)
    } else {
        let url = base_url.unwrap_or_else(|| default_base_url(provider));
        let model_config = ModelConfig {
            id: model.to_string(),
            name: model.to_string(),
            api: yoagent::provider::ApiProtocol::OpenAiCompletions,
            provider: provider.to_string(),
            base_url: url.to_string(),
            reasoning: thinking != ThinkingLevel::Off,
            context_window: 200_000,
            max_tokens: max_tokens.unwrap_or(8192),
            cost: yoagent::provider::CostConfig::default(),
            headers: std::collections::HashMap::new(),
            compat: Some(compat_for_provider(provider)),
        };
        Agent::new(OpenAiCompatProvider).with_model_config(model_config)
    };

    agent = agent
        .with_system_prompt(system_prompt)
        .with_model(model)
        .with_api_key(api_key)
        .with_thinking(thinking)
        .with_skills(skills.clone())
        .with_tools(default_tools());

    if let Some(max) = max_tokens {
        agent = agent.with_max_tokens(max);
    }
    agent
}
```

- [ ] **Step 4: Update all `build_agent` call sites**

There are 3 call sites in `src/main.rs`. Each needs the new `provider` and `base_url` args.

Extract `provider` and `base_url` from config after the existing extractions (around line 80):

```rust
let provider = config.provider;
let base_url = config.base_url;
```

Update the initial build (around line 82):

```rust
let mut agent = build_agent(
    &model,
    &api_key,
    &skills,
    &system_prompt,
    thinking,
    max_tokens,
    &provider,
    base_url.as_deref(),
);
```

Update `/clear` (around line 271):

```rust
agent = build_agent(
    &model,
    &api_key,
    &skills,
    &system_prompt,
    thinking,
    max_tokens,
    &provider,
    base_url.as_deref(),
);
```

Update `/model <name>` (around line 295):

```rust
agent = build_agent(
    &model,
    &api_key,
    &skills,
    &system_prompt,
    thinking,
    max_tokens,
    &provider,
    base_url.as_deref(),
);
```

- [ ] **Step 5: Update banner and /config to show provider**

In the banner section (around line 139), add after the model line:

```rust
if provider != "anthropic" {
    println!("{DIM}  provider: {provider}{RESET}");
    if let Some(ref url) = base_url {
        println!("{DIM}  base_url: {url}{RESET}");
    }
}
```

In `/config` (around line 452), add after the model line:

```rust
println!("    provider:   {provider}");
if let Some(ref url) = base_url {
    println!("    base_url:   {url}");
}
```

- [ ] **Step 6: Run full CI checks**

Run: `cargo fmt && cargo clippy --all-targets -- -D warnings && cargo test`
Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add src/main.rs
git commit -m "feat: build agent with provider-specific ModelConfig"
```

---

### Task 4: Update evolve.sh and GitHub Actions for multi-provider

**Files:**
- Modify: `scripts/evolve.sh` — read `PROVIDER` and `BASE_URL` env vars, pass to cargo run
- Modify: `.github/workflows/evolve.yml` — pass through provider env vars

- [ ] **Step 1: Update evolve.sh env vars**

At the top of `scripts/evolve.sh` (after line 17 `TIMEOUT=...`), add:

```bash
PROVIDER="${PROVIDER:-anthropic}"
BASE_URL="${BASE_URL:-}"
```

- [ ] **Step 2: Build the provider flags for cargo run**

After `TIMEOUT_CMD` logic (around line 124), add:

```bash
PROVIDER_FLAGS="--provider $PROVIDER"
if [ -n "$BASE_URL" ]; then
    PROVIDER_FLAGS="$PROVIDER_FLAGS --base-url $BASE_URL"
fi
```

- [ ] **Step 3: Update all `cargo run` invocations in evolve.sh**

There are 3 `cargo run` calls. Update each to include `$PROVIDER_FLAGS`:

Main session (around line 223):
```bash
${TIMEOUT_CMD:+$TIMEOUT_CMD "$TIMEOUT"} cargo run -- \
    --model "$MODEL" \
    --skills ./skills \
    $PROVIDER_FLAGS \
    < "$PROMPT_FILE" 2>&1 | tee "$AGENT_LOG" || true
```

Fix prompt (around line 281):
```bash
${TIMEOUT_CMD:+$TIMEOUT_CMD 300} cargo run -- \
    --model "$MODEL" \
    --skills ./skills \
    $PROVIDER_FLAGS \
    < "$FIX_PROMPT" || true
```

Journal prompt (around line 320):
```bash
${TIMEOUT_CMD:+$TIMEOUT_CMD 120} cargo run -- \
    --model "$MODEL" \
    --skills ./skills \
    $PROVIDER_FLAGS \
    < "$JOURNAL_PROMPT" || true
```

- [ ] **Step 4: Update evolve.sh header comment**

Update the comment block at the top of `evolve.sh`:

```bash
# Environment:
#   ANTHROPIC_API_KEY  - API key (required unless PROVIDER=ollama)
#   API_KEY            - alternative API key env var
#   REPO               - GitHub repo (default: yologdev/yoyo-evolve)
#   MODEL              - LLM model (default: claude-opus-4-6)
#   PROVIDER           - API provider (default: anthropic)
#   BASE_URL           - Override base URL for the provider
#   TIMEOUT            - Max session time in seconds (default: 3600)
```

- [ ] **Step 5: Update evolve.yml to pass provider env vars**

In `.github/workflows/evolve.yml`, add to each `env:` block that has `ANTHROPIC_API_KEY` (the 3 step blocks: attempt1, attempt2, retry):

```yaml
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          API_KEY: ${{ secrets.API_KEY }}
          PROVIDER: ${{ vars.PROVIDER || 'anthropic' }}
          BASE_URL: ${{ vars.BASE_URL || '' }}
          REPO: ${{ github.repository }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

This uses GitHub repository **variables** (not secrets) for `PROVIDER` and `BASE_URL` since they're not sensitive, and **secrets** for `API_KEY` as a fallback key name that works with any provider.

- [ ] **Step 6: Run CI checks**

Run: `cargo fmt -- --check && cargo clippy --all-targets -- -D warnings && cargo test`
Expected: All pass (shell script changes don't affect Rust CI).

- [ ] **Step 7: Commit**

```bash
git add scripts/evolve.sh .github/workflows/evolve.yml
git commit -m "feat: evolve.sh and CI support for multi-provider"
```

---

### Task 5: Update documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md` (if it exists — check first)

- [ ] **Step 1: Update CLAUDE.md**

In the "Build & Test Commands" section, add to the interactive run examples:

```bash
API_KEY=sk-or-... cargo run -- --provider openrouter --model anthropic/claude-sonnet-4
API_KEY=... cargo run -- --provider openai --model gpt-4o
cargo run -- --provider ollama --model llama3.1
```

In the "Architecture" section, add a brief note:

```
**Providers**: Defaults to Anthropic. Use `--provider <name>` for OpenRouter, OpenAI, Ollama, Groq, DeepSeek, Mistral, or xAI. Any OpenAI-compatible API works with `--provider openai --base-url <url>`.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add multi-provider usage examples"
```

---

### Task 6: Integration smoke test

This is a manual verification task — no code changes.

- [ ] **Step 1: Test Anthropic (default) still works**

Run: `ANTHROPIC_API_KEY=sk-... cargo run -- -p "say hello" --model claude-haiku-4-5-20251001`
Expected: Get a response, no errors.

- [ ] **Step 2: Test OpenRouter**

Run: `API_KEY=sk-or-... cargo run -- --provider openrouter --model anthropic/claude-haiku-4-5-20251001 -p "say hello"`
Expected: Get a response via OpenRouter.

- [ ] **Step 3: Test Ollama (if installed)**

Run: `cargo run -- --provider ollama --model llama3.2 -p "say hello"`
Expected: Get a response from local Ollama, no API key required.

- [ ] **Step 4: Test error on missing API key (non-ollama)**

Run: `cargo run -- --provider openrouter -p "test"` (with no API_KEY set)
Expected: Error message about missing API key.

- [ ] **Step 5: Test config file**

Create `.yoyo.toml`:
```toml
provider = "openrouter"
base_url = "https://openrouter.ai/api/v1"
model = "anthropic/claude-haiku-4-5-20251001"
```
Run: `API_KEY=sk-or-... cargo run -- -p "say hello"`
Expected: Uses OpenRouter from config file.
Clean up: `rm .yoyo.toml`
