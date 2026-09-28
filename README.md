# SRE Observability Platform

![Kubernetes](https://img.shields.io/badge/Kubernetes-K3d-326CE5?logo=kubernetes)

![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)

![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus-E6522C?logo=prometheus)

![Grafana](https://img.shields.io/badge/Dashboards-Grafana-F46800?logo=grafana)

Plataforma SRE desplegada en Kubernetes con GitOps, monitorización y auto-remediación.

Todo el proyecto está gestionado como código y actualmente se encuentra **en desarrollo**.

---

## Estado del proyecto

🟡 **Proyecto en desarrollo**

La infraestructura principal ya está desplegada y funcionando. Actualmente el proyecto se encuentra en la fase de configuración de alertas, automatización y auto-remediación.

### Objetivos cumplidos

* [x] Crear cluster Kubernetes con K3d
* [x] Crear estructura base del proyecto
* [x] Crear namespaces de Kubernetes
* [x] Instalar ArgoCD
* [x] Configurar GitOps con ArgoCD
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
* [x] Configurar datasource de Prometheus en Grafana
* [x] Crear dashboard inicial de Grafana
* [x] Verificar despliegues mediante ArgoCD

### Objetivos pendientes

* [ ] Crear reglas de alerta personalizadas con `PrometheusRule`
* [ ] Crear alertas en Grafana
* [ ] Configurar correctamente los grupos de reglas
* [ ] Conectar Alertmanager con EDA
* [ ] Configurar webhooks de Alertmanager
* [ ] Crear `ansible-rulebook`
* [ ] Crear playbooks de remediación con Ansible
* [ ] Probar el flujo completo de auto-remediación
* [ ] Simular una incidencia real en Kubernetes
* [ ] Verificar que la alerta llega a Alertmanager
* [ ] Verificar que EDA recibe el evento
* [ ] Ejecutar automáticamente el playbook de Ansible
* [ ] Documentar el flujo completo de recuperación
* [ ] Añadir observabilidad de logs
* [ ] Valorar integración con Elasticsearch
* [ ] Mejorar dashboards de Grafana
* [ ] Añadir más métricas de Kubernetes
* [ ] Añadir métricas de la aplicación `demo-app`
* [ ] Añadir tests de infraestructura
* [ ] Mejorar seguridad de credenciales
* [ ] Evaluar despliegue en cloud (AWS, Azure o GCP)

---

## Capturas

### ArgoCD — Login

Pantalla de acceso a ArgoCD.

![ArgoCD Login](docs/screenshots/argocd-login.jpeg)

### ArgoCD — Aplicaciones desplegadas

Aplicaciones gestionadas mediante GitOps y sincronizadas desde Git.

![ArgoCD Applications](docs/screenshots/argocd-applications.jpeg)

### Grafana — Dashboard

Dashboard inicial para visualizar las métricas de la infraestructura Kubernetes.

![Grafana Dashboard](docs/screenshots/grafana-dashboard.jpeg)

### Prometheus — CPU Usage

Consulta de métricas de utilización de CPU mediante PromQL.

![Prometheus CPU Usage](docs/screenshots/prometeus-cpu-usage.jpeg)

### Kubernetes

Estado de los pods desplegados en el cluster.

![Kubernetes ](docs/screenshots/kubernetes.jpeg)

---

## Arquitectura

```text
                    ┌──────────────────┐
                    │      Usuario     │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
       ┌──────────┐    ┌──────────┐    ┌──────────┐
       │  ArgoCD  │    │ Grafana  │    │ demo-app │
       └──────────┘    └────┬─────┘    └──────────┘
                            │
                            ▼
                     ┌───────────┐
                     │ Prometheus│
                     └─────┬─────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  Node    │ │  Node    │ │  Node    │
        │ Exporter │ │ Exporter │ │ Exporter │
        └──────────┘ └──────────┘ └──────────┘
                           │
                           │ alertas
                           ▼
                    ┌───────────────┐
                    │  Alertmanager │
                    └───────┬───────┘
                            │ webhook
                            ▼
                    ┌───────────────┐
                    │      EDA      │
                    └───────┬───────┘
                            │ ejecuta
                            ▼
                    ┌───────────────┐
                    │    Ansible    │
                    └───────────────┘
```

---

## Stack

| Capa                  | Tecnología                 | Para qué                       |
| --------------------- | -------------------------- | ------------------------------ |
| **Contenedores**      | Docker                     | Motor de contenedores          |
| **Orquestación**      | Kubernetes (K3d)           | Cluster local                  |
| **GitOps**            | ArgoCD                     | Despliegue desde Git           |
| **Ingress**           | Nginx Ingress              | Exponer servicios              |
| **Métricas**          | Prometheus + Node Exporter | Recoger métricas               |
| **Estado Kubernetes** | kube-state-metrics         | Métricas de objetos Kubernetes |
| **Dashboards**        | Grafana                    | Visualización                  |
| **Alertas**           | Alertmanager               | Gestionar y enviar alertas     |
| **Auto-remediación**  | EDA (ansible-rulebook)     | Decidir qué playbook ejecutar  |
| **Remediación**       | Ansible                    | Ejecutar playbooks             |

---

## Estructura del proyecto

```text
sre-observability-platform/

├── bootstrap/
│   ├── bootstrap.sh
│   ├── namespaces.yaml
│   └── argocd-apps.yaml
│
├── gitops/
│   └── helm/
│       └── demo-app/
│
├── docs/
│   ├── ARQUITECTURA.md
│   └── screenshots/
│       ├── argocd-applications.jpeg
│       ├── argocd-login.jpeg
│       ├── grafana-dashboard.jpeg
│       ├── kubernetes.jpeg
│       └── prometeus-cpu-usage.jpeg
│
├── k3d-config.yaml
├── README.md
└── .gitignore
```

---

## Cómo desplegar

```bash
git clone https://github.com/vramosr1986-gif/sre-observability-platform.git

cd sre-observability-platform

./bootstrap/bootstrap.sh
```

El despliegue tarda aproximadamente 3-4 minutos en levantar:

* Cluster K3d
* ArgoCD
* Nginx Ingress
* Prometheus
* Grafana
* Alertmanager
* kube-state-metrics
* Node Exporter
* demo-app

---

## Cómo acceder

| Servicio       | Comando                                                                                     | URL                    |
| -------------- | ------------------------------------------------------------------------------------------- | ---------------------- |
| **ArgoCD**     | `kubectl port-forward svc/argocd-server -n argocd 9090:443`                                 | https://localhost:9090 |
| **Grafana**    | `kubectl port-forward svc/prometheus-grafana -n observability 3000:80`                      | http://localhost:3000  |
| **Prometheus** | `kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090` | http://localhost:9090  |
| **demo-app**   | `kubectl port-forward svc/demo-app -n applications 8080:80`                                 | http://localhost:8080  |

### Credenciales

**ArgoCD**

Usuario:

```text
admin
```

Contraseña:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

**Grafana**

```text
Usuario: admin
Contraseña: admin
```

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

Los targets pueden comprobarse mediante:

```promql
up
```

Los targets con valor:

```text
1
```

están siendo monitorizados correctamente.

---

## Alertas

La infraestructura de Prometheus y Alertmanager ya está desplegada.

La creación de reglas de alerta personalizadas se encuentra actualmente pendiente.

El objetivo es implementar reglas como:

```text
TargetDown
PodCrashLooping
PodNotReady
HighCPUUsage
HighMemoryUsage
NodeNotReady
DeploymentReplicasMismatch
```

El flujo previsto es:

```text
Prometheus
    │
    │ alerta
    ▼
Alertmanager
    │
    │ webhook
    ▼
EDA
    │
    │ evento
    ▼
Ansible
    │
    │ playbook
    ▼
Remediación
```

---

## Auto-remediación

La auto-remediación es una de las partes principales del proyecto, pero todavía está en desarrollo.

El objetivo es que una incidencia detectada por Prometheus pueda desencadenar automáticamente una acción correctiva.

Ejemplo:

```text
Pod problemático
      │
      ▼
Prometheus detecta la métrica
      │
      ▼
PrometheusRule
      │
      ▼
Alertmanager
      │
      ▼
EDA
      │
      ▼
Ansible
      │
      ▼
Playbook de remediación
      │
      ▼
Incidencia corregida
```

---

## Qué aprendí

* **Kubernetes**: pods, services, namespaces, ingress, CRDs y StatefulSets
* **K3d**: Kubernetes dentro de Docker
* **GitOps con ArgoCD**: sincronización desde Git, `selfHeal` y `prune`
* **Helm**: charts, values y templates
* **Prometheus**: métricas, PromQL, ServiceMonitors y PrometheusRules
* **Grafana**: dashboards y data sources
* **Alertmanager**: alertas y webhooks
* **Ansible**: playbooks de remediación
* **EDA**: `ansible-rulebook` y event-driven automation
* **SRE**: observabilidad, alerting y automatización de operaciones

---

## Próximos pasos

El roadmap actual del proyecto es:

```text
[x] Kubernetes / K3d
[x] GitOps / ArgoCD
[x] Helm
[x] Prometheus
[x] Grafana
[x] Alertmanager
[x] Node Exporter
[x] kube-state-metrics
[x] Dashboards
[ ] PrometheusRules personalizadas
[ ] Alertas
[ ] Webhooks
[ ] EDA
[ ] Ansible
[ ] Auto-remediación
[ ] Pruebas de incidentes
[ ] Logs
[ ] Mejoras de observabilidad
[ ] Cloud
```

---

## Proyecto en desarrollo

Este repositorio representa un **laboratorio SRE en evolución**.

La infraestructura base y la monitorización ya están operativas, mientras que las funcionalidades avanzadas de alerting, event-driven automation y auto-remediación todavía están siendo implementadas.

El objetivo final es disponer de una plataforma capaz de:

```text
Detectar
   ↓
Alertar
   ↓
Analizar
   ↓
Actuar
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
