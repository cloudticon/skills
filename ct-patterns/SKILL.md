# CT Patterns — Resources, Factories & Imports

Use this skill when the user wants to define Kubernetes resources in CT, use high-level factories (`webApp`, `expose`), create platform-level shared factories (`createFactory`), define custom CRDs (`resource()`), or work with GitHub URL imports. Relevant trigger terms: `resource()`, `webApp`, `expose`, `createFactory`, `env.secret`, `vol.pvc`, `.ct files`, "import from GitHub", "shared factory", "CRD", "k8s-factories".

For full API specification see [reference.md](./reference.md).
For ready-to-use examples (Level 1–6) see [examples.md](./examples.md).

## `.ct` files and GitHub URL imports

### `.ct` files

All CT source files use the `.ct` extension. They are TypeScript files executed by the CT runtime. The entry point is `main.ct`; you can import from other local `.ct` files or from GitHub URLs.

### GitHub URL imports

CT resolves imports from GitHub repositories at build time:

```typescript
import { deployment } from "github.com/cloudticon/k8s@master/apps/v1";
import { webApp } from "github.com/cloudticon/k8s-factories@master";
import { myFactory } from "github.com/my-org/my-platform@v1.0.0/factories";
```

Format: `github.com/<org>/<repo>@<ref>/<path>`

- `<ref>` — git tag or branch: `@v1.0.0`, `@master`, `@main`
- `<path>` — file or directory path within the repo (without `.ct` extension)
- Cache: downloaded to `~/.ct/cache/`, use `--no-cache` to force refresh

Helm analogy: GitHub URL imports replace `Chart.yaml` dependencies, subcharts, and chart registries — no registry needed, just a git repo with a tag.

## Runtime globals

Available in every `.ct` file:

| Global | Type | Description | Helm analogy |
|---|---|---|---|
| `Values` | `CtValues` | Contents of `values.json`, typed via `ct types` | `.Values` |
| `Release` | `{ name: string; namespace: string }` | Release name and namespace from CLI args | `.Release.Name`, `.Release.Namespace` |

Generate types for IntelliSense: `ct types .` → produces `values.d.ts` + `globals.d.ts`.

## Two package layers

CT has two layers of packages for defining Kubernetes resources:

### Layer 1 (low-level): `github.com/cloudticon/k8s@master`

Typed factory functions for individual K8s resources. Each function takes a spec object and registers the resource in the manifest output.

```typescript
import { deployment, service } from "github.com/cloudticon/k8s@master/apps/v1";
import { configMap, secret } from "github.com/cloudticon/k8s@master/core/v1";
import { ingress } from "github.com/cloudticon/k8s@master/networking.k8s.io/v1";
```

Available modules:

| Import path | Resources |
|---|---|
| `core/v1` | `configMap`, `endpoints`, `limitRange`, `namespace`, `node`, `persistentVolume`, `persistentVolumeClaim`, `pod`, `secret`, `service`, `serviceAccount` |
| `apps/v1` | `deployment`, `daemonSet`, `replicaSet`, `statefulSet` |
| `batch/v1` | `cronJob`, `job` |
| `autoscaling/v2` | `horizontalPodAutoscaler` |
| `networking.k8s.io/v1` | `ingress`, `ingressClass`, `networkPolicy` |
| `policy/v1` | `podDisruptionBudget` |
| `rbac.authorization.k8s.io/v1` | `clusterRole`, `clusterRoleBinding`, `role`, `roleBinding` |
| `storage.k8s.io/v1` | `storageClass` |
| `cert-manager.io/v1` | `certificate`, `clusterIssuer`, `issuer` |
| `istio` | `virtualService`, `gateway`, `destinationRule`, `serviceEntry`, `sidecar`, `envoyFilter`, `proxyConfig`, `authorizationPolicy`, `peerAuthentication`, `telemetry`, `wasmplugin` |

Utilities (from root import):

```typescript
import { resource, z, toOpenAPI, operator, Result } from "github.com/cloudticon/k8s@master";
```

- `resource(apiVersion, kind, opts)` — define a typed factory for any CRD
- `z` — re-exported Zod for schema definitions
- `toOpenAPI` — convert Zod schema to OpenAPI
- `operator` — define a K8s operator
- `Result` — typed result container

### Layer 2 (high-level): `github.com/cloudticon/k8s-factories@master`

Opinionated helpers that produce multiple resources from a single config object.

```typescript
import { webApp, expose, env, vol, createFactory } from "github.com/cloudticon/k8s-factories@master";
```

## `webApp(config)` — Deployment + Service

Creates a Deployment and a Service from a single configuration object. Returns a `WebAppResult` that can be used as a `destination` in `expose()`.

```typescript
const app = webApp({
  name: "api",
  image: "myapp:v1",
  port: 8080,
  replicas: 2,
  resources: "medium",
  probes: "/health",
  env: {
    NODE_ENV: "production",
    DB_HOST: env.secret("db-credentials", "host"),
  },
  hpa: { min: 2, max: 10, cpu: 80 },
});
```

