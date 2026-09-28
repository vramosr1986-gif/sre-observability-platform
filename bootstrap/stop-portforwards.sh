#!/bin/bash
# Para los port-forwards lanzados por bootstrap.sh

PIDFILE="/tmp/sre-lab-portforwards.pid"
MAPFILE="/tmp/sre-lab-portforwards.map"

if [ ! -f "${PIDFILE}" ]; then
    echo "No hay port-forwards de bootstrap.sh en marcha."
    exit 0
fi

COUNT=0

while read -r PID; do
    [ -z "${PID}" ] && continue
    if kill "${PID}" 2>/dev/null; then
        COUNT=$((COUNT + 1))
    fi
done < "${PIDFILE}"

rm -f "${PIDFILE}" "${MAPFILE}"

echo "Detenidos ${COUNT} port-forward(s)."

if [ "${COUNT}" -eq 0 ]; then
    echo "Nota: habia forwards antiguos que ya estaban Muertos."
fi
