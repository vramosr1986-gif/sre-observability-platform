# SRE Observability Platform

![Kubernetes](https://img.shields.io/badge/Kubernetes-K3d-326CE5?logo=kubernetes)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)
![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus-E6522C?logo=prometheus)
![Grafana](https://img.shields.io/badge/Dashboards-Grafana-F46800?logo=grafana)
![EDA](https://img.shields.io/badge/Automation-EDA-EB5424?logo=ansible)

Plataforma SRE desplegada en Kubernetes con GitOps, monitorización y auto-remediación.

Todo el proyecto está gestionado como código y actualmente se encuentra **en desarrollo**.

---

## Estado del proyecto

🟡 **Proyecto en desarrollo**

La infraestructura principal está desplegada y funcionando. **La cadena completa de event-driven automation está operativa**: Prometheus detecta, Alertmanager enruta al receptor `alertas-para-eda`, EDA recibe la alerta, ejecuta un playbook de Ansible con `run_playbook`, y el playbook hace un POST HTTP a un webhook externo con los datos de la alerta.

Lo único que queda pendiente es la parte de remediación **real** (que el playbook haga algo útil sobre el cluster: escalar un deployment, reiniciar un pod, etc.).

### Objetivos cumplidos

* [x] Crear cluster Kubernetes con K3d
* [x] Crear estructura base del proyecto
* [x] Crear namespaces de Kubernetes
* [x] Instalar ArgoCD
* [x] Configurar GitOps con ArgoCD (App-of-Apps)
* [x] Desplegar aplicación de demostración
* [x] Instalar Nginx Ingress
* [x] Instalar Prometheus
* [x] Instalar Grafana
* [x] Instalar Alertmanager
* [x] Instalar Node Exporter
* [x] Instalar kube-state-metrics
* [x] Configurar monitorización de los nodos
* [x] Configurar monitorización de Kubernetes
* [x] Comprobar targets de Prometheus
* [x] Comprobar métricas mediante PromQL
* [x] Crear reglas de alerta propias con `PrometheusRule` (`HighCPU`, `HighMemory`)
* [x] Configurar el datasource de Prometheus en Grafana
* [x] Verificar despliegues mediante ArgoCD
* [x] Verificar el rebuild completo desde cero
* [x] Configurar webhook de Alertmanager hacia EDA
* [x] Desplegar EDA (`ansible-rulebook` 1.3.2) en el cluster
* [x] Conectar Alertmanager con EDA vía webhook
* [x] Verificar que las alertas llegan a Alertmanager
* [x] Verificar que Alertmanager envía los POST a EDA (`Notify success`)
* [x] Configurar el receptor con nombre descriptivo (`alertas-para-eda`)
* [x] Activar el modo `debug` en Alertmanager para ver las notificaciones
* [x] Configurar el receptor para apuntar a `/alerts` en EDA
* [x] Desplegar el inventario de Ansible en el ConfigMap de EDA
* [x] Crear un playbook de Ansible que ejecuta EDA al recibir la alerta
* [x] Verificar que EDA ejecuta el playbook (`ansible-httpget` en el POST)
* [x] Verificar el flujo completo end-to-end (Prometheus → webhook.site)
* [x] Crear script de demo `demo-eda.sh`

### Objetivos pendientes

* [ ] Remediar de verdad (escalar un deployment, reiniciar un pod...)
* [ ] Cambiar la acción del rulebook a `run_playbook` sobre objetos de Kubernetes
* [ ] Simular una incidencia real (estrés de CPU con `stress-ng`)
* [ ] Hacer visible la reacción de EDA (cambiar imagen a `eda-server` o añadir logs)
* [ ] Añadir observabilidad de logs
* [ ] Valorar integración con Elasticsearch
* [ ] Añadir más métricas de Kubernetes
* [ ] Añadir métricas de la aplicación `demo-app`
* [ ] Añadir tests de infraestructura
* [ ] Mejorar seguridad de credenciales
* [ ] Evaluar despliegue en cloud (AWS, Azure o GCP)

> **Sobre el dashboard de Grafana:** la captura de abajo se creó cuando Grafana venía dentro
> de `kube-prometheus-stack`, que lo aprovisionaba automáticamente. Ahora Grafana se despliega
> como aplicación independiente (chart `grafana` 7.0.19). El **datasource** sí está provisionado
> desde Git y sobrevive a cada rebuild, pero el **dashboard** se importó a mano y **no está
> versionado**: al recrear el cluster hay que volver a importarlo. Ver
> [Dashboards](#dashboards).

---

## Capturas

### ArgoCD — Login

Pantalla de acceso a ArgoCD.

![ArgoCD Login](docs/screenshots/argocd-login.jpeg)

### ArgoCD — Aplicaciones desplegadas

Las cinco Applications gestionadas por GitOps, todas en estado `Synced` y `Healthy`.
`root-app` lee la carpeta `bootstrap/` y crea las cuatro hijas: `prometheus`, `grafana`,
`demo-app` y `eda-app`.

![ArgoCD Applications](docs/screenshots/argocd-applications.jpeg)

### Grafana — Dashboard

Dashboard inicial para visualizar las métricas de la infraestructura Kubernetes.
*Captura del despliegue anterior a la separación de Grafana como app independiente.*

![Grafana Dashboard](docs/screenshots/grafana-dashboard.jpeg)

### Prometheus — CPU Usage

Consulta de métricas de utilización de CPU mediante PromQL.

![Prometheus CPU Usage](docs/screenshots/prometeus-cpu-usage.jpeg)

### Alertmanager — Alertas

Alertas gestionadas por Alertmanager, con los grupos y firing rules del clúster.

![Alertmanager](docs/screenshots/alertmanager.jpeg)

### Kubernetes

Estado de los pods desplegados en el cluster.

![Kubernetes ](docs/screenshots/kubernetes.jpeg)

### Flujo completo de auto-remediación

Ejecución del script `demo-eda.sh`, que inyecta una alerta y muestra el recorrido completo
por toda la cadena: Prometheus → Alertmanager → EDA → Ansible → Webhook.

![Flujo completo](docs/screenshots/flujo-prometheus-EDA-webhook-terminal.png)

### Resultado final — POST recibido en webhook.site

El playbook de Ansible hace un POST HTTP al webhook con los datos de la alerta. El
`user-agent: ansible-httpget` confirma que el POST lo ha enviado EDA (no un navegador ni
un `curl` manual).

![Webhook POST](docs/screenshots/webhook-site.png)

---

## Arquitectura

```text
                          ┌─────────────────────┐
                          │        GitHub       │
                          │  fuente de verdad   │
                          └──────────┬──────────┘
                                     │  pull cada ~3 min
                                     ▼
┌──────────────────┐       ┌─────────────────────┐
│      Usuario     │──────▶│      ArgoCD        │
└──────────────────┘       └──────────┬──────────┘
                                      │  renderiza charts
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
             ┌────────────┐   ┌────────────┐   ┌────────────┐
             │     App    │   │     App    │   │     App    │
             │ prometheus │   │  grafana   │   │  demo-app  │
             └─────┬──────┘   └──────┬─────┘   └────────────┘
                   │                 │
                   │          ┌──────▼─────┐
                   │          │  Ingress   │
                   │          │  (nginx)   │
                   │          └──────┬─────┘
                   │                 │
     ┌─────────────┼───────────┐     │
     │             │           │     │
     ▼             ▼           ▼     ▼
┌─────────┐  ┌────────────┐  ┌────────────┐  ┌────────┐
│  Alert  │  │ Prometheus │  │ kube-state │  │demo-app│
│ manager │  │            │  │  -metrics  │  │        │
└────┬────┘  └─────┬──────┘  └────────────┘  └────────┘
     │            │
     │  scrape    │
     │            ▼
     │      ┌───────────┐
     │      │  3 × Node │  (1 server + 2 agents)
     │      │  Exporter │
     │      └───────────┘
     │
     │  webhook POST a /alerts
     ▼
┌────────────┐
│     EDA    │   ← activo (ns eda)
│  ansible-  │
│  rulebook  │
└─────┬──────┘
      │  run_playbook
      ▼
┌────────────┐
│  Ansible   │   ← activo
│  notify.yml│
└─────┬──────┘
      │  POST
      ▼
┌────────────┐
│  Webhook   │   ← activo (webhook.site)
│  externo   │
└────────────┘
```

### Cómo encaja el App-of-Apps

`root-app` no instala Prometheus: instala las **Applications** que instalan Prometheus. Hay
dos capas, cada una con su propio ciclo de sincronización:

```text
bootstrap/root-app.yaml
   └─ Application/root-app          (lee la carpeta bootstrap/ de Git)
        ├─ Application/prometheus   (chart kube-prometheus-stack 55.0.0 → ns observability)
        ├─ Application/grafana      (chart grafana 7.0.19            → ns observability)
        ├─ Application/demo-app     (chart local                     → ns applications)
        ├─ Application/eda-app      (chart local                     → ns eda)
        └─ los 4 Namespaces
```

Un único sentido de cambio: **Git → cluster**. Si editas algo con `kubectl edit`, Argo lo
sobrescribe con la versión de Git en cuanto lo detecta (`selfHeal: true`).

---

## Stack

| Capa                  | Tecnología                    | Estado       | Para qué                        |
| --------------------- | ----------------------------- | ------------ | ------------------------------- |
| **Contenedores**      | Docker                        | ✅ activo    | Motor de contenedores           |
| **Orquestación**      | Kubernetes (K3d)              | ✅ activo    | Cluster local                   |
| **GitOps**            | ArgoCD 3.5.3                  | ✅ activo    | Despliegue desde Git            |
| **Ingress**           | Nginx Ingress                 | ✅ activo    | Exponer servicios               |
| **Métricas**          | Prometheus + Node Exporter    | ✅ activo    | Recoger métricas                |
| **Estado Kubernetes** | kube-state-metrics            | ✅ activo    | Métricas de objetos Kubernetes  |
| **Dashboards**        | Grafana 10.2.2                | ✅ activo    | Visualización                   |
| **Alertas**           | Alertmanager                  | ✅ activo    | Gestionar y enviar alertas      |
| **Auto-remediación**  | EDA (ansible-rulebook) 1.3.2  | ✅ activo    | Escucha alertas de Alertmanager |
| **Remediación**       | Ansible                       | ✅ activo    | Ejecutar playbooks              |

---

## Estructura del proyecto

```text
sre-observability-platform/
│
├── bootstrap/
│   ├── bootstrap.sh          # crea el cluster, instala ArgoCD/CRDs/ingress y abre la UI
│   ├── stop-portforwards.sh  # detiene los port-forward lanzados por el bootstrap
│   ├── namespaces.yaml       # argocd, observability, applications, eda
│   ├── argocd-apps.yaml      # las 4 Applications hijas + values de cada chart
│   └── root-app.yaml         # Application raíz (App-of-Apps)
│
├── gitops/
│   └── helm/
│       ├── demo-app/         # chart local de la app de demostración
│       └── eda/              # chart local de EDA (ansible-rulebook)
│           ├── Chart.yaml
│           ├── values.yaml
│           ├── files/
│           │   ├── notify.yml       # playbook de Ansible (POST a webhook.site)
│           │   └── inventory.yml    # inventario de Ansible (localhost)
│           └── templates/
│               ├── configmap.yaml   # rulebook + notify.yml + inventory.yml
│               ├── deployment.yaml  # ansible-rulebook con --rulebook y --inventory
│               └── service.yaml     # expone el webhook en :5000
│
├── docs/
│   └── screenshots/
│       ├── alertmanager.jpeg
│       ├── argocd-applications.jpeg
│       ├── argocd-login.jpeg
│       ├── flujo-prometheus-EDA-webhook-terminal.png
│       ├── grafana-dashboard.jpeg
│       ├── kubernetes.jpeg
│       ├── prometeus-cpu-usage.jpeg
│       └── webhook-site.png
│
├── demo-eda.sh                # script de demo del flujo completo
├── k3d-config.yaml            # 1 server + 2 agents, traefik deshabilitado
└── README.md
```

> **Las CRDs del Prometheus Operator no están en el repo a propósito.** `bootstrap.sh` las
> descarga del chart publicado en el paso 8 y las aplica con `kubectl apply --server-side`, y
> ArgoCD gestiona el chart con `helm.skipCrds: true` para no adoptarlas. Si las metieras en
> Git, Argo pelearía con el operator por su property.

---

## Cómo desplegar

```bash
git clone https://github.com/vramosr1986-gif/sre-observability-platform.git

cd sre-observability-platform

./bootstrap/bootstrap.sh
```

> **Requiere WSL o Linux.** El cluster k3d corre dentro de Docker en WSL, así que `k3d`,
> `helm` y `kubectl` deben estar disponibles **dentro de WSL**, no en PowerShell.

El script es idempotente: si el cluster ya existe, lo borra y lo recrea desde cero. Levanta:

1. Cluster K3d (1 server + 2 agents)
2. Namespaces
3. ArgoCD
4. **CRDs del Prometheus Operator** (descargadas del chart 55.0.0, aplicadas con server-side apply)
5. Nginx Ingress
6. `root-app`, que a su vez sincroniza Prometheus, Grafana, demo-app y EDA
7. Espera a que las 5 Applications queden `Synced` y `Healthy` (hasta 180 s)
8. Levanta los `port-forward` en segundo plano y abre ArgoCD en el navegador

La parte lenta es el paso 6: los charts tardan en renderizarse y Prometheus en ponerse *ready*.
ArgoCD sincroniza cada ~3 minutos, así que **`root-app` puede marcar `Synced` antes de que
`prometheus` termine**. Es normal ver `OutOfSync` durante el primer minuto.

> **El script no se queda esperando a que la terminal quede libre.** Los `port-forward` del
> paso 8 se lanzan con `nohup`, así que puedes seguir usando la terminal mientras corren.

Si al terminar ves un aviso de que alguna Application no convergió en 180 s, no es un fallo del
script: significa que el primer despliegue tardó más. Espera un poco y vuelve a consultar:

Para ver el estado cuando quieras:

```bash
kubectl get applications -n argocd
```

Lo que debes ver cuando todo ha asentado:

```text
NAME         SYNC STATUS   HEALTH STATUS
demo-app     Synced        Healthy
eda-app      Synced        Healthy
grafana      Synced        Healthy
prometheus   Synced        Healthy
root-app     Synced        Healthy
```

> **Si tocas `bootstrap/argocd-apps.yaml` y no ves cambio en el cluster**, es que `root-app`
> aún no ha recogido el commit. Fuerza el refresco:
>
> ```bash
> kubectl annotate application root-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
> ```
>
> Tarda unos 20 s en propagarse a las Applications hijas.
>
> **Ojo:** refrescar la app hija (`prometheus`, `grafana`, etc.) **no sirve** cuando el cambio
> está en `argocd-apps.yaml`. Las apps hijas leen su propio chart o su propio path en el repo,
> no ese fichero. Los values de Prometheus, por ejemplo, viven en `argocd-apps.yaml`, y solo
> `root-app` los lee. Se delata porque el `Revision` de la app hija muestra la **versión del
> chart** (`55.0.0`), no un hash de commit.

---

## Cómo acceder

### Vía port-forward (recomendado)

`bootstrap.sh` los lanza **en segundo plano** al final y abre ArgoCD en el navegador, así que
la terminal queda libre para seguir usándose. Para ver qué puerto acabó sirviendo cada
aplicación:

```bash
cat /tmp/sre-lab-portforwards.map
```

| Servicio         | Puerto por defecto | URL                             |
| ---------------- | ------------------ | ------------------------------- |
| **ArgoCD**       | 9090               | https://localhost:9090          |
| **Grafana**      | 3000               | http://localhost:3000           |
| **Prometheus**   | 9091               | http://localhost:9091           |
| **Alertmanager** | 9093               | http://localhost:9093           |
| **demo-app**     | 8082               | http://localhost:8082           |
| **EDA**          | 5000               | http://localhost:5000/alerts (solo POST) |

> Si un puerto ya está ocupado (por ejemplo, porque tienes otro `port-forward` vivo), el
> script busca el siguiente libre y avisa por pantalla. Consulta siempre el fichero
> `.map` para saber el puerto real.

Para pararlos todos:

```bash
bash bootstrap/stop-portforwards.sh
```

> Si matas los `port-forward` a mano con `pkill -f 'kubectl port-forward'`, el fichero
> `.pid` se queda obsoleto. La próxima vez que corras `bootstrap.sh` los mata sin error
> porque `stop` ignora los PIDs que ya no existen.

> **Alertmanager tiene dos Services.** El que funciona para port-forward es
> `alertmanager-operated` (headless). El otro, `prometheus-kube-prometheus-alertmanager`, tiene
> ClusterIP y también sirve, pero no puedes usar los dos a la vez en el mismo puerto local.

ArgoCD usa certificado autofirmado, así que el navegador mostrará un aviso de
seguridad. Es esperado: pulsa **Advanced → Proceed**.

### Vía Ingress

| Servicio     | Host                | Notas                                 |
| ------------ | ------------------- | ------------------------------------- |
| **demo-app** | `demo-app.local`    | sin autenticación                     |
| ~~Grafana~~  | ~~`grafana.local`~~ | **no funciona**, ver la nota de abajo |

> ⚠️ **Grafana no es accesible por ingress.** Su `root_url` está fijado a
> `http://localhost:3000` porque el chart por defecto usa `domain = grafana.local`, y con ese
> valor el navegador recibe `Failed to fetch` al pedir cualquier API. Fijarlo a `localhost`
> arregla el port-forward, pero rompe el ingress. Usa siempre `http://localhost:3000`.
>
> Si algún día quieres que ambos funcionen, la vía es un `root_url` con los placeholders de
> Grafana (`%(protocol)s://%(domain)s:%(http_port)s/`) **y** quitar el `domain` fijo.

El ingress de nginx escucha en la IP del loadbalancer. Para resolver los nombres en local,
añade a tu `hosts` de Windows:

```text
172.19.0.2   demo-app.local
```

La IP puede cambiar en cada recreación del cluster; consíguela con:

```bash
kubectl get ingress -n applications demo-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

## Grafana

Grafana se despliega como aplicación independiente (chart `grafana` 7.0.19), no como subchart
de `kube-prometheus-stack`. Eso obliga a cablear a mano dos cosas que el stack integrado
hacía solo.

### Datasource

Provisionado desde Git en los values de la Application de Grafana, así que **sobrevive a cada
rebuild**:

```yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090
        isDefault: true
```

Comprobar que responde:

```bash
curl -s -u admin:admin http://localhost:3000/api/datasources/uid/prometheus/health
```

Deberías ver `"status":"OK"` y `"Successfully queried the Prometheus API."`.

### Dashboards

**No hay ningún dashboard versionado en el repo.** El que se ha usado (`Node Exporter Full`,
de `kube-prometheus-stack`) se importó a mano en la UI.

Grafana corre con almacenamiento **efímero** (sin PVC), así que al recrear el cluster **se
pierde**. Hay que volver a importarlo.

Para sacarlo de la instancia actual:

```bash
curl -s -u admin:admin http://localhost:3000/api/dashboards/uid/rYdddlPWk \
  | python3 -c 'import sys,json;print(json.dumps(json.load(sys.stdin)["dashboard"]))' \
  > node-exporter-full.json
```

Verifícalo antes de conectarte:

```bash
curl -s -u admin:admin http://localhost:3000/api/frontend/settings \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["appUrl"])'
```

Debe devolver `http://localhost:3000/`. Si devuelve `grafana.local`, el `root_url` no se aplicó
todavía.

### Credenciales de ArgoCD

Usuario `admin`. La contraseña se genera en el arranque del cluster:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

> Esta contraseña **solo existe hasta el primer arranque** de ArgoCD. Como `bootstrap.sh`
> recrea el cluster cada vez, cambia en cada despliegue.

---

## Monitorización

Prometheus está configurado para recopilar métricas de diferentes componentes del cluster.

Actualmente se encuentran disponibles métricas de:

* Kubernetes API Server
* Kubelet
* cAdvisor
* CoreDNS
* kube-state-metrics
* Node Exporter
* Prometheus
* Alertmanager
* Prometheus Operator

Comprobar el estado de los targets desde la UI de Prometheus, o por CLI:

```bash
PROM=$(kubectl get pod -n observability -l app.kubernetes.io/name=prometheus \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n observability "$PROM" -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=count(up%20%3D%3D%201)'
```

Los targets con valor `1` en la consulta `up` están siendo monitorizados correctamente.

---

## Alertas

### Reglas propias

Ya existen **dos reglas de alerta propias**, definidas en `bootstrap/argocd-apps.yaml` dentro
de `additionalPrometheusRulesMap` y desplegadas como objetos `PrometheusRule`:

| Alerta       | Namespace | Qué detecta                                 |
| ------------ | --------- | ------------------------------------------- |
| `HighCPU`    | `cpu`     | CPU > 80% sostenida 5 min por instancia     |
| `HighMemory` | `memory`  | Memoria usada > 80% del total durante 5 min |

```yaml
additionalPrometheusRulesMap:
  high-cpu-alert:
    groups:
      - name: cpu
        rules:
          - alert: HighCPU
            expr: |
              100 - (
                avg by(instance) (
                  rate(node_cpu_seconds_total{mode="idle"}[5m])
                ) * 100
              ) > 80
            for: 5m
            labels:
              severity: warning
```

Verificar que están cargadas y evaluándose:

```bash
PROM=$(kubectl get pod -n observability -l app.kubernetes.io/name=prometheus \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n observability "$PROM" -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/rules'
```

`state=inactive` con `health=ok` significa que la regla existe y se evalúa, pero su
condición no se cumple. Eso es lo esperado en un cluster sano.

> **Ruido esperado en K3d:** las reglas `KubeControllerManagerDown`, `KubeProxyDown` y
> `KubeSchedulerDown` del propio chart salen perpetuamente en `firing`. K3d es un cluster de
> un solo nodo y no expone esos componentes del control plane, así que **no es un fallo**.
> Las alertas propias (`HighCPU`, `HighMemory`) están correctamente inactivas.

### Receptor de Alertmanager

Alertmanager está configurado para enviar **todas** las alertas a EDA, y **concretamente al
endpoint `/alerts`** (no a la raíz):

```yaml
alertmanager:
  config:
    route:
      receiver: alertas-para-eda
      group_by:
        - alertname
      group_wait: 10s
      group_interval: 30s
      repeat_interval: 1h
      routes:
        - receiver: alertas-para-eda
          matchers:
            - alertname =~ ".*"
    receivers:
      - name: alertas-para-eda
        webhook_configs:
          - url: http://eda.eda.svc.cluster.local:5000/alerts
            send_resolved: true
  alertmanagerSpec:
    logLevel: debug
```

* `receiver: alertas-para-eda` → nombre libre del receptor (antes era `eda-webhook`).
* `webhook_configs` → el receptor hace un POST HTTP al endpoint de EDA.
* **`url: .../alerts`** → EDA solo acepta POSTs en `/alerts`. Si apuntas a `/`, responde
  `405 Method Not Allowed`.
* `send_resolved: true` → también se notifica cuando la alerta se resuelve.
* `logLevel: debug` → para ver cada notificación en los logs.

Verificar que EDA recibe las alertas, mirando los logs de Alertmanager:

```bash
kubectl logs -n observability alertmanager-prometheus-kube-prometheus-alertmanager-0 -c alertmanager --tail=30 \
  | grep -i "notify\|webhook\|error"
```

Cuando todo funciona, se ven líneas como:

```text
level=debug component=dispatcher receiver=alertas-para-eda integration=webhook[0] msg="Notify success" attempts=1
```

Ese `Notify success` significa que el POST ha llegado a EDA con éxito.

### Flujo de alertas

```text
Prometheus  ──alerta──▶  Alertmanager  ──webhook /alerts──▶  EDA  ──▶  Ansible
                              (✅ activo)       (✅ activo)         (✅ activo)
```

---

## Auto-remediación (EDA)

EDA está desplegado como una Application más de ArgoCD (`eda-app`), con su propio chart en
`gitops/helm/eda/`. La imagen usada es `quay.io/ansible/ansible-rulebook:v1.3.2`, la CLI de
`ansible-rulebook`.

### Arquitectura de ficheros

El chart de EDA tiene **tres ficheros clave** que se montan como ConfigMap y que
`ansible-rulebook` lee al arrancar:

| Fichero | Fuente en el repo | Qué contiene |
| ------- | ----------------- | ------------ |
| `rulebook.yml` | Inline en `configmap.yaml` | Qué escucha EDA y cómo reacciona |
| `notify.yml` | `files/notify.yml` | El playbook de Ansible que se ejecuta |
| `inventory.yml` | `files/inventory.yml` | Los hosts sobre los que ejecutar Ansible |

Los tres llegan al pod como ficheros en `/rulebook/`:

```
/rulebook/
├── rulebook.yml
├── notify.yml
└── inventory.yml
```

### El rulebook

Vive en el `ConfigMap` `eda-rulebook`, y define qué escucha EDA y cómo reacciona:

```yaml
---
- name: Reaccionar a alertas
  hosts: all
  sources:
    - ansible.eda.alertmanager:
        host: 0.0.0.0
        port: 5000
  rules:
    - name: Alerta de prueba
      condition: event.alert.labels.alertname is defined
      action:
        run_playbook:
          name: /rulebook/notify.yml
```

* `source: ansible.eda.alertmanager` → EDA entiende el formato de Alertmanager y desempaqueta
  cada alerta del array `alerts`, generando un evento por alerta.
* `condition` → filtra qué alerta dispara la regla. Ahora mismo matchea **cualquier** alerta
  con `alertname` definido.
* `action: run_playbook` → ejecuta el playbook de Ansible `/rulebook/notify.yml`.

### El playbook (`notify.yml`)

```yaml
---
- name: Notificar alerta
  hosts: localhost
  gather_facts: true
  tasks:
    - name: Hacer POST a webhook.site
      ansible.builtin.uri:
        url: https://webhook.site/4325c6a4-6efa-4af8-84fc-592905101139
        method: POST
        body_format: json
        body:
          alerta: "🚨 Alerta recibida por EDA"
          severidad: "critical"
          origen: "Prometheus"
          accion: "Notificación enviada"
          timestamp: "{{ ansible_date_time.iso8601 | default('N/A') }}"
          mensaje: "Alerta recibida por EDA"
        status_code: 200
```

Hace un POST a `webhook.site` con un JSON profesional que incluye el timestamp real.

### El inventario (`inventory.yml`)

```yaml
all:
  hosts:
    localhost:
      ansible_connection: local
```

**Obligatorio** para `run_playbook`: Ansible siempre necesita saber sobre qué hosts ejecutar.
Sin él, EDA falla al arrancar con:

```
ERROR - Terminating: Rule Alerta de prueba has an action run_playbook which needs inventory to be defined
```

### Estado actual de la cadena

```text
Métrica anormal
      │
      ▼
Prometheus evalúa la regla                 ✅
      │
      ▼
PrometheusRule  (HighCPU / HighMemory)     ✅
      │
      ▼
Alertmanager   enruta a `alertas-para-eda` ✅
      │  POST a /alerts
      ▼
EDA            recibe el POST              ✅
      │  run_playbook
      ▼
Ansible        ejecuta notify.yml          ✅
      │  POST HTTP
      ▼
Webhook externo (webhook.site)             ✅
```

**La cadena completa funciona de punta a punta.**

### Limitación conocida: logs de EDA

La imagen `quay.io/ansible/ansible-rulebook:v1.3.2` **no escribe a stdout**, así que aunque
EDA reciba las alertas y ejecute el playbook, no se ve nada en `kubectl logs`. Alertmanager sí
confirma que el POST llega (`Notify success`), y el webhook externo confirma que el playbook
se ejecutó (`user-agent: ansible-httpget`).

Opciones para tener visibilidad directa:

1. **Cambiar la imagen a `quay.io/ansible/eda-server:latest`**, que sí imprime logs.
2. **Cambiar la acción del rulebook** por algo aún más visible (escribir un fichero, mandar
   un Slack, etc.).

### Script de demo

El repo incluye `demo-eda.sh`, un script que inyecta una alerta y muestra el recorrido completo
por toda la cadena con salida formateada:

```bash
./demo-eda.sh
```

---

## Qué aprendí

* **Kubernetes**: pods, services, namespaces, ingress, CRDs y StatefulSets
* **K3d**: Kubernetes dentro de Docker
* **GitOps con ArgoCD**: sincronización desde Git, `selfHeal` y `prune`
* **App-of-Apps**: una Application raíz que gestiona otras Applications
* **Helm**: charts, values, templates y `.Files.Get` para ficheros externos
* **Prometheus**: métricas, PromQL, ServiceMonitors y PrometheusRules
* **Grafana**: dashboards y data sources
* **Alertmanager**: alertas, webhooks, receptores y modo debug
* **EDA**: `ansible-rulebook`, sources, condiciones, acciones y inventario
* **Ansible**: playbooks, inventario y módulo `ansible.builtin.uri`
* **SRE**: observabilidad, alerting y automatización de operaciones

### Trampas que costaron tiempo

**`syncOptions` cambió de sitio en ArgoCD v3.** En v2.x era `spec.syncOptions`; desde v3 la
ruta válida es `spec.syncPolicy.syncOptions`. Con el layout antiguo, el API server hace
*structural schema pruning* y **descarta el campo en silencio**, así que Git siempre declara
algo que el cluster no tiene. El síntoma es un `root-app` que se queda `OutOfSync` para
siempre con un bucle de autosync que nunca converge, mientras Argo reporta
`successfully synced`. La pista está en el log del controller:

```bash
kubectl logs -n argocd argocd-application-controller-0 --since=5m | grep 'unknown field'
```

**Un cambio en `bootstrap/argocd-apps.yaml` se aplica refrescando `root-app`, no la app hija.**
Las apps hijas no leen ese fichero: leen su propio chart o su propio path en el repo. Los
values de Prometheus (por ejemplo, el receptor de Alertmanager) viven en `argocd-apps.yaml`,
y solo `root-app` los lee. Se detecta mirando el `Revision` de la app hija: en vez de un hash
de commit, muestra la **versión del chart** (`55.0.0`).

```bash
kubectl get application prometheus -n argocd -o jsonpath='{.status.sync.revision}'
# → 55.0.0   (no es un commit, es la versión del chart)

kubectl get application root-app -n argocd -o jsonpath='{.status.sync.revision}'
# → 1974588  (esto sí es un commit de Git)
```

**`helm template` antes de commitear.** Un error de indentación en un `ConfigMap` o en un
`values:` no se detecta hasta que Argo intenta renderizar el chart, y el mensaje de error
(Helm ejecutado dentro de Argo) es mucho menos claro. `helm template <chart> <ruta>` valida el
chart en local en un segundo:

```bash
helm template eda gitops/helm/eda
```

**Los logs de `ansible-rulebook` pueden estar mudos.** La imagen
`quay.io/ansible/ansible-rulebook:v1.3.2` no vuelca a stdout, así que aunque EDA reciba las
alertas y ejecute el playbook, no hay forma de verlo desde `kubectl logs`. Se comprueba
indirectamente mirando los logs de Alertmanager (`msg="Notify success"`) y el webhook externo
(`user-agent: ansible-httpget`).

**Un `run_playbook` necesita inventario, siempre.** Aunque solo haya un host (`localhost`),
Ansible se niega a ejecutar sin un inventario declarado. El error es explícito al arrancar:

```
ERROR - Terminating: Rule Alerta de prueba has an action run_playbook which needs inventory to be defined
```

La solución es doble: (1) añadir un `inventory.yml` al ConfigMap, y (2) pasarle a
`ansible-rulebook` el flag `--inventory /rulebook/inventory.yml`.

**EDA solo acepta POSTs en `/alerts`.** El source `ansible.eda.alertmanager` responde
`405 Method Not Allowed` si le mandas un POST a la raíz (`/`). La URL del receptor de
Alertmanager tiene que apuntar a `/alerts`:

```yaml
- url: http://eda.eda.svc.cluster.local:5000/alerts
```

Se detecta mirando la cabecera `Allow` de la respuesta:

```bash
kubectl run curl-test -n eda --rm -it --restart=Never --image=curlimages/curl -- \
  curl -v -X POST http://eda:5000
# < HTTP/1.1 405 Method Not Allowed
# < Allow: GET,HEAD
```

**Un bucle de reconciliación puede *parecer* sano.** El mensaje de éxito del sync se refiere
a que la operación se ejecutó, no a que el cluster haya cambiado. La señal fiable es que
`status.sync.status` llegue a `Synced` y **se quede** ahí.

**El `root_url` de Grafana decide si la UI funciona o no.** El chart `grafana` viene con
`domain = grafana.local` por defecto, y eso hace que Grafana se builda la URL base
`http://grafana.local:3000/`. Si abres la UI por `localhost:3000`, el navegador pide contra
`grafana.local`, que no resuelve, y cada llamada a la API muere con `Failed to fetch`. El
síntoma engaña porque **el datasource puede estar perfectamente configurado y el health check
devolver `OK`**: el fallo es del navegador, no del backend. Se diagnostica mirando qué cree
Grafana que es su URL base:

```bash
curl -s -u admin:admin http://localhost:3000/api/frontend/settings | grep -o '"appUrl":"[^"]*"'
```

**Una anotación en ArgoCD es un "one-shot".** El comando `kubectl annotate application ...`
mete una anotación que Argo lee una vez y borra. Sirve para forzar un refresh inmediato
sin esperar al ciclo de polling (~3 min). Para cambios permanentes, van en Git.

**Los `port-forward` de `bootstrap.sh` sobreviven, pero los manuales no.** Los del script
se lanzan con `nohup`, así que sobreviven al cierre de la terminal. Los que lanzas a mano
con `kubectl port-forward` mueren al cerrar la terminal (a menos que los envuelvas en
`nohup ... &`). Se comprueba con:

```bash
ps aux | grep "port-forward" | grep -v grep
```

---

## Próximos pasos

```text
[x] Kubernetes / K3d
[x] GitOps / ArgoCD
[x] Helm
[x] Prometheus
[x] Grafana
[x] Alertmanager
[x] Node Exporter
[x] kube-state-metrics
[x] PrometheusRules propias (HighCPU, HighMemory)
[x] Datasource de Prometheus en Grafana
[x] Webhooks (Alertmanager → EDA)
[x] Despliegue de EDA
[x] Playbook de Ansible (notify.yml)
[x] Inventario de Ansible (inventory.yml)
[x] Flujo completo end-to-end (Prometheus → Webhook)
[x] Script de demo (demo-eda.sh)
[ ] Hacer visible la reacción de EDA (cambiar imagen a eda-server)
[ ] Remediación real (escalar deployment, reiniciar pod)
[ ] Simular incidencia real (stress-ng)
[ ] Pruebas de incidentes
[ ] Logs centralizados
[ ] Mejoras de observabilidad
[ ] Cloud
```

---

## Proyecto en desarrollo

Este repositorio representa un **laboratorio SRE en evolución**.

La infraestructura base, la monitorización, las alertas propias, el datasource de Grafana y
**la cadena completa de event-driven automation** (Prometheus → Alertmanager → EDA →
Ansible → Webhook) ya están operativas, mientras que la remediación real sobre objetos de
Kubernetes sigue en implementación.

El objetivo final es disponer de una plataforma capaz de:

```text
Detectar
   ↓
Alertar
   ↓
Analizar
   ↓
Activar
   ↓
Remediar
   ↓
Verificar
```

manteniendo toda la infraestructura y configuración gestionadas como código.

---

## Autor

**Victor Ramos** — [@vramosr1986-gif](https://github.com/vramosr1986-gif)

Proyecto de aprendizaje y experimentación con **SRE, Kubernetes, GitOps, observabilidad y automatización**.
