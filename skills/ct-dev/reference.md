# CT Dev — Full API Reference

## `config(options: ConfigOptions)`

Configure the dev session. Called at most once in `dev.ct`.

### `ConfigOptions`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `namespace` | `string` | no | `"default"` | Kubernetes namespace for the dev session. Can be overridden by `--namespace` CLI flag |
| `values` | `Record<string, any>` | no | `{}` | Partial values object. Deep-merged over `values.json` — nested objects are merged, primitives are replaced |

Deep merge behavior:

```typescript
// values.json
{ "image": { "repository": "myapp", "tag": "v1" }, "replicas": 3 }

// config() call
config({ values: { image: { tag: "dev" }, replicas: 1 } });

// effective values
{ "image": { "repository": "myapp", "tag": "dev" }, "replicas": 1 }
```

---

## `dev(options: DevTargetOptions)`

Define a workload to develop against. Can be called multiple times — each call registers a separate dev target.

### `DevTargetOptions`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `selector` | `Record<string, string>` | **yes** | — | Pod label selector. Must match exactly one Deployment/StatefulSet/DaemonSet |
| `container` | `string` | no | first container | Target container name. Required only for multi-container pods |
| `sync` | `SyncRule[]` | no | `[]` | File synchronization rules (see below) |
| `ports` | `(number \| string)[]` | no | `[]` | Port forwards. `number` = same local and remote port. `string` = `"localPort:remotePort"` |
| `terminal` | `boolean` | no | `false` | Open an interactive terminal session in the container after sync is established |
| `command` | `string[]` | no | original command | Override the container's command (entrypoint). Replaces both `command` and `args` |
| `workingDir` | `string` | no | original workingDir | Override the container's working directory |
| `image` | `string` | no | original image | Override the container image (useful for dev-specific images with debug tools) |
| `env` | `Record<string, string>` | no | `{}` | Additional environment variables injected into the container. Merged with existing env — does not replace |
| `probes` | `boolean` | no | `true` | Set to `false` to disable liveness, readiness, and startup probes during dev (prevents restarts during hot reload) |
| `replicas` | `number` | no | original replicas | Scale the workload to this many replicas during dev. Typically set to `1` to avoid sync conflicts |

---

## `SyncRule`

Defines how local files are synchronized to the container filesystem.

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `from` | `string` | **yes** | — | Local path (relative to project root). Can be a file or directory |
| `to` | `string` | **yes** | — | Absolute path inside the container |
| `exclude` | `string[]` | no | `[]` | Glob patterns to exclude from sync (e.g., `["node_modules", "*.test.ts", ".git"]`) |
| `polling` | `boolean` | no | `false` | Use polling instead of filesystem events. Enable when working on network-mounted volumes or certain WSL setups |

Sync behavior:

- Initial sync: full copy of `from` → `to`
- Subsequent: incremental — only changed files are transferred
- Deletions: files deleted locally are also deleted in the container
- Direction: one-way (local → container only)

```typescript
sync: [
  { from: "./src", to: "/app/src", exclude: ["**/*.test.ts"] },
  { from: "./config", to: "/app/config" },
  { from: "./package.json", to: "/app/package.json" },
]
```

---

## `env(name: string, defaultValue?: string): string`

Read an environment variable from the host machine.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | **yes** | Environment variable name |
| `defaultValue` | `string` | no | Fallback value if variable is not set |

Returns: `string` — the value of the environment variable or `defaultValue`. Throws if variable is not set and no default is provided.

Type coercion: `env()` always returns a `string`. For other types, parse explicitly:

```typescript
const debug = env("DEBUG", "false") === "true";
const port = parseInt(env("PORT", "3000"), 10);
```

Environment loading order:

1. System environment variables
2. Variables from `--env-file <path>` (if specified)
3. Later sources override earlier ones

---

## `prompt(message: string, options?: PromptOptions): string`

Interactively ask the developer for input. Displayed once per unique message; responses are cached.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `message` | `string` | **yes** | Question text displayed to the developer |
| `options` | `PromptOptions` | no | Additional configuration |

### `PromptOptions`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `choices` | `string[]` | no | — | When provided, shows a selection list instead of free-text input |

Returns: `string` — the user's response.

Caching behavior:

- Responses are cached in `~/.ct/dev-prompts.json` keyed by the message text
- On subsequent runs, the cached value is used without prompting
- To re-prompt, delete the cache file or the specific entry
- `choices` are not part of the cache key — only the message text matters

```typescript
const name = prompt("Enter your name");
// cached as: { "Enter your name": "alice" }

const team = prompt("Select team", { choices: ["alpha", "beta", "gamma"] });
// presents a selection list; cached once selected
```

---

## CLI: `ct dev`

```
ct dev <path> <release-name> [flags]
```

| Argument / Flag | Type | Required | Default | Description |
|---|---|---|---|---|
| `<path>` | positional | yes | — | Path to CT project directory (must contain `dev.ct`) |
| `<release-name>` | positional | yes | — | Release name |
| `--namespace`, `-n` | string | no | from `config()` or `"default"` | Override namespace. Takes priority over `config({ namespace })` |
| `--env-file` | string | no | — | Path to `.env` file. Loaded before `dev.ct` is evaluated |
| `--context` | string | no | current context | Kubeconfig context to use |
| `--name` | string | no | — | Run only dev targets matching this name (by selector label value) |
| `--delete` | boolean | no | `false` | Tear down dev session (restore original deployments) and exit |

### Lifecycle

1. Load `--env-file` (if provided)
2. Evaluate `dev.ct` — calls to `config()`, `dev()`, `env()`, `prompt()` are registered
3. Render and apply manifests (equivalent to `ct apply`)
4. For each `dev()` target:
   a. Patch workload (override image, command, env, probes, replicas)
   b. Wait for pod to be ready
   c. Start file sync (initial full copy, then incremental)
   d. Establish port forwards
   e. Open terminal (if `terminal: true`)
5. Watch for local file changes → re-sync
6. On Ctrl+C or `--delete`: restore original workload specs, remove patches
