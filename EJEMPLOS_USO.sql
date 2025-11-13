/*******************************************************************************
 * ARCHIVO: EJEMPLOS_USO.sql
 * DESCRIPCIÓN: Ejemplos completos y ejecutables de uso de FN_ENVIAR_NOTIFICACION
 * VERSIÓN: 2.0
 * FECHA: 2025-01-13
 *
 * Este archivo contiene 7 ejemplos prácticos que demuestran diferentes
 * casos de uso de la función FN_ENVIAR_NOTIFICACION, desde casos básicos
 * hasta escenarios avanzados con construcción dinámica de IDs y validaciones.
 ******************************************************************************/

-- ============================================================================
-- EJEMPLO 1: Construir Lista de IDs desde Tabla Relacionada
-- ============================================================================
-- Caso: Enviar todos los certificados de una persona específica
-- ============================================================================

PROMPT ===== EJEMPLO 1: Construir Lista de IDs Dinámicamente =====

DECLARE
    v_id_notif     NUMBER;
    v_ids_archivos VARCHAR2(4000);
    v_id_persona   NUMBER := 5001; -- Cambiar por un ID real
    v_placeholders CLOB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Ejemplo 1: Construcción Dinámica de IDs ===');
    DBMS_OUTPUT.PUT_LINE('');

    -- Paso 1: Obtener IDs de archivos de la persona
    SELECT LISTAGG(ID_ARCHIVO, ',') WITHIN GROUP (ORDER BY ID_ARCHIVO)
    INTO v_ids_archivos
    FROM ADM_ARCHIVO
    WHERE ID_PERSONA = v_id_persona
      AND TIPO_DOCUMENTO IN ('CERTIFICADO', 'LICENCIA')
      AND ARCHIVO IS NOT NULL
      AND DBMS_LOB.GETLENGTH(ARCHIVO) <= (5 * 1024 * 1024); -- Pre-filtrar por tamaño

    DBMS_OUTPUT.PUT_LINE('IDs encontrados: ' || NVL(v_ids_archivos, 'NINGUNO'));

    -- Paso 2: Enviar solo si hay archivos
    IF v_ids_archivos IS NOT NULL THEN

        -- Construir JSON con placeholders
        SELECT NOMBRE || ' ' || APELLIDO, EMAIL
        INTO v_placeholders
        FROM PA_PERSONA
        WHERE ID_PERSONA = v_id_persona;

        v_placeholders := '{
            "NOMBRE_COMPLETO": "' || v_placeholders || '",
            "FECHA_ENVIO": "' || TO_CHAR(SYSDATE, 'DD/MM/YYYY') || '",
            "CANTIDAD_ARCHIVOS": "' || REGEXP_COUNT(v_ids_archivos, ',') + 1 || '"
        }';

        -- Enviar notificación
        v_id_notif := FN_ENVIAR_NOTIFICACION(
            p_codigo_plantilla => 'ENVIO_DOCUMENTOS',
            p_destinatario     => 'usuario@ejemplo.com',
            p_id_persona       => v_id_persona,
            p_placeholders     => v_placeholders,
            p_ids_archivos     => v_ids_archivos
        );

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✓ Notificación enviada correctamente');
        DBMS_OUTPUT.PUT_LINE('  ID Notificación: ' || v_id_notif);
    ELSE
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✗ No se encontraron archivos válidos para enviar');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ============================================================================
-- EJEMPLO 2: Validar Tamaños ANTES de Enviar
-- ============================================================================
-- Caso: Revisar todos los archivos y mostrar advertencias antes de enviar
-- ============================================================================

PROMPT ===== EJEMPLO 2: Validación Previa de Tamaños =====

