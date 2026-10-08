# Dashboard — Examen Técnico #1813

**Proyecto:** Sistema de Gestión de Coworking  
**Código del Examen:** `1813`  
**Estudiante:** Julio Ernesto Castaño Palacios  
---

##  1. Contexto 

1. **Disponibilidad de Espacios:** Saber al instante qué salas, escritorios u oficinas están libres u ocupadas en el momento actual, junto con el horario de su próxima reserva para evitar solapamientos o asignar clientes de paso.
2. **Cierre y Monitoreo Diario:** Generar un reporte ejecutivo del día con el volumen de reservas gestionadas, usuarios que asistieron a las instalaciones y el total recaudado en caja/pagos.
3. **Aforo y Seguridad Presencial:**  consulta para mostrar en pantalla: "Ahora mismo hay X personas en el coworking".

---

### 2.1 Vista: `VW_EstadoEspacios`

####  Requisito:
Crear una vista `VW_EstadoEspacios` que muestre:
- **Espacio** (nombre del espacio físico)
- **Estado** (`Libre` / `Ocupado`)
- **Próxima reserva** (fecha y hora del próximo uso programado)

####  Lógica de Implementación:
- **Estado Dinámico (`NOW()`):** Se evalúa mediante una cláusula condicional `CASE` con una subconsulta correlacionada `EXISTS`. Un espacio está `'Ocupado'` si existe una reserva con estado `'Confirmada'` cuyo rango temporal cubra el instante exacto actual (`NOW() BETWEEN r.fecha_inicio AND r.fecha_fin`). En caso contrario, se reporta como `'Libre'`.
- **Próxima Reserva:** Se determina mediante una subconsulta que obtiene el valor mínimo (`MIN(fecha_inicio)`) de las reservas futuras (`fecha_inicio > NOW()`) que se encuentren en estado `'Confirmada'` o `'Pendiente'`.

```sql
CREATE OR REPLACE VIEW VW_EstadoEspacios AS
SELECT
    e.nombre AS espacio,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM reservas r
            WHERE r.espacio_id = e.id
              AND r.estado = 'Confirmada'
              AND NOW() BETWEEN r.fecha_inicio AND r.fecha_fin
        ) THEN 'Ocupado'
        ELSE 'Libre'
    END AS estado,
    (
        SELECT MIN(r_prox.fecha_inicio)
        FROM reservas r_prox
        WHERE r_prox.espacio_id = e.id
          AND r_prox.estado IN ('Confirmada', 'Pendiente')
          AND r_prox.fecha_inicio > NOW()
    ) AS proxima_reserva
FROM espacios e
ORDER BY e.nombre ASC;
```

---

### 3. Procedimiento Almacenado: `sp_GenerarReporteDiario`

####  Requisito:
Crear un procedimiento `sp_GenerarReporteDiario` que devuelva:
- **Total de reservas hoy**
- **Usuarios activos en el día**
- **Ingresos del día**

####  Lógica de Implementación:
1. **Fecha de Corte:** Utiliza `CURDATE()`. Para facilitar pruebas, permite sobreescribir la fecha asignando opcionalmente la variable de sesión `@fecha_reporte` (`SET v_fecha = COALESCE(@fecha_reporte, CURDATE())`).
2. **Total de Reservas Hoy:** Realiza un `COUNT(*)` sobre la tabla `reservas` para aquellas cuya `DATE(fecha_inicio) = v_fecha` y no hayan sido canceladas (`estado IN ('Confirmada', 'Pendiente', 'Completada')`).
3. **Usuarios Activos en el Día:** Calcula el aforo presencial único diario mediante `COUNT(DISTINCT usuario_id)` en la tabla `accesos`, validando que el ingreso físico haya sido autorizado (`estado_intento = 'Permitido'`) en la fecha evaluada (`DATE(fecha_hora_entrada) = v_fecha`).
4. **Ingresos del Día:** Suma el flujo de caja real con `COALESCE(SUM(monto), 0.00)` desde la tabla `pagos` para cobros efectivamente aplicados (`estado = 'Aplicado'`) en dicha fecha (`DATE(fecha_pago) = v_fecha`).

