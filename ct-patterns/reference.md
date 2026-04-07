# CT Patterns — Full API Reference

## `resource(apiVersion, kind, opts)` — Custom resource factory

Create a typed factory function for any Kubernetes resource or CRD.

### Signature

```typescript
function resource<S extends z.ZodType, St extends z.ZodType>(
  apiVersion: string,
  kind: string,
  opts?: ResourceOpts<S, St>
): ResourceFn<S>
```

### `ResourceOpts<S, St>`

| Field | Type | Required | Description |
|---|---|---|---|
| `spec` | `z.ZodType` | no | Zod schema for the `spec` field |
| `status` | `z.ZodType` | no | Zod schema for the `status` field (informational — not sent to cluster) |

### `ResourceFn<S>`

The returned factory function accepts:

```typescript
function resourceFn(args: MetadataArgs & { spec: z.infer<S> }): Result
```

### `MetadataArgs`

| Field | Type | Required | Description |
|---|---|---|---|
| `metadata.name` | `string` | **yes** | Resource name |
| `metadata.namespace` | `string` | no | Namespace (defaults to release namespace) |
| `metadata.labels` | `Record<string, string>` | no | Labels |
| `metadata.annotations` | `Record<string, string>` | no | Annotations |

### Example

```typescript
import { resource, z } from "github.com/cloudticon/k8s@master";

const redisCluster = resource("redis.example.com/v1alpha1", "RedisCluster", {
  spec: z.object({
    replicas: z.number().min(1).max(10).default(3),
    version: z.string().default("7.2"),
    storage: z.string().default("10Gi"),
    resources: z.object({
      requests: z.object({ cpu: z.string(), memory: z.string() }),
      limits: z.object({ cpu: z.string(), memory: z.string() }),
    }).optional(),
  }),
});

redisCluster({
  metadata: { name: "cache" },
  spec: { replicas: 3, version: "7.2", storage: "20Gi" },
});
```

---

## `webApp(config: WebAppConfig)` — Deployment + Service

### `WebAppConfig`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | **yes** | — | Resource name for Deployment, Service, labels |
| `image` | `string` | **yes** | — | Container image (e.g., `"myapp:v1"`) |
| `port` | `number` | **yes** | — | Container port. Also used as Service `targetPort` |
| `replicas` | `number` | no | `1` | Replica count. Ignored when `hpa` is configured |
| `resources` | `ResourcePreset \| ResourceSpec` | no | — | Resource requests/limits (see Resource Presets below) |
| `env` | `Record<string, string \| EnvRef>` | no | `{}` | Environment variables — plain strings or `env.secret()`/`env.configMap()` refs |
| `volumes` | `VolumeMount[]` | no | `[]` | Volume mounts using `vol.*` helpers |
| `probes` | `string \| ProbesConfig` | no | — | Health probes (see Probes below) |
| `hpa` | `HPAConfig` | no | — | HorizontalPodAutoscaler configuration |
| `expose` | `ExposeConfig` | no | — | Inline expose configuration (alternative to standalone `expose()`) |
| `labels` | `Record<string, string>` | no | `{}` | Additional labels merged onto all generated resources |
| `annotations` | `Record<string, string>` | no | `{}` | Additional annotations merged onto all generated resources |
| `serviceType` | `string` | no | `"ClusterIP"` | Service type: `"ClusterIP"`, `"NodePort"`, `"LoadBalancer"` |
| `imagePullSecrets` | `string[]` | no | `[]` | Image pull secret names |
| `nodeSelector` | `Record<string, string>` | no | — | Node selector for pod scheduling |
| `tolerations` | `Toleration[]` | no | `[]` | Pod tolerations |
| `affinity` | `Affinity` | no | — | Pod affinity/anti-affinity rules |
| `serviceAccount` | `string` | no | — | ServiceAccount name to use |
| `initContainers` | `Container[]` | no | `[]` | Init containers added to the pod spec |
| `command` | `string[]` | no | — | Override container command |
| `args` | `string[]` | no | — | Override container args |

### `WebAppResult`

Returned by `webApp()`:

| Field | Type | Description |
|---|---|---|
| `deploy` | `Deployment` | The created Deployment resource |
| `svc` | `Service` | The created Service resource |

Used as `destination` in `expose()` routes.

---

## `expose(config)` — Routing

### Istio mode: `IstioExposeConfig`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `host` | `string` | **yes** | — | Hostname (e.g., `"api.example.com"`) |
| `gateway` | `string` | no | from factory defaults | Gateway reference: `"namespace/name"` |
| `tls` | `TLSConfig` | no | — | TLS configuration |
| `routes` | `Route[]` | **yes** | — | Routing rules |
| `corsPolicy` | `CorsPolicy` | no | — | CORS configuration on the VirtualService |
| `timeout` | `string` | no | — | Request timeout (e.g., `"30s"`) |
| `retries` | `RetryPolicy` | no | — | Retry configuration |
| `headers` | `HeaderOperations` | no | — | Request/response header manipulation |