DECLARE
    v_id_notif          NUMBER;
    v_ids_enviar        VARCHAR2(4000);
    v_ids_omitir        VARCHAR2(4000);
    v_count_validos     NUMBER := 0;
    v_count_invalidos   NUMBER := 0;
    v_limite_bytes      CONSTANT NUMBER := 5 * 1024 * 1024;
    v_ids_solicitud     VARCHAR2(200) := '1001,1002,1003,1004,1005'; -- IDs a revisar
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Ejemplo 2: Validación Previa de Tamaños ===');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('IDs solicitados: ' || v_ids_solicitud);
    DBMS_OUTPUT.PUT_LINE('');

    -- Analizar cada archivo
    FOR r IN (
        SELECT
            a.ID_ARCHIVO,
            a.NOMBRE_CARGUE_USUARIO,
            DBMS_LOB.GETLENGTH(a.ARCHIVO) AS TAMANO_BYTES,
            ROUND(DBMS_LOB.GETLENGTH(a.ARCHIVO) / (1024 * 1024), 2) AS TAMANO_MB
        FROM ADM_ARCHIVO a
        WHERE a.ID_ARCHIVO IN (
            SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(v_ids_solicitud, '[^,]+', 1, LEVEL)))
            FROM DUAL
            CONNECT BY LEVEL <= REGEXP_COUNT(v_ids_solicitud, ',') + 1
        )
        AND a.ARCHIVO IS NOT NULL
    ) LOOP

        IF r.TAMANO_BYTES <= v_limite_bytes THEN
            -- Archivo válido
            v_count_validos := v_count_validos + 1;
            IF v_ids_enviar IS NOT NULL THEN
                v_ids_enviar := v_ids_enviar || ',';
            END IF;
            v_ids_enviar := v_ids_enviar || r.ID_ARCHIVO;

            DBMS_OUTPUT.PUT_LINE('✓ ID ' || r.ID_ARCHIVO || ': ' ||
                               r.NOMBRE_CARGUE_USUARIO || ' (' || r.TAMANO_MB || ' MB) - OK');
        ELSE
            -- Archivo excede límite
            v_count_invalidos := v_count_invalidos + 1;
            IF v_ids_omitir IS NOT NULL THEN
                v_ids_omitir := v_ids_omitir || ',';
            END IF;
            v_ids_omitir := v_ids_omitir || r.ID_ARCHIVO;

            DBMS_OUTPUT.PUT_LINE('✗ ID ' || r.ID_ARCHIVO || ': ' ||
                               r.NOMBRE_CARGUE_USUARIO || ' (' || r.TAMANO_MB || ' MB) - EXCEDE LÍMITE');
        END IF;

    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Resumen:');
    DBMS_OUTPUT.PUT_LINE('  Archivos válidos: ' || v_count_validos);
    DBMS_OUTPUT.PUT_LINE('  Archivos omitidos: ' || v_count_invalidos);
    DBMS_OUTPUT.PUT_LINE('');

    -- Enviar solo si hay archivos válidos
    IF v_ids_enviar IS NOT NULL THEN
        v_id_notif := FN_ENVIAR_NOTIFICACION(
            p_codigo_plantilla => 'DOCUMENTOS',
            p_destinatario     => 'usuario@ejemplo.com',
            p_ids_archivos     => v_ids_enviar
        );

        DBMS_OUTPUT.PUT_LINE('✓ Correo enviado. ID Notificación: ' || v_id_notif);
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ No hay archivos válidos para enviar');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ============================================================================
-- EJEMPLO 3: Filtrar Archivos Válidos por Tipo y Tamaño
-- ============================================================================
-- Caso: Seleccionar solo archivos PDF menores a 5MB
-- ============================================================================

PROMPT ===== EJEMPLO 3: Filtrado Avanzado de Archivos =====

DECLARE
    v_id_notif     NUMBER;
    v_ids_archivos VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Ejemplo 3: Filtrado por Tipo MIME y Tamaño ===');
    DBMS_OUTPUT.PUT_LINE('');

    -- Construir lista de IDs solo de archivos PDF válidos
    SELECT LISTAGG(ID_ARCHIVO, ',') WITHIN GROUP (ORDER BY ID_ARCHIVO)
    INTO v_ids_archivos
    FROM ADM_ARCHIVO
    WHERE MIME_TYPE = 'application/pdf'
      AND ARCHIVO IS NOT NULL
      AND DBMS_LOB.GETLENGTH(ARCHIVO) <= (5 * 1024 * 1024)
      AND FECHA_CARGA >= TRUNC(SYSDATE) - 30 -- Últimos 30 días
      AND ROWNUM <= 10; -- Limitar a 10 archivos

    DBMS_OUTPUT.PUT_LINE('IDs de PDFs válidos: ' || NVL(v_ids_archivos, 'NINGUNO'));

    IF v_ids_archivos IS NOT NULL THEN
        v_id_notif := FN_ENVIAR_NOTIFICACION(
            p_codigo_plantilla => 'ENVIO_PDFS',
            p_destinatario     => 'documentos@ejemplo.com',
            p_ids_archivos     => v_ids_archivos
        );

        DBMS_OUTPUT.PUT_LINE('✓ Notificación enviada. ID: ' || v_id_notif);
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ No se encontraron PDFs válidos');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ============================================================================
-- EJEMPLO 4: Envío Masivo con Control de Errores
-- ============================================================================
-- Caso: Enviar notificaciones a múltiples destinatarios con manejo de errores
-- ============================================================================

