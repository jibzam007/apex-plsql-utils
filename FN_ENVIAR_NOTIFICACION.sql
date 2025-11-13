/*******************************************************************************
 * FUNCIÓN: FN_ENVIAR_NOTIFICACION
 * VERSIÓN: 2.0
 * FECHA: 2025-01-13
 * AUTOR: Sistema de Notificaciones APEX
 *
 * DESCRIPCIÓN:
 *   Función mejorada para enviar correos electrónicos con soporte para archivos
 *   adjuntos desde la tabla ADM_ARCHIVO. Incluye validación de tamaño de archivos
 *   (límite 5MB por archivo) y manejo de placeholders JSON para personalización.
 *
 * CAMBIOS EN V2.0:
 *   - Eliminado parámetro p_adjuntar_archivos (BOOLEAN)
 *   - Agregado parámetro p_ids_archivos (VARCHAR2) para IDs separados por comas
 *   - Implementada validación de tamaño de archivos (5MB límite)
 *   - Omisión automática de archivos que excedan el límite
 *   - Mensajes de advertencia para archivos omitidos
 *
 * RETORNO:
 *   NUMBER - ID de la notificación creada en ADM_NOTIFICACION
 *
 * CÓDIGOS DE ERROR:
 *   -20001: Código de plantilla es obligatorio
 *   -20002: Destinatario es obligatorio
 *   -20003: Formato de email inválido
 *   -20004: Plantilla no encontrada o inactiva
 *   -20005: Error al parsear JSON de placeholders
 *   -20006: Error al enviar correo
 *   -20007: Error general inesperado
 ******************************************************************************/

CREATE OR REPLACE FUNCTION FN_ENVIAR_NOTIFICACION (
    p_codigo_plantilla VARCHAR2,
    p_destinatario     VARCHAR2,
    p_con_copia        VARCHAR2 DEFAULT NULL,
    p_id_persona       NUMBER   DEFAULT NULL,
    p_placeholders     CLOB     DEFAULT NULL,
    p_ids_archivos     VARCHAR2 DEFAULT NULL
) RETURN NUMBER
IS
    -- Variables para la plantilla y el correo
    v_id_plantilla       NUMBER;
    v_asunto             VARCHAR2(500);
    v_cuerpo_html        CLOB;
    v_email_remitente    VARCHAR2(255);
    v_id_notificacion    NUMBER;
    v_mail_id            NUMBER;

    -- Variables para manejo de placeholders JSON
    v_keys               APEX_T_VARCHAR2;
    v_key                VARCHAR2(4000);
    v_value              VARCHAR2(4000);

    -- Variables para control de adjuntos
    v_total_archivos     NUMBER := 0;
    v_archivos_omitidos  NUMBER := 0;
    v_lista_omitidos     VARCHAR2(4000) := '';
    v_tamano_mb          NUMBER;
    v_limite_bytes       CONSTANT NUMBER := 5 * 1024 * 1024; -- 5 MB

    -- Cursor para obtener archivos según los IDs proporcionados
    CURSOR c_archivos IS
        SELECT
            a.ID_ARCHIVO,
            a.ARCHIVO,
            a.NOMBRE_CARGUE_USUARIO,
            a.MIME_TYPE,
            DBMS_LOB.GETLENGTH(a.ARCHIVO) AS TAMANO_BYTES
        FROM ADM_ARCHIVO a
        WHERE a.ID_ARCHIVO IN (
            SELECT TO_NUMBER(TRIM(REGEXP_SUBSTR(p_ids_archivos, '[^,]+', 1, LEVEL)))
            FROM DUAL
            CONNECT BY LEVEL <= REGEXP_COUNT(p_ids_archivos, ',') + 1
        )
        AND a.ARCHIVO IS NOT NULL
        ORDER BY a.ID_ARCHIVO;