### Ingress mode: `IngressExposeConfig`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `type` | `"ingress"` | **yes** | — | Must be `"ingress"` to select Ingress mode |
| `host` | `string` | **yes** | — | Hostname |
| `ingressClassName` | `string` | no | — | Ingress class (e.g., `"nginx"`, `"traefik"`) |
| `tls` | `IngressTLSConfig` | no | — | TLS configuration |
| `routes` | `Route[]` | **yes** | — | Routing rules |
| `annotations` | `Record<string, string>` | no | `{}` | Ingress annotations |

### `TLSConfig` (Istio)

| Field | Type | Required | Description |
|---|---|---|---|
| `issuer` | `string` | no | cert-manager ClusterIssuer name. When set, auto-creates a Certificate resource and configures the Gateway |
| `secretName` | `string` | no | Existing TLS secret name (alternative to `issuer`) |
| `mode` | `string` | no | TLS mode: `"SIMPLE"`, `"MUTUAL"`, `"PASSTHROUGH"` (default: `"SIMPLE"`) |

### `IngressTLSConfig`

| Field | Type | Required | Description |
|---|---|---|---|
| `secretName` | `string` | no | TLS secret name |
| `issuer` | `string` | no | cert-manager annotation for automatic certificate |

### `Route`

| Field | Type | Required | Description |
|---|---|---|---|
| `prefix` | `string` | **yes** | URL path prefix (e.g., `"/"`, `"/api"`) |
| `destination` | `WebAppResult` | **yes** | Target — result of `webApp()` |
| `rewrite` | `string` | no | Rewrite the path prefix before forwarding |

---

## `createFactory(config: FactoryConfig)` — Platform factories

### `FactoryConfig`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `networking` | `NetworkingConfig` | no | — | Default networking settings for `expose()` |
| `resourcePresets` | `Record<string, ResourceSpec>` | no | `DEFAULT_RESOURCE_PRESETS` | Override or extend built-in resource presets |
| `webApp` | `WebAppFactoryConfig` | no | — | Defaults and transform for `webApp()` |
| `expose` | `ExposeFactoryConfig` | no | — | Defaults and transform for `expose()` |

### `NetworkingConfig`

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | `"istio" \| "ingress"` | **yes** | Default routing type |
| `gateway` | `string` | no | Default Istio gateway (`"namespace/name"`) |
| `tls` | `TLSConfig` | no | Default TLS configuration |
| `ingressClassName` | `string` | no | Default Ingress class name |

### `WebAppFactoryConfig`

| Field | Type | Description |
|---|---|---|
| `defaults` | `Partial<WebAppConfig>` | Default values deep-merged into every `webApp()` call |
| `transform` | `(config: WebAppConfig) => WebAppConfig` | Transform applied after merging defaults, before resource creation |

### `ExposeFactoryConfig`

| Field | Type | Description |
|---|---|---|
| `defaults` | `Partial<ExposeConfig>` | Default values deep-merged into every `expose()` call |
| `transform` | `(config: ExposeConfig) => ExposeConfig` | Transform applied after merging defaults |

### `FactoryResult`

Returned by `createFactory()`:

| Field | Type | Description |
|---|---|---|
| `webApp` | `(config: WebAppConfig) => WebAppResult` | Factory-configured `webApp` function |
| `expose` | `(config: ExposeConfig) => void` | Factory-configured `expose` function |

Merge order for `webApp`: `factoryDefaults` → `callConfig` → `transform()`.
Merge order for `expose`: `factoryDefaults` + `networkingDefaults` → `callConfig` → `transform()`.

---

## `env.*` — Environment variable helpers

### `env.secret(secretName, key)`

Reference a value from a Kubernetes Secret.

| Parameter | Type | Description |
|---|---|---|
| `secretName` | `string` | Name of the Secret resource |
| `key` | `string` | Key within the Secret's `data` |

Produces: `valueFrom: { secretKeyRef: { name, key } }`.

### `env.configMap(configMapName, key)`

Reference a value from a Kubernetes ConfigMap.

| Parameter | Type | Description |
|---|---|---|
| `configMapName` | `string` | Name of the ConfigMap resource |
| `key` | `string` | Key within the ConfigMap's `data` |

Produces: `valueFrom: { configMapKeyRef: { name, key } }`.

### Usage

```typescript
webApp({
  name: "api",
  image: "api:v1",
  port: 8080,
  env: {
    DB_PASSWORD: env.secret("db-credentials", "password"),
    DB_HOST: env.secret("db-credentials", "host"),
    APP_CONFIG: env.configMap("app-settings", "config.json"),
    NODE_ENV: "production",  // plain string
  },
});
```

