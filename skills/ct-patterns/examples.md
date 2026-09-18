# CT Patterns — Examples (Level 1–6)

## Level 1: Simple service with `webApp()` + inline expose

A single web application with Istio routing — minimal configuration.

```typescript
// main.ct
import { webApp } from "github.com/cloudticon/k8s-factories@master";

webApp({
  name: Release.name,
  image: `${Values.image.repository}:${Values.image.tag}`,
  port: 8080,
  replicas: 2,
  resources: "small",
  probes: "/health",
  expose: {
    host: Values.domain,
    gateway: "istio-system/default",
    routes: [{ prefix: "/" }],
  },
});
```

```json
// values.json
{
  "image": { "repository": "myapp", "tag": "v1.0.0" },
  "domain": "myapp.example.com"
}
```

Produces: Deployment, Service, VirtualService.

---

## Level 2: Multi-service routing with `expose()` + TLS

Multiple services behind a single hostname with path-based routing and automatic TLS certificate.

```typescript
// main.ct
import { webApp, expose } from "github.com/cloudticon/k8s-factories@master";

const frontend = webApp({
  name: "frontend",
  image: `${Values.frontend.image}:${Values.frontend.tag}`,
  port: 3000,
  replicas: 2,
  resources: "small",
  probes: "/health",
});

const api = webApp({
  name: "api",
  image: `${Values.api.image}:${Values.api.tag}`,
  port: 8080,
  replicas: 3,
  resources: "medium",
  probes: "/health",
});

expose({
  host: Values.domain,
  gateway: "istio-system/default",
  tls: { issuer: "letsencrypt-prod" },
  routes: [
    { prefix: "/api", destination: api },
    { prefix: "/", destination: frontend },
  ],
});
```

```json
// values.json
{
  "domain": "myapp.example.com",
  "frontend": { "image": "myapp-frontend", "tag": "v2.0.0" },
  "api": { "image": "myapp-api", "tag": "v1.5.0" }
}
```

Produces: 2x Deployment, 2x Service, VirtualService, Gateway, Certificate.

---

## Level 3: Service with volumes, env secrets, probes, HPA

Full-featured application with persistent storage, secret references, detailed probes, and autoscaling.

```typescript
// main.ct
import { webApp, expose, env, vol } from "github.com/cloudticon/k8s-factories@master";

const app = webApp({
  name: Release.name,
  image: `${Values.image.repository}:${Values.image.tag}`,
  port: 8080,
  resources: {
    requests: { cpu: "200m", memory: "256Mi" },
    limits: { cpu: "1000m", memory: "1Gi" },
  },
  env: {
    NODE_ENV: "production",
    DB_HOST: env.secret("db-credentials", "host"),
    DB_PORT: env.secret("db-credentials", "port"),
    DB_USER: env.secret("db-credentials", "username"),
    DB_PASSWORD: env.secret("db-credentials", "password"),
    REDIS_URL: env.configMap("app-config", "redis-url"),
    LOG_LEVEL: Values.logLevel ?? "info",
  },
  volumes: [
    vol.pvc({ name: "data", size: "50Gi", mountPath: "/app/data", storageClass: "fast-ssd" }),
    vol.emptyDir({ mountPath: "/tmp" }),
    vol.configMap("app-config", { mountPath: "/etc/app" }),
    vol.secret("tls-certs", { mountPath: "/etc/tls", defaultMode: 0o400 }),
  ],
  probes: {
    liveness: { path: "/healthz", periodSeconds: 15, failureThreshold: 3 },
    readiness: { path: "/ready", periodSeconds: 5, failureThreshold: 2 },
    startup: { path: "/startup", failureThreshold: 30, periodSeconds: 2 },
  },
  hpa: {
    min: Values.hpa?.min ?? 2,
    max: Values.hpa?.max ?? 20,
    cpu: 75,
    memory: 80,
    scaleDown: { stabilizationWindowSeconds: 300 },
  },
  labels: { team: "backend", tier: "api" },
  annotations: { "prometheus.io/scrape": "true", "prometheus.io/port": "8080" },
});

expose({
  host: Values.domain,
  gateway: "istio-system/default",
  tls: { issuer: "letsencrypt-prod" },
  routes: [{ prefix: "/", destination: app }],
  timeout: "30s",
  retries: { attempts: 3, perTryTimeout: "10s" },
});
```

```json
// values.json
{
  "image": { "repository": "myapp", "tag": "v3.0.0" },
  "domain": "api.example.com",
  "logLevel": "info",
  "hpa": { "min": 3, "max": 15 }
}
```

Produces: Deployment, Service, PVC, HPA, VirtualService, Gateway, Certificate.

---

## Level 4: Ingress instead of Istio

Same application but using Kubernetes Ingress (e.g., nginx) instead of Istio.

```typescript
// main.ct
import { webApp, expose, env } from "github.com/cloudticon/k8s-factories@master";

const app = webApp({
  name: Release.name,
  image: `${Values.image.repository}:${Values.image.tag}`,
  port: 8080,
  replicas: 3,
  resources: "medium",
  probes: "/health",
  env: {
    NODE_ENV: "production",
    DB_URL: env.secret("db-credentials", "url"),
  },
});

expose({
  type: "ingress",
  host: Values.domain,
  ingressClassName: "nginx",
  tls: { issuer: "letsencrypt-prod" },
  annotations: {
    "nginx.ingress.kubernetes.io/proxy-body-size": "50m",
    "nginx.ingress.kubernetes.io/rate-limit": "100",
  },
  routes: [{ prefix: "/", destination: app }],
});
```

