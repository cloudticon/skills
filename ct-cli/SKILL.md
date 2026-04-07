# CT CLI — Cloudticon Command-Line Interface

Use this skill when the user wants to create, render, deploy, or manage Kubernetes manifests using Cloudticon (CT). Relevant trigger terms: `ct init`, `ct template`, `ct apply`, `ct delete`, `ct list`, `ct types`, main.ct, values.json, "render YAML", "deploy to cluster", "generate K8s manifests".

For full flag/argument specification see [reference.md](./reference.md).

## What is Cloudticon?

Cloudticon (CT) is a tool for defining Kubernetes manifests in TypeScript — a type-safe alternative to Helm. Instead of Go templates you write `.ct` files (TypeScript), and instead of `values.yaml` you use `values.json` (with generated types).

### Helm ↔ CT analogy

| Helm | CT | Notes |
|---|---|---|
| `helm create` | `ct init` | Scaffold a new project |
| `helm template` | `ct template` | Render manifests to YAML (no cluster needed) |
| `helm upgrade --install` | `ct apply` | Server-side apply + inventory pruning |
| `helm uninstall` | `ct delete` | Remove release from cluster |
| `helm list` | `ct list` | List active releases |
| `templates/*.yaml` (Go) | `main.ct` (TypeScript) | Entry point |
| `values.yaml` | `values.json` | Input values (typed via `ct types`) |
| Chart dependencies / subcharts | GitHub URL imports | No registry needed — just git |

## Project structure

```
my-project/
  main.ct          # entry point — TypeScript that produces K8s resources
  values.json      # input values consumed via global `Values` object
  values.d.ts      # (generated) TypeScript types for Values
  globals.d.ts     # (generated) global types (Values, Release)
```

## Workflow

```
ct init my-project        # 1. scaffold
cd my-project
$EDITOR main.ct           # 2. write TypeScript resources
ct types .                # 3. generate types for IntelliSense
ct template . my-release  # 4. render YAML locally
ct apply . my-release     # 5. deploy to cluster
```

## Commands

### `ct init <dir>`

Scaffold a new CT project in `<dir>`. Creates `main.ct` and `values.json`.

```bash
ct init my-app
```

### `ct template <path> <release-name>`

Render manifests to YAML without touching a cluster. Use for CI validation, piping to `kubectl`, or inspecting output.

```bash
# render to stdout
ct template . my-release --namespace production

# render with custom values
ct template . my-release -n production --values prod-values.json

# override a single value
ct template . my-release --set image.tag=v2.1.0

# save to file
ct template . my-release -n production --output manifests.yaml

# pipe to kubectl diff
ct template . my-release -n production | kubectl diff -f -
```

Key flags: `--namespace (-n)`, `--values`, `--set`, `--output`, `--no-cache`.

### `ct apply <path> <release-name>`

Deploy manifests to a Kubernetes cluster using server-side apply with inventory-based pruning (resources removed from code are deleted from the cluster).

```bash
# basic deploy
ct apply . my-release --namespace production

# create namespace if missing
ct apply . my-release -n production --create-namespace

# target a specific kubeconfig context
ct apply . my-release -n production --context my-cluster

# with custom values
ct apply . my-release -n production --values prod-values.json --set image.tag=v2.1.0
```

Key flags: `--namespace (-n)`, `--create-namespace`, `--values`, `--set`, `--context`, `--no-cache`, `--output`.

### `ct delete <path> <release-name>`

Remove all resources belonging to a release from the cluster (inventory-based deletion).

```bash
ct delete . my-release --namespace production
ct delete . my-release -n production --context my-cluster
```

Key flags: `--namespace (-n)`, `--context`.

### `ct list`

List active releases (similar to `helm list`).

```bash
ct list --namespace production
ct list --all-namespaces
ct list -A --output json
ct list --context my-cluster
```

Key flags: `--namespace (-n)`, `--all-namespaces (-A)`, `--context`, `--output`.

### `ct types <path>`

Generate TypeScript type definitions from `values.json` for IntelliSense support. Outputs `values.d.ts` and `globals.d.ts`.

```bash
ct types .
ct types . --output types/
ct types . --operator    # generate operator CRD types
ct types . --dev         # include dev.ct types
```

Key flags: `--output`, `--operator`, `--dev`.

## Runtime globals in `main.ct`

Two global objects are available inside `.ct` files:

- **`Values`** — contents of `values.json`, typed via generated `values.d.ts`. Helm analogy: `.Values`.
- **`Release`** — `{ name, namespace }` from CLI arguments. Helm analogy: `.Release.Name` / `.Release.Namespace`.

## Common patterns

### Minimal main.ct

```typescript
import { deployment, service } from "github.com/cloudticon/k8s@master/apps/v1";

deployment({
  metadata: { name: Release.name },
  spec: {
    replicas: Values.replicas ?? 1,
    selector: { matchLabels: { app: Release.name } },
    template: {
      metadata: { labels: { app: Release.name } },
      spec: {
        containers: [{
          name: "app",
          image: `${Values.image.repository}:${Values.image.tag}`,
          ports: [{ containerPort: Values.port ?? 8080 }],
        }],
      },
    },
  },
});

service({
  metadata: { name: Release.name },
  spec: {
    selector: { app: Release.name },
    ports: [{ port: 80, targetPort: Values.port ?? 8080 }],
  },
});
```

### Using high-level factories

```typescript
import { webApp, expose } from "github.com/cloudticon/k8s-factories@master";

const app = webApp({
  name: Release.name,
  image: `${Values.image.repository}:${Values.image.tag}`,
  port: 8080,
  replicas: 2,
  resources: "medium",
  probes: "/health",
});

expose({
  host: Values.domain,
  routes: [{ prefix: "/", destination: app }],
});
```