```sql
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_GenerarReporteDiario$$

CREATE PROCEDURE sp_GenerarReporteDiario()
BEGIN
    DECLARE v_fecha DATE;

    SET v_fecha = COALESCE(@fecha_reporte, CURDATE());

    SELECT
        v_fecha AS fecha_reporte,
        (
            SELECT COUNT(*)
            FROM reservas
            WHERE DATE(fecha_inicio) = v_fecha
              AND estado IN ('Confirmada', 'Pendiente', 'Completada')
        ) AS total_reservas_hoy,
        (
            SELECT COUNT(DISTINCT usuario_id)
            FROM accesos
            WHERE DATE(fecha_hora_entrada) = v_fecha
              AND estado_intento = 'Permitido'
        ) AS usuarios_activos_dia,
        (
            SELECT COALESCE(SUM(monto), 0.00)
            FROM pagos
            WHERE DATE(fecha_pago) = v_fecha
              AND estado = 'Aplicado'
        ) AS ingresos_dia;
END$$

DELIMITER ;
```

### 4. Consulta en Tiempo Real para Pantalla de Recepción

####  Requisito:
Simular una consulta para mostrar en pantalla: *"Ahora mismo hay X personas en el coworking"*, empleando `COUNT` y `WHERE` apropiados.

####  Lógica de Implementación:
- **Presencia en el Recinto:** Un usuario se encuentra actualmente en las instalaciones si su ingreso físico fue autorizado (`estado_intento = 'Permitido'`) y **aún no ha registrado su evento de salida** (`fecha_hora_salida IS NULL`).
- **Conteo Único:** Se utiliza `COUNT(DISTINCT usuario_id)` para garantizar precisión ante eventuales lecturas duplicadas de sensores.
- **Formateo de Salida:** Se aplica la función `CONCAT` para generar la cadena exacta requerida por el display del lobby.

```sql
SELECT 
    CONCAT('Ahora mismo hay ', COUNT(DISTINCT usuario_id), ' personas en el coworking') AS mensaje_pantalla
FROM accesos
WHERE estado_intento = 'Permitido'
  AND fecha_hora_salida IS NULL;
```
### 5. Verificación de la Vista de Espacios
```sql
USE coworking;
SELECT * FROM VW_EstadoEspacios;
```
<img width="1363" height="707" alt="image" src="https://github.com/user-attachments/assets/15470a39-28f0-4d34-bb02-0fe72d5382dc" />


### 6. Verificación del Procedimiento de Reporte Diario

#### En tiempo real (día de hoy):
```sql
CALL sp_GenerarReporteDiario();
```
<img width="1365" height="712" alt="image" src="https://github.com/user-attachments/assets/715a691a-8528-478e-8297-4bc8b8def4a5" />

#### Simulación con fecha del dataset de prueba (ej. `2026-03-31`):
```sql
SET @fecha_reporte = '2026-03-31';
CALL sp_GenerarReporteDiario();
SET @fecha_reporte = NULL; -- Restablece a tiempo real
```
<img width="1365" height="721" alt="image" src="https://github.com/user-attachments/assets/b5e442cd-d406-48aa-8031-8c643c497a5d" />


### 7. Verificación de la Consulta en Pantalla
```sql
SELECT 
    CONCAT('Ahora mismo hay ', COUNT(DISTINCT usuario_id), ' personas en el coworking') AS mensaje_pantalla
FROM accesos
WHERE estado_intento = 'Permitido'
  AND fecha_hora_salida IS NULL;

-- Inserción de los 5 accesos activos en tiempo real (fecha_hora_salida IS NULL):
INSERT INTO accesos (usuario_id, reserva_id, fecha_hora_entrada, fecha_hora_salida, metodo_acceso, estado_intento, motivo_rechazo) VALUES
(6,  NULL, DATE_SUB(NOW(), INTERVAL 120 MINUTE), NULL, 'RFID',   'Permitido', NULL), 
(7,  NULL, DATE_SUB(NOW(), INTERVAL 90 MINUTE),  NULL, 'QR',     'Permitido', NULL), 
(8,  NULL, DATE_SUB(NOW(), INTERVAL 60 MINUTE),  NULL, 'RFID',   'Permitido', NULL), 
(10, NULL, DATE_SUB(NOW(), INTERVAL 35 MINUTE),  NULL, 'Manual', 'Permitido', NULL), 
(11, NULL, DATE_SUB(NOW(), INTERVAL 10 MINUTE),  NULL, 'RFID',   'Permitido', NULL); 
```
<img width="1364" height="719" alt="image" src="https://github.com/user-attachments/assets/11bc26bf-a477-40e7-99d0-f22ff07a8537" />


## 8. Estructura de Entregables

```text
├── 1813-examen.sql       # Script SQL completo (Vista, Stored Procedure y Consulta)
└── README.md             # Documentación técnica, justificación de negocio y pruebas
