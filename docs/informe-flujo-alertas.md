# Informe de diagnóstico del flujo de alertas

## Resumen ejecutivo

El pipeline tenía fallos en etapas distintas, que al principio parecían un único problema. Prometheus evaluaba las reglas y Alertmanager entregaba alertas a EDA. EDA recibía los eventos, pero `ansible-rulebook` estaba limitando el playbook usando `event.meta.hosts`; ese valor no coincidía con un host utilizable del inventario y Ansible terminaba con `skipping: no hosts matched`. Tras corregir ese límite, el playbook comenzó a escribir en `/tmp/eventos.txt` y a intentar el POST a webhook.site. webhook.site respondió HTTP 429 por exceso de solicitudes.

## Síntomas y causas

### 1. Las reglas y Alertmanager

Las reglas propias son `HighCPU`, `HighMemory` y `PodNotReady`. Prometheus llegó a mostrar `PodNotReady` y `HighMemory` en estado firing. Alertmanager registró `Notify success` para esas alertas y su receptor `alertas-para-eda` apuntaba al endpoint `/endpoint` del Service EDA.

`Notify success` solo valida la entrega desde Alertmanager a EDA. No valida la ejecución del playbook ni el POST posterior a webhook.site.

### 2. El playbook no encontraba hosts

Los logs de EDA repetían `PLAY ... skipping: no hosts matched`, y `/tmp/eventos.txt` no existía. `localhost` sí aparecía en el inventario y `ansible-playbook --list-hosts` lo encontraba, por lo que el inventario básico no era la causa.

La causa estaba en el límite de hosts que aplica `ansible-rulebook`: si un evento contiene `meta.hosts`, EDA lo pasa a la acción `run_playbook` como límite. El filtro tenía `exclude_keys: ["meta.hosts"]`, pero `json_filter` busca claves individuales y procesa recursivamente; no interpreta esa cadena como una ruta. La clave que debía excluirse era `hosts`.

La configuración vigente usa:

```yaml
filters:
  - eda.builtin.json_filter:
      exclude_keys:
        - hosts
```

Así, el playbook se ejecuta con el host `localhost` del ruleset/inventario, sin limitarse a la etiqueta `instance` de Prometheus.

### 3. Los hosts `IP:puerto` no eran la solución

Se intentó añadir al inventario valores como `10.42.2.19:8080` y `172.19.0.2:9100`, tomados de la etiqueta `instance`. La prueba con `ansible-inventory --host` mostró que Ansible no reconoce esas cadenas como patrones válidos de host. Además, el playbook de notificación corre localmente en `localhost`; no necesita conectarse a node-exporter ni a kube-state-metrics. Se retiraron esos aliases.

### 4. El archivo vive dentro del pod

El playbook usa `blockinfile` para crear `/tmp/eventos.txt` en el contenedor EDA. Una vez corregido el límite de hosts, se confirmó que el archivo contenía entradas de `PodNotReady` y `HighMemory`.

`/tmp` pertenece al filesystem efímero del contenedor. El archivo desaparece cuando Kubernetes reemplaza el pod; para conservar el historial hace falta montar almacenamiento persistente o exportar los eventos a un servicio externo.

### 5. Rate limit en webhook.site

El POST del playbook usa el token `015924ce-3860-4a56-9ccf-05efe5ee384d`. EDA ejecutó la tarea de escritura local y luego la tarea HTTP, pero webhook.site devolvió `429 Too Many Requests`. La configuración de Alertmanager usaba intervalos de grupo y repetición de 30 segundos, lo que produjo notificaciones recurrentes durante las pruebas.

La recomendación es aumentar `repeat_interval` (por ejemplo, a `5m` o más) y no interpretar `Notify success` como confirmación del POST externo. El éxito externo se confirma con una respuesta HTTP 2xx y una solicitud nueva en la bandeja de webhook.site.

## Estado comprobado al documentar

- Argo CD sincronizó el commit `ecfa211` para `eda-app`.
- EDA ejecutó el playbook en `localhost` y escribió datos de `PodNotReady` y `HighMemory` en `/tmp/eventos.txt`.
- La llamada HTTP a webhook.site fue rechazada con HTTP 429 durante la prueba observada.
- Alertmanager tenía `group_interval: 30s` y `repeat_interval: 30s` en la configuración mostrada durante esa prueba.

## Interpretación de capturas

Las capturas recientes de Prometheus muestran la métrica de readiness y alertas firing. Las capturas de Alertmanager que agrupan también reglas predeterminadas, y la captura de la expresión antigua de `PodNotReady`, son evidencia histórica del diagnóstico; no describen la configuración final de Git, que limita el receptor de EDA a las tres alertas propias.
