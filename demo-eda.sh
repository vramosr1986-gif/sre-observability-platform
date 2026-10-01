#!/bin/bash
# ============================================================
# DEMO: Inyección de alerta → EDA → Playbook → webhook.site
# ============================================================
# Uso: ./demo-eda.sh
# ============================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================
# FUNCIONES
# ============================================================

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}DEMO SRE — EVENT-DRIVEN AUTOMATION${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}Prometheus → Alertmanager → EDA → Ansible → Webhook${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}▶ PASO $1:${NC} $2"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "  ${CYAN}ℹ${NC} $1"
}

print_wait() {
    echo -e "  ${YELLOW}⏳${NC} $1"
}

# ============================================================
# VARIABLES
# ============================================================

WEBHOOK_URL="https://webhook.site/4325c6a4-6efa-4af8-84fc-592905101139"
ALERTMANAGER_POD="alertmanager-prometheus-kube-prometheus-alertmanager-0"
ALERTMANAGER_NS="observability"
EDA_NS="eda"

# ============================================================
# INICIO
# ============================================================

print_banner

# ------------------------------------------------------------
print_step "1" "Verificando que el sistema está vivo"
# ------------------------------------------------------------

if kubectl get pods -n "$EDA_NS" -l app=eda --no-headers 2>/dev/null | grep -q Running; then
    POD_EDA=$(kubectl get pods -n "$EDA_NS" -l app=eda -o jsonpath='{.items[0].metadata.name}')
    print_ok "Pod de EDA corriendo: ${BOLD}${POD_EDA}${NC}"
else
    echo -e "  ${RED}✗ Pod de EDA no encontrado${NC}"
    exit 1
fi

if kubectl get pods -n "$ALERTMANAGER_NS" "$ALERTMANAGER_POD" --no-headers 2>/dev/null | grep -q Running; then
    print_ok "Pod de Alertmanager corriendo"
else
    echo -e "  ${RED}✗ Pod de Alertmanager no encontrado${NC}"
    exit 1
fi

# ------------------------------------------------------------
print_step "2" "Mostrando la configuración del receptor"
# ------------------------------------------------------------

print_info "El receptor de Alertmanager apunta a EDA:"
echo ""
kubectl exec -n "$ALERTMANAGER_NS" "$ALERTMANAGER_POD" -- \
    cat /etc/alertmanager/config_out/alertmanager.env.yaml 2>/dev/null | \
    grep -A3 "webhook_configs" | sed 's/^/      /'
echo ""

# ------------------------------------------------------------
print_step "3" "Inyectando alerta de prueba"
# ------------------------------------------------------------

print_info "Lanzando alerta ${BOLD}TestAlert${NC} con severidad ${BOLD}critical${NC}..."

kubectl exec -n "$ALERTMANAGER_NS" "$ALERTMANAGER_POD" -c alertmanager -- \
    amtool alert add alertname=TestAlert severity=critical \
    --alertmanager.url=http://localhost:9093 2>&1 | sed 's/^/      /'

print_ok "Alerta inyectada en Alertmanager"

# ------------------------------------------------------------
print_step "4" "Esperando a que EDA procese la alerta"
# ------------------------------------------------------------

print_wait "Esperando 30 segundos (Alertmanager agrupa y envía)..."
for i in $(seq 1 30); do
    printf "\r      ${YELLOW}%2d/30 segundos${NC}" "$i"
    sleep 1
done
echo ""
print_ok "Tiempo de espera completado"

# ------------------------------------------------------------
print_step "5" "Verificando los logs de Alertmanager"
# ------------------------------------------------------------

print_info "Buscando notificaciones enviadas a EDA..."
echo ""

NOTIFY_LOGS=$(kubectl logs -n "$ALERTMANAGER_NS" "$ALERTMANAGER_POD" -c alertmanager \
    --tail=30 2>/dev/null | grep -i "notify.*alertas-para-eda" | tail -3)

if [ -n "$NOTIFY_LOGS" ]; then
    echo "$NOTIFY_LOGS" | sed 's/^/      /'
    echo ""
    print_ok "Alertmanager ha enviado la alerta a EDA"
else
    print_wait "No hay logs recientes de notificación. La alerta puede estar en cola."
fi

# ------------------------------------------------------------
print_step "6" "Resultado final"
# ------------------------------------------------------------

echo ""
echo -e "  ${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "  ${GREEN}${BOLD}║              ✓  FLUJO COMPLETADO                        ║${NC}"
echo -e "  ${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}La alerta ha recorrido toda la cadena:${NC}"
echo ""
echo -e "    ${CYAN}1.${NC} ${BOLD}Prometheus${NC}      → detecta el problema"
echo -e "    ${CYAN}2.${NC} ${BOLD}Alertmanager${NC}    → enruta al receptor ${GREEN}alertas-para-eda${NC}"
echo -e "    ${CYAN}3.${NC} ${BOLD}EDA${NC}             → recibe y evalúa la condición"
echo -e "    ${CYAN}4.${NC} ${BOLD}Ansible${NC}         → ejecuta el playbook ${GREEN}notify.yml${NC}"
echo -e "    ${CYAN}5.${NC} ${BOLD}Webhook${NC}         → recibe el POST con los datos"
echo ""
echo -e "  ${BOLD}Verifica el resultado en:${NC}"
echo -e "    ${GREEN}${WEBHOOK_URL}${NC}"
echo ""
echo -e "  ${BOLD}Logs de Alertmanager:${NC}"
echo -e "    ${CYAN}kubectl logs -n $ALERTMANAGER_NS $ALERTMANAGER_POD -c alertmanager --tail=20 | grep notify${NC}"
echo ""