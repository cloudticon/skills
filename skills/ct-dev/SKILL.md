---
name: ct-dev
description: Set up a local Cloudticon development workflow with live file sync into a running pod, port forwarding and `dev.ct` configuration. Use when the user mentions `ct dev`, `dev.ct`, the `config()`, `dev()`, `env()` or `prompt()` globals, live reload, port forwarding, syncing files to a pod, or dev namespaces.
---

# CT Dev — Developer Mode

Use this skill when the user wants to set up a local development workflow with Cloudticon, live-sync files to a running pod, configure port forwarding, or work with `dev.ct` files. Relevant trigger terms: `ct dev`, `dev.ct`, `config()`, `dev()`, `env()`, `prompt()`, "live reload", "port forward", "sync to pod", "dev namespace".

For full API specification see [reference.md](./reference.md).

## What is `ct dev`?

`ct dev` launches an interactive development session against a Kubernetes cluster. It:

1. Reads `dev.ct` from the project directory
2. Calls `config()` to determine namespace and values overrides
3. Renders and applies manifests (same as `ct apply`)
4. For each `dev()` target: patches the deployment, syncs local files to the pod, forwards ports, optionally opens a terminal
5. Watches for file changes and re-syncs automatically
6. On exit (Ctrl+C): restores original deployments

## `dev.ct` structure

`dev.ct` is a TypeScript file with four global functions. All are optional except `dev()`.

```typescript
// dev.ct

config({
  namespace: `dev-${prompt("your name")}`,
  values: {
    image: { tag: "dev" },
    replicas: 1,
  },
});

dev({
  selector: { app: "api" },
  container: "api",
  sync: [
    { from: "./src", to: "/app/src" },
    { from: "./package.json", to: "/app/package.json" },
  ],
  ports: [3000, "9229:9229"],
  terminal: true,
  command: ["npm", "run", "dev"],
  env: {
    NODE_ENV: "development",
    DEBUG: env("DEBUG", "app:*"),
  },
  probes: false,
  replicas: 1,
});

dev({
  selector: { app: "worker" },
  sync: [{ from: "./src", to: "/app/src" }],
  ports: [3001],
});
```

### `config(options)`

Configure the dev session — override namespace and values.

```typescript
config({
  namespace: "dev-team-alpha",           // override namespace
  values: { image: { tag: "latest" } },  // deep-merged with values.json
});
```

- `namespace` — Kubernetes namespace for this dev session
- `values` — partial values object, deep-merged over `values.json`

### `dev(options)`

Define a dev target — a workload to sync files to, forward ports from, and optionally run commands in.

```typescript
dev({
  selector: { app: "api" },    // pod label selector (required)
  container: "api",            // target container name (optional if single-container pod)
  sync: [                      // file sync rules
    { from: "./src", to: "/app/src", exclude: ["*.test.ts"], polling: false },
  ],
  ports: [3000, "9229:9229"],  // port forwards: number | "local:remote"
  terminal: true,              // open interactive terminal in the container
  command: ["npm", "run", "dev"],  // override container command
  workingDir: "/app",          // override container workingDir
  image: "node:20-alpine",    // override container image
  env: { NODE_ENV: "development" },  // additional env vars
  probes: false,               // disable liveness/readiness probes during dev
  replicas: 1,                 // scale to N replicas during dev
});
```

You can call `dev()` multiple times — each call adds a dev target.

### `env(name, defaultValue?)`

Read an environment variable with optional default. Useful for per-developer or CI-specific configuration.

```typescript
config({
  namespace: env("CT_NAMESPACE", "dev-default"),
});

dev({
  selector: { app: "api" },
  env: {
    DATABASE_URL: env("DATABASE_URL", "postgres://localhost:5432/dev"),
    DEBUG: env("DEBUG"),
  },
  sync: [{ from: "./src", to: "/app/src" }],
});
```

Type coercion: `env()` always returns a string. For booleans/numbers, parse manually.

Supports `--env-file` flag to load a `.env` file before evaluating `dev.ct`.

### `prompt(message, options?)`

Interactively ask the developer for input at session start. Responses are cached in `~/.ct/dev-prompts.json`.

```typescript
const name = prompt("Enter your name");
const team = prompt("Select team", { choices: ["alpha", "beta", "gamma"] });

config({
  namespace: `dev-${name}`,
  values: { team },
});
```

Common pattern — per-developer namespace:

```typescript
config({
  namespace: `dev-${prompt("your name (lowercase, no spaces)")}`,
});
```

## CLI flags

```bash
ct dev <path> <release-name> [flags]
```

| Flag | Type | Default | Description |
|---|---|---|---|
| `--namespace`, `-n` | string | from `config()` or `"default"` | Override namespace (takes priority over `config()`) |
| `--env-file` | string | — | Load environment variables from file before evaluating `dev.ct` |
| `--context` | string | current context | Kubeconfig context |
| `--name` | string | — | Filter dev targets by name |
| `--delete` | boolean | `false` | Delete dev session resources and exit |

## Typical patterns

### Per-developer namespace with `prompt()`

```typescript
config({
  namespace: `dev-${prompt("your name")}`,
  values: { replicas: 1, image: { tag: "dev" } },
});
```

### CI/local combo with `env()` + `prompt()`

```typescript
const ns = env("CI_NAMESPACE") || `dev-${prompt("your name")}`;

config({
  namespace: ns,
  values: { image: { tag: env("IMAGE_TAG", "latest") } },
});
```

### Multi-service dev

```typescript
dev({
  selector: { app: "frontend" },
  sync: [{ from: "./frontend/src", to: "/app/src" }],
  ports: [3000],
  command: ["npm", "run", "dev"],
});

dev({
  selector: { app: "backend" },
  sync: [{ from: "./backend/src", to: "/app/src" }],
  ports: [8080, "5555:5555"],
  terminal: true,
});
```