PROMPT ===== EJEMPLO 4: Envío Masivo Controlado =====

DECLARE
    v_id_notif      NUMBER;
    v_count_ok      NUMBER := 0;
    v_count_error   NUMBER := 0;
    v_placeholders  CLOB;

    -- Cursor de destinatarios
    CURSOR c_destinatarios IS
        SELECT
            p.ID_PERSONA,
            p.EMAIL,
            p.NOMBRE || ' ' || p.APELLIDO AS NOMBRE_COMPLETO
        FROM PA_PERSONA p
        WHERE p.EMAIL IS NOT NULL
          AND p.ACTIVO = 'S'
          AND ROWNUM <= 5; -- Limitar para el ejemplo

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Ejemplo 4: Envío Masivo con Control ===');
    DBMS_OUTPUT.PUT_LINE('');

    FOR r IN c_destinatarios LOOP
        BEGIN
            -- Construir placeholders para cada destinatario
            v_placeholders := '{
                "NOMBRE_COMPLETO": "' || r.NOMBRE_COMPLETO || '",
                "FECHA": "' || TO_CHAR(SYSDATE, 'DD/MM/YYYY') || '"
            }';

            -- Enviar notificación
            v_id_notif := FN_ENVIAR_NOTIFICACION(
                p_codigo_plantilla => 'NOTIFICACION_GENERAL',
                p_destinatario     => r.EMAIL,
                p_id_persona       => r.ID_PERSONA,
                p_placeholders     => v_placeholders
            );

            v_count_ok := v_count_ok + 1;
            DBMS_OUTPUT.PUT_LINE('✓ Enviado a: ' || r.EMAIL || ' (ID: ' || v_id_notif || ')');

        EXCEPTION
            WHEN OTHERS THEN
                v_count_error := v_count_error + 1;
                DBMS_OUTPUT.PUT_LINE('✗ Error al enviar a: ' || r.EMAIL || ' - ' || SQLERRM);
        END;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Resumen del envío masivo:');
    DBMS_OUTPUT.PUT_LINE('  Exitosos: ' || v_count_ok);
    DBMS_OUTPUT.PUT_LINE('  Errores: ' || v_count_error);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ============================================================================
-- EJEMPLO 5: Selección Dinámica de Archivos Específicos
-- ============================================================================
-- Caso: Enviar solo archivos de un tipo específico basado en condiciones
-- ============================================================================

PROMPT ===== EJEMPLO 5: Selección Condicional de Archivos =====

