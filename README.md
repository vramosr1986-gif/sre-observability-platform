# SRE Observability Platform

![Kubernetes](https://img.shields.io/badge/Kubernetes-K3d-326CE5?logo=kubernetes)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)
![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus-E6522C?logo=prometheus)
![Grafana](https://img.shields.io/badge/Dashboards-Grafana-F46800?logo=grafana)

Plataforma SRE desplegada en Kubernetes con GitOps, monitorización y auto-remediación.
Todo el proyecto está gestionado como código.

---

## Capturas

### Dashboard de Grafana — Métricas de nodos

![Grafana](docs/screenshots/grafana-dashboard.jpeg)

### ArgoCD — Aplicaciones desplegadas

![ArgoCD](docs/screenshots/argocd-applications.jpeg)


### Kubernetes ### Kubernetes

![Kubernetes Pods](docs/screenshots/kubernetes.jpeg)

---

## Arquitectura

```
                    ┌──────────────────┐
                    │     Usuario      │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
      ┌──────────┐   ┌──────────┐   ┌──────────┐
      │ ArgoCD   │   │ Grafana  │   │ demo-app │
      └──────────┘   └────┬─────┘   └──────────┘
                          │
                          ▼
                    ┌──────────┐
                    │Prometheus│
                    └────┬─────┘
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
        ┌────────┐ ┌────────┐ ┌────────┐
        │Node Exp│ │Node Exp│ │Node Exp│
        └────────┘ └────────┘ └────────┘
                         │
                         │ alertas
                         ▼
                 ┌───────────────┐
                 │ Alertmanager  │
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

| Capa | Tecnología | Para qué |
|---|---|---|
| **Contenedores** | Docker | Motor de contenedores |
| **Orquestación** | Kubernetes (K3d) | Cluster local |
| **GitOps** | ArgoCD | Despliegue desde Git |
| **Ingress** | Nginx Ingress | Exponer servicios |
| **Métricas** | Prometheus + Node Exporter | Recoger métricas |
| **Dashboards** | Grafana | Visualización |
| **Alertas** | Alertmanager | Enviar alertas |
| **Auto-remediación** | EDA (ansible-rulebook) | Decidir playbook |
| **Remediación** | Ansible | Ejecutar playbook |

---

## Estructura del proyecto

```
sre-observability-platform/
├── bootstrap/
│   ├── bootstrap.sh
│   ├── namespaces.yaml
│   └── argocd-apps.yaml
├── gitops/
│   └── helm/
│       └── demo-app/
├── docs/
│   ├── ARQUITECTURA.md
│   └── screenshots/
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

Tarda 3-4 minutos en levantar:
- Cluster K3d
- ArgoCD
- Nginx Ingress
- Prometheus + Grafana + Alertmanager
- demo-app

---

## Cómo acceder

| Servicio | Comando | URL |
|---|---|---|
| **ArgoCD** | `kubectl port-forward svc/argocd-server -n argocd 9090:443` | https://localhost:9090 |
| **Grafana** | `kubectl port-forward svc/prometheus-grafana -n observability 3000:80` | http://localhost:3000 |
| **Prometheus** | `kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090` | http://localhost:9090 |
| **demo-app** | `kubectl port-forward svc/demo-app -n applications 8080:80` | http://localhost:8080 |

**Credenciales:**

- **ArgoCD:** usuario `admin`, contraseña:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

- **Grafana:** usuario `admin`, contraseña `admin`

---

## Qué aprendí

- **Kubernetes**: pods, services, namespaces, ingress, CRDs, statefulsets
- **K3d**: Kubernetes dentro de Docker
- **GitOps con ArgoCD**: sincronización desde Git, selfHeal, prune
- **Helm**: charts, values, templates
- **Prometheus**: métricas, PromQL, ServiceMonitors, PrometheusRules
- **Grafana**: dashboards, data sources
- **Alertmanager**: alertas, webhooks
- **Ansible**: playbooks de remediación
- **EDA**: ansible-rulebook, event-driven automation

---

## Posibles mejoras

- [ ] Añadir reglas de alerta personalizadas
- [ ] Conectar Alertmanager con EDA
- [ ] Crear playbooks de remediación
- [ ] Probar el flujo completo de auto-remediación
- [ ] Añadir Elasticsearch para logs
- [ ] Desplegar en cloud (AWS, Azure, GCP)

---

## Autor

**Victor Ramos** — [@vramosr1986-gif](https://github.com/vramosr1986-gif)

Proyecto de aprendizaje de SRE, Kubernetes y GitOps.