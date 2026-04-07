# CT CLI — Full Flag & Argument Reference

## `ct init`

Scaffold a new CT project.

```
ct init <dir>
```

| Argument / Flag | Type | Required | Default | Description |
|---|---|---|---|---|
| `<dir>` | positional | yes | — | Directory name for the new project |
| `--dir` | string | no | `.` | Base directory in which `<dir>` is created |

Creates: `<dir>/main.ct`, `<dir>/values.json`.

---

## `ct template`

Render manifests to YAML (offline — no cluster access needed).

```
ct template <path> <release-name> [flags]
```

| Argument / Flag | Type | Required | Default | Description |
|---|---|---|---|---|
| `<path>` | positional | yes | — | Path to CT project directory |
| `<release-name>` | positional | yes | — | Release name (available as `Release.name` in code) |
| `--namespace`, `-n` | string | no | `"default"` | Kubernetes namespace (available as `Release.namespace`) |
| `--values` | string | no | `values.json` in `<path>` | Path to values file (JSON or YAML). Merged over built-in values |
| `--set` | string (repeatable) | no | — | Override individual value: `--set key=value`. Dot-notation supported: `--set image.tag=v2` |
| `--output` | string | no | stdout | Write rendered YAML to file instead of stdout |
| `--no-cache` | boolean | no | `false` | Skip local cache for GitHub URL imports — force re-download |

Exit codes: `0` success, `1` compilation/validation error.

---

## `ct apply`

Deploy manifests to a Kubernetes cluster. Uses server-side apply with inventory-based pruning — resources removed from code are automatically deleted from the cluster.

```
ct apply <path> <release-name> [flags]
```

| Argument / Flag | Type | Required | Default | Description |
|---|---|---|---|---|
| `<path>` | positional | yes | — | Path to CT project directory |
| `<release-name>` | positional | yes | — | Release name |
| `--namespace`, `-n` | string | no | `"default"` | Target Kubernetes namespace |
| `--create-namespace` | boolean | no | `false` | Create the namespace if it does not exist |
| `--values` | string | no | `values.json` in `<path>` | Path to values file |
| `--set` | string (repeatable) | no | — | Override individual value |
| `--context` | string | no | current context | Kubeconfig context to use |
| `--no-cache` | boolean | no | `false` | Force re-download of GitHub URL imports |
| `--output` | string | no | — | Also write rendered YAML to file (in addition to applying) |

Exit codes: `0` success, `1` compilation error, `2` apply error.

---

## `ct delete`

Remove all resources belonging to a release from the cluster. Uses inventory to determine which resources to delete.

```
ct delete <path> <release-name> [flags]
```

| Argument / Flag | Type | Required | Default | Description |
|---|---|---|---|---|
| `<path>` | positional | yes | — | Path to CT project directory |
| `<release-name>` | positional | yes | — | Release name to delete |
| `--namespace`, `-n` | string | no | `"default"` | Target Kubernetes namespace |
| `--context` | string | no | current context | Kubeconfig context to use |

Exit codes: `0` success, `1` error.

---

## `ct list`

List active CT releases.

```
ct list [flags]
```

| Argument / Flag | Type | Required | Default | Description |
|---|---|---|---|---|
| `--namespace`, `-n` | string | no | `"default"` | Namespace to list releases in |
| `--all-namespaces`, `-A` | boolean | no | `false` | List releases across all namespaces |
| `--context` | string | no | current context | Kubeconfig context to use |
| `--output` | string | no | `"table"` | Output format: `"table"`, `"json"`, `"yaml"` |

Output columns (table): NAME, NAMESPACE, RESOURCES, LAST APPLIED, STATUS.

---

## `ct types`

Generate TypeScript type definitions from `values.json` for editor IntelliSense.

```
ct types <path> [flags]
```

| Argument / Flag | Type | Required | Default | Description |
|---|---|---|---|---|
| `<path>` | positional | yes | — | Path to CT project directory |
| `--output` | string | no | `<path>` | Directory to write generated `.d.ts` files |
| `--operator` | boolean | no | `false` | Generate CRD types for operator mode |
| `--dev` | boolean | no | `false` | Include types for `dev.ct` globals (`config`, `dev`, `env`, `prompt`) |

Generated files:

| File | Contents |
|---|---|
| `values.d.ts` | `interface CtValues` derived from `values.json` schema |
| `globals.d.ts` | Global declarations: `Values: CtValues`, `Release: { name: string; namespace: string }` |

---

## Values resolution order

Values are merged in this order (later wins):

1. `values.json` in the project directory (base)
2. `--values <file>` (override file)
3. `--set key=value` (individual overrides, highest priority)

Deep merge is used — nested objects are merged, not replaced.

---

## GitHub URL import caching

All commands that evaluate `.ct` files (`template`, `apply`, `delete`, `types`) download and cache GitHub URL imports in `~/.ct/cache/`. Use `--no-cache` to force re-download.