```json
// values.json
{
  "image": { "repository": "myapp", "tag": "v2.0.0" },
  "domain": "app.example.com"
}
```

Produces: Deployment, Service, Ingress (with cert-manager annotation for TLS).

---

## Level 5: `createFactory()` — Platform factory with defaults and transform

Define organizational defaults in a reusable factory. All teams import this instead of raw `webApp`/`expose`.

```typescript
// platform.ct — published at github.com/my-org/my-platform@v1.0.0/platform
import { createFactory } from "github.com/cloudticon/k8s-factories@master";

export const { webApp, expose } = createFactory({
  networking: {
    type: "istio",
    gateway: "istio-system/shared-gateway",
    tls: { issuer: "letsencrypt-prod" },
  },
  resourcePresets: {
    small:  { requests: { cpu: "50m",  memory: "64Mi"  }, limits: { cpu: "200m",  memory: "128Mi" } },
    medium: { requests: { cpu: "200m", memory: "256Mi" }, limits: { cpu: "500m",  memory: "512Mi" } },
    large:  { requests: { cpu: "500m", memory: "512Mi" }, limits: { cpu: "2000m", memory: "2Gi"   } },
  },
  webApp: {
    defaults: {
      replicas: 2,
      probes: "/health",
      resources: "medium",
      labels: { "platform.io/managed": "true" },
    },
    transform: (config) => ({
      ...config,
      labels: {
        ...config.labels,
        "app.kubernetes.io/managed-by": "platform",
        "app.kubernetes.io/part-of": config.name,
      },
      annotations: {
        ...config.annotations,
        "prometheus.io/scrape": "true",
        "prometheus.io/port": String(config.port),
      },
    }),
  },
  expose: {
    defaults: {},
    transform: (config) => ({
      ...config,
      timeout: config.timeout ?? "30s",
    }),
  },
});
```

Usage in a project:

```typescript
// main.ct — consuming the platform factory
import { webApp, expose } from "github.com/my-org/my-platform@v1.0.0/platform";

const app = webApp({
  name: Release.name,
  image: `${Values.image.repository}:${Values.image.tag}`,
  port: 8080,
  // replicas, probes, resources inherited from factory defaults
  // labels and annotations added by factory transform
});

expose({
  host: Values.domain,
  // gateway, tls inherited from factory networking defaults
  routes: [{ prefix: "/", destination: app }],
});
```

---

## Level 6: Shared factory on GitHub — multi-project import

End-to-end example: platform team publishes a factory, application teams consume it.

### Step 1 — Platform team: create and publish

Repository: `github.com/acme-corp/k8s-platform`

```typescript
// factories.ct
import { createFactory } from "github.com/cloudticon/k8s-factories@master";
import { resource, z } from "github.com/cloudticon/k8s@master";

export const backendDatabase = resource("databases.acme.io/v1", "ManagedDatabase", {
  spec: z.object({
    engine: z.enum(["postgres", "mysql", "redis"]),
    version: z.string(),
    storage: z.string().default("10Gi"),
    backup: z.object({
      enabled: z.boolean().default(true),
      schedule: z.string().default("0 2 * * *"),
    }).default({}),
  }),
});

export const { webApp, expose } = createFactory({
  networking: {
    type: "istio",
    gateway: "istio-system/acme-gateway",
    tls: { issuer: "letsencrypt-prod" },
  },
  resourcePresets: {
    small:  { requests: { cpu: "50m",  memory: "64Mi"  }, limits: { cpu: "200m",  memory: "128Mi" } },
    medium: { requests: { cpu: "250m", memory: "256Mi" }, limits: { cpu: "1000m", memory: "512Mi" } },
    large:  { requests: { cpu: "500m", memory: "512Mi" }, limits: { cpu: "2000m", memory: "2Gi"   } },
  },
  webApp: {
    defaults: {
      replicas: 2,
      probes: "/health",
      resources: "medium",
    },
    transform: (config) => ({
      ...config,
      labels: {
        ...config.labels,
        "acme.io/managed-by": "platform-v1",
        "acme.io/team": Values.team ?? "unknown",
      },
    }),
  },
});
```

Tag and release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

### Step 2 — Application team: consume in project

```typescript
// main.ct
import { webApp, expose, backendDatabase } from "github.com/acme-corp/k8s-platform@v1.0.0/factories";
import { env, vol } from "github.com/cloudticon/k8s-factories@master";

backendDatabase({
  metadata: { name: `${Release.name}-db` },
  spec: {
    engine: "postgres",
    version: "15",
    storage: Values.db?.storage ?? "20Gi",
  },
});

const api = webApp({
  name: Release.name,
  image: `${Values.image.repository}:${Values.image.tag}`,
  port: 8080,
  env: {
    DB_HOST: env.secret(`${Release.name}-db-credentials`, "host"),
    DB_PASSWORD: env.secret(`${Release.name}-db-credentials`, "password"),
  },
  hpa: { min: 2, max: 10, cpu: 80 },
});

expose({
  host: Values.domain,
  routes: [{ prefix: "/", destination: api }],
});
```

```json
// values.json
{
  "image": { "repository": "acme-corp/billing-api", "tag": "v4.2.0" },
  "domain": "billing.acme-corp.com",
  "team": "billing",
  "db": { "storage": "100Gi" }
}
```

### Step 3 — Deploy

```bash
ct types .
ct template . billing-api -n billing
ct apply . billing-api -n billing --create-namespace --context production
```

Produces: ManagedDatabase, Deployment, Service, HPA, VirtualService, Gateway, Certificate — all with platform-standard labels, probes, and resource presets.