DECLARE
    v_id_notif       NUMBER;
    v_ids_archivos   VARCHAR2(4000);
    v_tipo_envio     VARCHAR2(20) := 'URGENTE'; -- Puede ser: URGENTE, NORMAL, TODOS
    v_placeholders   CLOB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Ejemplo 5: Selección Condicional ===');
    DBMS_OUTPUT.PUT_LINE('Tipo de envío: ' || v_tipo_envio);
    DBMS_OUTPUT.PUT_LINE('');

    -- Seleccionar archivos según el tipo de envío
    CASE v_tipo_envio
        WHEN 'URGENTE' THEN
            -- Solo archivos marcados como urgentes y pequeños
            SELECT LISTAGG(ID_ARCHIVO, ',') WITHIN GROUP (ORDER BY ID_ARCHIVO)
            INTO v_ids_archivos
            FROM ADM_ARCHIVO
            WHERE PRIORIDAD = 'ALTA'
              AND DBMS_LOB.GETLENGTH(ARCHIVO) <= (2 * 1024 * 1024) -- Máx 2MB
              AND ARCHIVO IS NOT NULL
              AND ROWNUM <= 3;

        WHEN 'NORMAL' THEN
            -- Archivos normales hasta 5MB
            SELECT LISTAGG(ID_ARCHIVO, ',') WITHIN GROUP (ORDER BY ID_ARCHIVO)
            INTO v_ids_archivos
            FROM ADM_ARCHIVO
            WHERE PRIORIDAD = 'MEDIA'
              AND DBMS_LOB.GETLENGTH(ARCHIVO) <= (5 * 1024 * 1024)
              AND ARCHIVO IS NOT NULL
              AND ROWNUM <= 5;

        WHEN 'TODOS' THEN
            -- Todos los archivos válidos
            SELECT LISTAGG(ID_ARCHIVO, ',') WITHIN GROUP (ORDER BY ID_ARCHIVO)
            INTO v_ids_archivos
            FROM ADM_ARCHIVO
            WHERE DBMS_LOB.GETLENGTH(ARCHIVO) <= (5 * 1024 * 1024)
              AND ARCHIVO IS NOT NULL
              AND ROWNUM <= 10;
    END CASE;

    DBMS_OUTPUT.PUT_LINE('IDs seleccionados: ' || NVL(v_ids_archivos, 'NINGUNO'));

    IF v_ids_archivos IS NOT NULL THEN
        v_placeholders := '{
            "TIPO_ENVIO": "' || v_tipo_envio || '",
            "FECHA": "' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI') || '"
        }';

        v_id_notif := FN_ENVIAR_NOTIFICACION(
            p_codigo_plantilla => 'ENVIO_' || v_tipo_envio,
            p_destinatario     => 'destinatario@ejemplo.com',
            p_placeholders     => v_placeholders,
            p_ids_archivos     => v_ids_archivos
        );

        DBMS_OUTPUT.PUT_LINE('✓ Notificación enviada. ID: ' || v_id_notif);
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ No se encontraron archivos para el criterio seleccionado');
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ============================================================================
-- EJEMPLO 6: Reporte de Archivos que Serían Omitidos
-- ============================================================================
-- Caso: Generar reporte antes de enviar para revisar qué archivos se omitirían
-- ============================================================================

PROMPT ===== EJEMPLO 6: Reporte Pre-Envío =====

DECLARE
    v_limite_bytes CONSTANT NUMBER := 5 * 1024 * 1024;
    v_total        NUMBER := 0;
    v_validos      NUMBER := 0;
    v_omitidos     NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Ejemplo 6: Reporte de Validación de Archivos ===');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Límite permitido: 5 MB');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('REPORTE DE ARCHIVOS:');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));

    FOR r IN (
        SELECT
            ID_ARCHIVO,
            NOMBRE_CARGUE_USUARIO,
            MIME_TYPE,
            DBMS_LOB.GETLENGTH(ARCHIVO) AS TAMANO_BYTES,
            ROUND(DBMS_LOB.GETLENGTH(ARCHIVO) / (1024 * 1024), 2) AS TAMANO_MB,
            CASE
                WHEN DBMS_LOB.GETLENGTH(ARCHIVO) <= v_limite_bytes THEN 'VÁLIDO'
                ELSE 'OMITIDO'
            END AS ESTADO
        FROM ADM_ARCHIVO
        WHERE ARCHIVO IS NOT NULL
          AND ROWNUM <= 20 -- Limitar para el ejemplo
        ORDER BY DBMS_LOB.GETLENGTH(ARCHIVO) DESC
    ) LOOP
        v_total := v_total + 1;

        IF r.ESTADO = 'VÁLIDO' THEN
            v_validos := v_validos + 1;
            DBMS_OUTPUT.PUT_LINE(
                '✓ ' ||
                RPAD(r.ID_ARCHIVO, 8) ||
                RPAD(SUBSTR(r.NOMBRE_CARGUE_USUARIO, 1, 30), 32) ||
                LPAD(r.TAMANO_MB || ' MB', 12) ||
                '  [VÁLIDO]'
            );
        ELSE
            v_omitidos := v_omitidos + 1;
            DBMS_OUTPUT.PUT_LINE(
                '✗ ' ||
                RPAD(r.ID_ARCHIVO, 8) ||
                RPAD(SUBSTR(r.NOMBRE_CARGUE_USUARIO, 1, 30), 32) ||
                LPAD(r.TAMANO_MB || ' MB', 12) ||
                '  [EXCEDE LÍMITE]'
            );
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('RESUMEN:');
    DBMS_OUTPUT.PUT_LINE('  Total archivos analizados: ' || v_total);
    DBMS_OUTPUT.PUT_LINE('  Archivos válidos (serán enviados): ' || v_validos);
    DBMS_OUTPUT.PUT_LINE('  Archivos omitidos (exceden 5MB): ' || v_omitidos);
    DBMS_OUTPUT.PUT_LINE('  Porcentaje de éxito: ' ||
                        ROUND((v_validos / NULLIF(v_total, 0)) * 100, 2) || '%');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ============================================================================