---

## `vol.*` — Volume helpers

### `vol.pvc(opts)`

Persistent Volume Claim mount.

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | **yes** | — | PVC name (created if it doesn't exist) |
| `mountPath` | `string` | **yes** | — | Mount path inside the container |
| `size` | `string` | **yes** | — | Storage size (e.g., `"10Gi"`) |
| `storageClass` | `string` | no | cluster default | StorageClass name |
| `accessModes` | `string[]` | no | `["ReadWriteOnce"]` | Access modes |
| `subPath` | `string` | no | — | Sub-path within the volume |

### `vol.emptyDir(opts?)`

EmptyDir volume (ephemeral, pod-scoped).

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `mountPath` | `string` | **yes** | — | Mount path |
| `medium` | `string` | no | `""` | `"Memory"` for tmpfs |
| `sizeLimit` | `string` | no | — | Size limit (e.g., `"1Gi"`) |

### `vol.configMap(name, opts)`

Mount a ConfigMap as files.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | **yes** | ConfigMap name |
| `opts.mountPath` | `string` | **yes** | Mount path |
| `opts.items` | `{ key, path }[]` | no | Select specific keys |
| `opts.defaultMode` | `number` | no | File permission mode (e.g., `0o644`) |

### `vol.secret(name, opts)`

Mount a Secret as files.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | **yes** | Secret name |
| `opts.mountPath` | `string` | **yes** | Mount path |
| `opts.items` | `{ key, path }[]` | no | Select specific keys |
| `opts.defaultMode` | `number` | no | File permission mode |

---

## Probes

### String shorthand

```typescript
probes: "/health"
```

Sets HTTP GET path for all three probes (liveness, readiness, startup) with sensible defaults.

### `ProbesConfig`

| Field | Type | Default | Description |
|---|---|---|---|
| `liveness` | `ProbeDetail \| string \| false` | — | Liveness probe config. `string` = HTTP GET path. `false` = disabled |
| `readiness` | `ProbeDetail \| string \| false` | — | Readiness probe config |
| `startup` | `ProbeDetail \| string \| false` | — | Startup probe config |

### `ProbeDetail`

| Field | Type | Default | Description |
|---|---|---|---|
| `path` | `string` | — | HTTP GET path (e.g., `"/health"`) |
| `port` | `number` | container port | Target port |
| `initialDelaySeconds` | `number` | `0` | Delay before first probe |
| `periodSeconds` | `number` | `10` | Interval between probes |
| `timeoutSeconds` | `number` | `1` | Probe timeout |
| `failureThreshold` | `number` | `3` | Failures before unhealthy |
| `successThreshold` | `number` | `1` | Successes before healthy |
| `scheme` | `string` | `"HTTP"` | `"HTTP"` or `"HTTPS"` |

### Examples

```typescript
// all probes on /health
probes: "/health"

// different paths per probe
probes: {
  liveness: "/healthz",
  readiness: "/ready",
  startup: { path: "/startup", failureThreshold: 30, periodSeconds: 2 },
}

// only readiness, no liveness or startup
probes: {
  readiness: "/ready",
  liveness: false,
  startup: false,
}
```

---

## HPA — `HPAConfig`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `min` | `number` | **yes** | — | Minimum replicas |
| `max` | `number` | **yes** | — | Maximum replicas |
| `cpu` | `number` | no | — | Target CPU utilization percentage (e.g., `80`) |
| `memory` | `number` | no | — | Target memory utilization percentage |
| `scaleDown` | `ScalePolicy` | no | — | Scale-down behavior |
| `scaleUp` | `ScalePolicy` | no | — | Scale-up behavior |

### `ScalePolicy`

| Field | Type | Description |
|---|---|---|
| `stabilizationWindowSeconds` | `number` | Stabilization window |
| `policies` | `{ type: "Pods" \| "Percent", value: number, periodSeconds: number }[]` | Scaling policies |

---

## Resource presets — `DEFAULT_RESOURCE_PRESETS`

| Preset | requests.cpu | requests.memory | limits.cpu | limits.memory |
|---|---|---|---|---|
| `"small"` | `"100m"` | `"128Mi"` | `"500m"` | `"256Mi"` |
| `"medium"` | `"250m"` | `"256Mi"` | `"1000m"` | `"512Mi"` |
| `"large"` | `"500m"` | `"512Mi"` | `"2000m"` | `"1Gi"` |

Override presets via `createFactory({ resourcePresets: { ... } })`.

### `ResourceSpec`

```typescript
interface ResourceSpec {
  requests: { cpu: string; memory: string };
  limits: { cpu: string; memory: string };
}
```
