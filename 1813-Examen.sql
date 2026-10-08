/*
Parte 1: VISTA VW_EstadoEspacios
    Julio Ernesto Castaño palacios 
*/
CREATE VIEW VW_EstadoEspacios AS
SELECT
    e.nombre AS espacio,
    CASE
    -- Verificacion del estado 
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
        --
        SELECT MIN(r_prox.fecha_inicio)
        FROM reservas r_prox
        WHERE r_prox.espacio_id = e.id
          AND r_prox.estado IN ('Confirmada', 'Pendiente')
          AND r_prox.fecha_inicio > NOW()
    ) AS proxima_reserva
FROM espacios e
ORDER BY e.nombre ASC;

/*
Parte 2: Procedmiento sp_GenerarReporteDiario
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_GenerarReporteDiario$$

CREATE PROCEDURE sp_GenerarReporteDiario()
BEGIN
    DECLARE v_fecha DATE;

    SET v_fecha = COALESCE(@fecha_reporte, CURDATE());

    SELECT
        v_fecha AS fecha_reporte,
        
        -- Total de reservas programadas/activas para el día de hoy
        (
            SELECT COUNT(*)
            FROM reservas
            WHERE DATE(fecha_inicio) = v_fecha
              AND estado IN ('Confirmada', 'Pendiente', 'Completada')
        ) AS total_reservas_hoy,

        --  Usuarios físicos únicos con accesos autorizados en el día
        (
            SELECT COUNT(DISTINCT usuario_id)
            FROM accesos
            WHERE DATE(fecha_hora_entrada) = v_fecha
              AND estado_intento = 'Permitido'
        ) AS usuarios_activos_dia,

        -- Ingresos financieros efectivos percibidos en el día
        (
            SELECT COALESCE(SUM(monto), 0.00)
            FROM pagos
            WHERE DATE(fecha_pago) = v_fecha
              AND estado = 'Aplicado'
        ) AS ingresos_dia;
END$$

DELIMITER ;

/*
parte 3: Consulta simulada para visualizar cuantas personas hay en el coworking

*/

SELECT 
    CONCAT('Ahora mismo hay ', COUNT(DISTINCT usuario_id), ' personas en el coworking') AS mensaje_pantalla
FROM accesos
WHERE estado_intento = 'Permitido'
  AND fecha_hora_salida IS NULL;