-- EJEMPLO 7: Construcción de JSON de Placeholders Dinámico
-- ============================================================================
-- Caso: Construir JSON complejo desde múltiples tablas
-- ============================================================================

PROMPT ===== EJEMPLO 7: JSON Dinámico Complejo =====

DECLARE
    v_id_notif     NUMBER;
    v_placeholders CLOB;
    v_id_persona   NUMBER := 5001; -- Cambiar por un ID real
    v_datos        VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Ejemplo 7: Construcción de JSON Dinámico ===');
    DBMS_OUTPUT.PUT_LINE('');

    -- Construir JSON desde múltiples fuentes
    SELECT
        '{' ||
        '"NOMBRE_COMPLETO": "' || p.NOMBRE || ' ' || p.APELLIDO || '",' ||
        '"TIPO_DOCUMENTO": "' || p.TIPO_DOCUMENTO || '",' ||
        '"NUMERO_DOCUMENTO": "' || p.NUMERO_DOCUMENTO || '",' ||
        '"EMAIL": "' || p.EMAIL || '",' ||
        '"TELEFONO": "' || NVL(p.TELEFONO, 'No registrado') || '",' ||
        '"FECHA_REGISTRO": "' || TO_CHAR(p.FECHA_REGISTRO, 'DD/MM/YYYY') || '",' ||
        '"ESTADO": "' || CASE p.ACTIVO WHEN 'S' THEN 'Activo' ELSE 'Inactivo' END || '",' ||
        '"CANTIDAD_DOCUMENTOS": "' || (
            SELECT COUNT(*)
            FROM ADM_ARCHIVO a
            WHERE a.ID_PERSONA = p.ID_PERSONA
              AND a.ARCHIVO IS NOT NULL
        ) || '"' ||
        '}'
    INTO v_placeholders
    FROM PA_PERSONA p
    WHERE p.ID_PERSONA = v_id_persona;

    DBMS_OUTPUT.PUT_LINE('JSON Generado:');
    DBMS_OUTPUT.PUT_LINE(v_placeholders);
    DBMS_OUTPUT.PUT_LINE('');

    -- Enviar notificación con el JSON dinámico
    v_id_notif := FN_ENVIAR_NOTIFICACION(
        p_codigo_plantilla => 'PERFIL_COMPLETO',
        p_destinatario     => 'admin@ejemplo.com',
        p_id_persona       => v_id_persona,
        p_placeholders     => v_placeholders
    );

    DBMS_OUTPUT.PUT_LINE('✓ Notificación enviada con JSON dinámico');
    DBMS_OUTPUT.PUT_LINE('  ID Notificación: ' || v_id_notif);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

/*******************************************************************************
 * CONSULTAS ÚTILES PARA DEBUGGING Y MONITOREO
 ******************************************************************************/

PROMPT ===== CONSULTAS ÚTILES =====

-- ============================================================================
-- CONSULTA 1: Ver historial completo de notificaciones
-- ============================================================================

PROMPT
PROMPT 1. Historial de notificaciones (últimas 20):
PROMPT

SELECT
    ID_NOTIFICACION,
    DESTINATARIO,
    SUBSTR(ASUNTO, 1, 40) AS ASUNTO,
    CASE ID_ESTADO
        WHEN 1 THEN 'Enviado'
        WHEN 3 THEN 'Pendiente'
        WHEN 4 THEN 'Suspendido'
        ELSE 'Desconocido'
    END AS ESTADO,
    TO_CHAR(FECHA_REGISTRO, 'DD/MM/YYYY HH24:MI') AS FECHA_REGISTRO,
    TO_CHAR(FECHA_ENVIO, 'DD/MM/YYYY HH24:MI') AS FECHA_ENVIO
FROM ADM_NOTIFICACION
ORDER BY FECHA_REGISTRO DESC
FETCH FIRST 20 ROWS ONLY;

-- ============================================================================
-- CONSULTA 2: Análisis de archivos por tamaño
-- ============================================================================

PROMPT
PROMPT 2. Análisis de archivos por tamaño:
PROMPT