Key fields:

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Resource name (used for Deployment, Service, labels) |
| `image` | `string` | Container image |
| `port` | `number` | Container port (also used for Service targetPort) |
| `replicas` | `number` | Replica count (ignored when `hpa` is set) |
| `resources` | `"small" \| "medium" \| "large" \| ResourceSpec` | Resource requests/limits — preset name or explicit object |
| `probes` | `string \| ProbesConfig` | Probe config — string shorthand = HTTP GET path for all probes |
| `env` | `Record<string, string \| EnvRef>` | Environment variables (plain strings or `env.secret()`/`env.configMap()` refs) |
| `volumes` | `VolumeMount[]` | Volume mounts using `vol.*` helpers |
| `hpa` | `HPAConfig` | HorizontalPodAutoscaler config |
| `expose` | `ExposeConfig` | Inline expose config (alternative to standalone `expose()`) |
| `labels` | `Record<string, string>` | Additional labels merged onto all resources |
| `annotations` | `Record<string, string>` | Additional annotations |

Returns: `WebAppResult` — `{ deploy, svc }` used as `destination` in `expose()`.

## `expose(config)` — Routing (Istio or Ingress)

Set up traffic routing to `webApp` results. Supports two modes: **Istio** (VirtualService + Gateway + Certificate) and **Ingress** (K8s Ingress resource).

### Istio mode

```typescript
expose({
  host: "api.example.com",
  gateway: "istio-system/default",
  tls: { issuer: "letsencrypt-prod" },
  routes: [
    { prefix: "/api", destination: apiApp },
    { prefix: "/", destination: frontendApp },
  ],
});
```

### Ingress mode

```typescript
expose({
  type: "ingress",
  host: "api.example.com",
  ingressClassName: "nginx",
  tls: { secretName: "api-tls" },
  routes: [
    { prefix: "/api", destination: apiApp },
  ],
});
```

Route: `{ prefix: string, destination: WebAppResult }`.

When `tls.issuer` is set (Istio mode), CT automatically creates a Certificate resource and configures the Gateway for TLS.

## `env.*` helpers

```typescript
env.secret("secret-name", "key")      // valueFrom: secretKeyRef
env.configMap("configmap-name", "key") // valueFrom: configMapKeyRef
```

Use inside `webApp({ env: { ... } })` for referencing K8s Secrets and ConfigMaps.

## `vol.*` helpers

```typescript
vol.pvc({ name: "data", size: "10Gi", mountPath: "/data" })
vol.emptyDir({ mountPath: "/tmp" })
vol.configMap("my-config", { mountPath: "/etc/config" })
vol.secret("my-secret", { mountPath: "/etc/secrets" })
```

Use inside `webApp({ volumes: [...] })`.

## `createFactory()` — Platform shared factories

The key distribution pattern: `createFactory()` wraps `webApp` and `expose` with organizational defaults and returns new factory functions. Publish to GitHub, import in all projects.

```typescript
import { createFactory } from "github.com/cloudticon/k8s-factories@master";

export const { webApp, expose } = createFactory({
  networking: {
    type: "istio",
    gateway: "istio-system/default",
    tls: { issuer: "letsencrypt-prod" },
  },
  resourcePresets: {
    small: { requests: { cpu: "50m", memory: "64Mi" }, limits: { cpu: "200m", memory: "128Mi" } },
  },
  webApp: {
    defaults: { replicas: 2, probes: "/health", resources: "medium" },
    transform: (config) => ({
      ...config,
      labels: { ...config.labels, "managed-by": "platform" },
    }),
  },
  expose: {
    defaults: {},
    transform: (config) => config,
  },
});
```

Helm analogy: library chart + `_helpers.tpl` with defaults — but as regular TypeScript functions with types.

### `FactoryConfig`

| Field | Description |
|---|---|
| `networking` | Default routing type (`"istio"` or `"ingress"`), gateway, TLS settings |
| `resourcePresets` | Override built-in `small`/`medium`/`large` resource presets |
| `webApp.defaults` | Default values merged into every `webApp()` call |
| `webApp.transform` | Transform function applied to config before resource creation |
| `expose.defaults` | Default values merged into every `expose()` call |
| `expose.transform` | Transform function applied to expose config |

## `resource()` — Custom CRD factories

Define a typed factory function for any Custom Resource Definition using Zod schemas.

```typescript
import { resource, z } from "github.com/cloudticon/k8s@master";

const myDatabase = resource("databases.example.com/v1", "Database", {
  spec: z.object({
    engine: z.enum(["postgres", "mysql"]),
    version: z.string(),
    storage: z.string(),
    replicas: z.number().default(1),
  }),
  status: z.object({
    ready: z.boolean(),
    endpoint: z.string().optional(),
  }),
});

// usage — fully typed
myDatabase({
  metadata: { name: "my-db" },
  spec: {
    engine: "postgres",
    version: "15",
    storage: "50Gi",
    replicas: 3,
  },
});
```

Helm analogy: no equivalent — Helm has no typed CRD factories.

## Shared factories — Distribution pattern

1. Create a git repo (e.g., `github.com/my-org/my-platform`)
2. Export `createFactory()` result from a `.ct` file
3. Tag with semver: `v1.0.0`
4. Import in projects:

```typescript
import { webApp, expose } from "github.com/my-org/my-platform@v1.0.0/factories";
```

Versioning convention: `v1alpha1` → `v1beta1` → `v1` (follow K8s API versioning).

Helm analogy: publishing charts to OCI registry / ChartMuseum — but without a registry, just a git repo + tag.