BEGIN
    -- =========================================================================
    -- 1. VALIDACIÓN DE PARÁMETROS OBLIGATORIOS
    -- =========================================================================

    IF p_codigo_plantilla IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'El código de plantilla es obligatorio');
    END IF;

    IF p_destinatario IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'El destinatario es obligatorio');
    END IF;

    -- Validar formato de email del destinatario
    IF NOT REGEXP_LIKE(p_destinatario, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
        RAISE_APPLICATION_ERROR(-20003, 'Formato de email inválido: ' || p_destinatario);
    END IF;

    -- =========================================================================
    -- 2. OBTENER PLANTILLA DE NOTIFICACIÓN
    -- =========================================================================

    BEGIN
        SELECT
            ID_PLANTILLA,
            ASUNTO,
            CUERPO_HTML
        INTO
            v_id_plantilla,
            v_asunto,
            v_cuerpo_html
        FROM ADM_PLANT_NOTIF
        WHERE CODIGO = p_codigo_plantilla
          AND ACTIVO = 'S'
          AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004,
                'Plantilla no encontrada o inactiva: ' || p_codigo_plantilla);
    END;

    -- =========================================================================
    -- 3. PROCESAR PLACEHOLDERS JSON (SI EXISTEN)
    -- =========================================================================

    IF p_placeholders IS NOT NULL THEN
        BEGIN
            -- Parsear el JSON de placeholders
            APEX_JSON.PARSE(p_placeholders);

            -- Obtener todas las claves del objeto JSON
            v_keys := APEX_JSON.GET_MEMBERS(p_path => '');

            -- Reemplazar cada placeholder en el asunto y cuerpo
            FOR i IN 1..v_keys.COUNT LOOP
                v_key := v_keys(i);
                -- IMPORTANTE: Usar el path sin punto inicial
                v_value := APEX_JSON.GET_VARCHAR2(p_path => v_key);

                -- Reemplazar en asunto
                v_asunto := REPLACE(v_asunto, '{' || v_key || '}', v_value);

                -- Reemplazar en cuerpo HTML
                v_cuerpo_html := REPLACE(v_cuerpo_html, '{' || v_key || '}', v_value);
            END LOOP;

        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20005,
                    'Error al parsear JSON de placeholders: ' || SQLERRM);
        END;
    END IF;

    -- =========================================================================
    -- 4. OBTENER EMAIL REMITENTE DE CONFIGURACIÓN
    -- =========================================================================

    BEGIN
        SELECT PREFERENCE_VALUE
        INTO v_email_remitente
        FROM ADM_CUST_PREFERENCE
        WHERE PREFERENCE_NAME = 'EMAIL_EMISOR'
          AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Valor por defecto si no existe la configuración
            v_email_remitente := 'noreply@aerocivil.gov.co';
    END;

    -- =========================================================================
    -- 5. INSERTAR REGISTRO EN ADM_NOTIFICACION (ESTADO PENDIENTE)
    -- =========================================================================

    INSERT INTO ADM_NOTIFICACION (
        REMITENTE,
        DESTINATARIO,
        ASUNTO,
        CUERPO_CORREO,
        ID_ESTADO,
        FECHA_REGISTRO
    ) VALUES (
        v_email_remitente,
        p_destinatario,
        v_asunto,
        SUBSTR(v_cuerpo_html, 1, 2000), -- Limitado a 2000 caracteres
        3, -- Estado: Pendiente
        SYSDATE
    ) RETURNING ID_NOTIFICACION INTO v_id_notificacion;

    -- =========================================================================
    -- 6. ENVIAR CORREO CON APEX_MAIL
    -- =========================================================================

    BEGIN
        v_mail_id := APEX_MAIL.SEND(
            p_from        => v_email_remitente,
            p_to          => p_destinatario,
            p_cc          => p_con_copia,
            p_subj        => v_asunto,
            p_body        => 'Este correo requiere un cliente que soporte HTML.',
            p_body_html   => v_cuerpo_html
        );

        -- =====================================================================
        -- 7. PROCESAR ARCHIVOS ADJUNTOS (SI EXISTEN)
        -- =====================================================================

        IF p_ids_archivos IS NOT NULL THEN

            FOR r_archivo IN c_archivos LOOP
                v_total_archivos := v_total_archivos + 1;

                -- Verificar si el archivo excede el límite de 5MB
                IF r_archivo.TAMANO_BYTES > v_limite_bytes THEN
                    -- Archivo excede el límite - omitirlo
                    v_archivos_omitidos := v_archivos_omitidos + 1;

                    -- Calcular tamaño en MB para el mensaje
                    v_tamano_mb := ROUND(r_archivo.TAMANO_BYTES / (1024 * 1024), 1);

                    -- Agregar a la lista de omitidos
                    IF v_lista_omitidos IS NOT NULL THEN
                        v_lista_omitidos := v_lista_omitidos || ', ';
                    END IF;
                    v_lista_omitidos := v_lista_omitidos ||
                                      r_archivo.NOMBRE_CARGUE_USUARIO ||
                                      ' (' || v_tamano_mb || ' MB)';

                ELSE
                    -- Archivo válido - adjuntar al correo
                    BEGIN
                        APEX_MAIL.ADD_ATTACHMENT(
                            p_mail_id    => v_mail_id,
                            p_attachment => r_archivo.ARCHIVO,
                            p_filename   => r_archivo.NOMBRE_CARGUE_USUARIO,
                            p_mime_type  => r_archivo.MIME_TYPE
                        );
                    EXCEPTION
                        WHEN OTHERS THEN
                            -- Registrar error pero continuar con otros archivos
                            DBMS_OUTPUT.PUT_LINE('Error al adjuntar archivo ' ||
                                               r_archivo.ID_ARCHIVO || ': ' || SQLERRM);
                    END;
                END IF;

            END LOOP;

        END IF;

        -- =====================================================================
        -- 8. EJECUTAR COLA DE CORREOS
        -- =====================================================================

        APEX_MAIL.PUSH_QUEUE;

        -- =====================================================================
        -- 9. ACTUALIZAR ESTADO DE NOTIFICACIÓN A ENVIADO
        -- =====================================================================

        UPDATE ADM_NOTIFICACION
        SET ID_ESTADO = 1, -- Estado: Enviado
            FECHA_ENVIO = SYSDATE
        WHERE ID_NOTIFICACION = v_id_notificacion;

        -- =====================================================================
        -- 10. GENERAR ADVERTENCIA SI HAY ARCHIVOS OMITIDOS
        -- =====================================================================

        IF v_archivos_omitidos > 0 THEN
            APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE :=
                'Correo enviado correctamente, pero ' || v_archivos_omitidos ||
                ' archivo(s) fueron omitidos por exceder 5MB: ' || v_lista_omitidos;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- Error al enviar correo - actualizar estado a Suspendido
            UPDATE ADM_NOTIFICACION
            SET ID_ESTADO = 4, -- Estado: Suspendido
                OBSERVACION = 'Error al enviar: ' || SUBSTR(SQLERRM, 1, 500)
            WHERE ID_NOTIFICACION = v_id_notificacion;

            RAISE_APPLICATION_ERROR(-20006,
                'Error al enviar correo: ' || SQLERRM);
    END;

    -- Confirmar transacción
    COMMIT;

    -- Retornar ID de la notificación creada
    RETURN v_id_notificacion;

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback en caso de cualquier error
        ROLLBACK;

        -- Si no es un error controlado, generar error genérico
        IF SQLCODE NOT BETWEEN -20007 AND -20001 THEN
            RAISE_APPLICATION_ERROR(-20007,
                'Error inesperado en FN_ENVIAR_NOTIFICACION: ' || SQLERRM);
        ELSE
            RAISE;
        END IF;

END FN_ENVIAR_NOTIFICACION;
/

-- Mostrar errores de compilación si existen
SHOW ERRORS FUNCTION FN_ENVIAR_NOTIFICACION;

-- Conceder permisos de ejecución (ajustar según tus necesidades)
-- GRANT EXECUTE ON FN_ENVIAR_NOTIFICACION TO APEX_PUBLIC_USER;