SELECT
    COUNT(*) AS TOTAL_ARCHIVOS,
    COUNT(CASE WHEN DBMS_LOB.GETLENGTH(ARCHIVO) <= (1 * 1024 * 1024) THEN 1 END) AS "MENORES_1MB",
    COUNT(CASE WHEN DBMS_LOB.GETLENGTH(ARCHIVO) BETWEEN (1 * 1024 * 1024) AND (5 * 1024 * 1024) THEN 1 END) AS "ENTRE_1_Y_5MB",
    COUNT(CASE WHEN DBMS_LOB.GETLENGTH(ARCHIVO) > (5 * 1024 * 1024) THEN 1 END) AS "MAYORES_5MB",
    ROUND(AVG(DBMS_LOB.GETLENGTH(ARCHIVO)) / (1024 * 1024), 2) AS PROMEDIO_MB,
    ROUND(MAX(DBMS_LOB.GETLENGTH(ARCHIVO)) / (1024 * 1024), 2) AS MAXIMO_MB
FROM ADM_ARCHIVO
WHERE ARCHIVO IS NOT NULL;

-- ============================================================================
-- CONSULTA 3: Top 10 archivos más grandes
-- ============================================================================

PROMPT
PROMPT 3. Top 10 archivos más grandes:
PROMPT

SELECT
    ID_ARCHIVO,
    NOMBRE_CARGUE_USUARIO,
    ROUND(DBMS_LOB.GETLENGTH(ARCHIVO) / (1024 * 1024), 2) AS TAMANO_MB,
    MIME_TYPE,
    CASE
        WHEN DBMS_LOB.GETLENGTH(ARCHIVO) > (5 * 1024 * 1024)
        THEN 'EXCEDE LÍMITE'
        ELSE 'OK'
    END AS VALIDACION
FROM ADM_ARCHIVO
WHERE ARCHIVO IS NOT NULL
ORDER BY DBMS_LOB.GETLENGTH(ARCHIVO) DESC
FETCH FIRST 10 ROWS ONLY;

-- ============================================================================
-- CONSULTA 4: Estadísticas de envíos por estado
-- ============================================================================

PROMPT
PROMPT 4. Estadísticas de envíos por estado:
PROMPT

SELECT
    CASE ID_ESTADO
        WHEN 1 THEN 'Enviado'
        WHEN 3 THEN 'Pendiente'
        WHEN 4 THEN 'Suspendido'
        ELSE 'Desconocido'
    END AS ESTADO,
    COUNT(*) AS CANTIDAD,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS PORCENTAJE
FROM ADM_NOTIFICACION
GROUP BY ID_ESTADO
ORDER BY COUNT(*) DESC;

-- ============================================================================
-- CONSULTA 5: Plantillas activas disponibles
-- ============================================================================

PROMPT
PROMPT 5. Plantillas activas disponibles:
PROMPT

SELECT
    CODIGO,
    SUBSTR(ASUNTO, 1, 50) AS ASUNTO,
    LENGTH(CUERPO_HTML) AS LONGITUD_CUERPO,
    -- Contar placeholders en el cuerpo
    (LENGTH(CUERPO_HTML) - LENGTH(REPLACE(CUERPO_HTML, '{', ''))) AS NUM_PLACEHOLDERS
FROM ADM_PLANT_NOTIF
WHERE ACTIVO = 'S'
ORDER BY CODIGO;

-- ============================================================================
-- CONSULTA 6: Cola de correos pendientes en APEX
-- ============================================================================

PROMPT
PROMPT 6. Cola de correos APEX (últimos 20):
PROMPT

SELECT
    mail_id,
    mail_to,
    SUBSTR(mail_subject, 1, 40) AS SUBJECT,
    mail_send_count AS INTENTOS,
    SUBSTR(mail_send_error, 1, 50) AS ERROR
FROM APEX_MAIL_QUEUE
ORDER BY mail_id DESC
FETCH FIRST 20 ROWS ONLY;

-- ============================================================================
-- CONSULTA 7: Archivos sin BLOB (potenciales problemas)
-- ============================================================================

PROMPT
PROMPT 7. Archivos registrados sin BLOB:
PROMPT

SELECT
    ID_ARCHIVO,
    NOMBRE_CARGUE_USUARIO,
    MIME_TYPE,
    FECHA_CARGA
FROM ADM_ARCHIVO
WHERE ARCHIVO IS NULL
ORDER BY FECHA_CARGA DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT ===== FIN DE EJEMPLOS Y CONSULTAS =====
PROMPT
PROMPT Para más información, consulta el archivo README.md
PROMPT
