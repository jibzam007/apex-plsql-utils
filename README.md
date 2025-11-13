# 📧 FN_ENVIAR_NOTIFICACION - Sistema de Notificaciones Oracle APEX

## 📝 Descripción

Función PL/SQL mejorada para enviar correos electrónicos con soporte para archivos adjuntos en Oracle APEX. Incluye validación automática de tamaño de archivos, manejo de placeholders JSON para personalización de contenido, y control completo del flujo de notificaciones.

### ✨ Versión 2.0 - Nuevas Características

- ✅ **Adjuntos múltiples**: Soporte para múltiples archivos desde la tabla `ADM_ARCHIVO`
- ✅ **Validación automática**: Límite de 5MB por archivo con omisión automática
- ✅ **Mensajes informativos**: Advertencias claras sobre archivos omitidos
- ✅ **Placeholders JSON**: Reemplazo dinámico de variables en plantillas
- ✅ **Manejo robusto de errores**: Códigos de error específicos y rollback automático
- ✅ **Trazabilidad completa**: Registro de todas las notificaciones en base de datos

---

## 🔧 Firma de la Función

```sql
FUNCTION FN_ENVIAR_NOTIFICACION (
    p_codigo_plantilla VARCHAR2,
    p_destinatario     VARCHAR2,
    p_con_copia        VARCHAR2 DEFAULT NULL,
    p_id_persona       NUMBER   DEFAULT NULL,
    p_placeholders     CLOB     DEFAULT NULL,
    p_ids_archivos     VARCHAR2 DEFAULT NULL
) RETURN NUMBER
```

### 📋 Parámetros

| Parámetro | Tipo | Obligatorio | Descripción |
|-----------|------|-------------|-------------|
| `p_codigo_plantilla` | VARCHAR2 | ✅ Sí | Código de la plantilla en `ADM_PLANT_NOTIF` (ej: 'BIENVENIDA', 'CONFIRMACION') |
| `p_destinatario` | VARCHAR2 | ✅ Sí | Email del destinatario. Debe tener formato válido |
| `p_con_copia` | VARCHAR2 | ❌ No | Email(s) en copia (CC). Separar múltiples con comas |
| `p_id_persona` | NUMBER | ❌ No | ID de la persona relacionada (para referencia) |
| `p_placeholders` | CLOB | ❌ No | JSON con valores para reemplazar en la plantilla. Ej: `{"NOMBRE":"Juan","CODIGO":"ABC123"}` |
| `p_ids_archivos` | VARCHAR2 | ❌ No | IDs de archivos separados por comas. Ej: `'123,456,789'` |

### 🔄 Valor de Retorno

Retorna el `ID_NOTIFICACION` (NUMBER) del registro creado en la tabla `ADM_NOTIFICACION`.

---

## 📊 Tablas Involucradas

### ADM_ARCHIVO
Almacena los archivos adjuntos.

```sql
CREATE TABLE ADM_ARCHIVO (
    ID_ARCHIVO           NUMBER(38,0) PRIMARY KEY,
    ARCHIVO              BLOB NOT NULL,
    NOMBRE_CARGUE_USUARIO VARCHAR2(150),
    MIME_TYPE            VARCHAR2(50),
    TAMANO               NUMBER(38,0)
);
```

### ADM_NOTIFICACION
Registro de todas las notificaciones enviadas.

```sql
CREATE TABLE ADM_NOTIFICACION (
    ID_NOTIFICACION NUMBER(10,0) PRIMARY KEY,
    REMITENTE       VARCHAR2(100),
    DESTINATARIO    VARCHAR2(200),
    ASUNTO          VARCHAR2(100),
    CUERPO_CORREO   VARCHAR2(2000),
    ID_ESTADO       NUMBER(38,0),
    FECHA_REGISTRO  DATE,
    FECHA_ENVIO     DATE
);
```

**Estados de notificación:**
- `1` = Enviado
- `3` = Pendiente
- `4` = Suspendido

### ADM_PLANT_NOTIF
Plantillas de correo con placeholders.

```sql
CREATE TABLE ADM_PLANT_NOTIF (
    ID_PLANTILLA NUMBER(38,0) PRIMARY KEY,
    CODIGO       VARCHAR2(20) UNIQUE,
    ASUNTO       VARCHAR2(500),
    CUERPO_HTML  CLOB,
    ACTIVO       VARCHAR2(1)
);
```

### ADM_CUST_PREFERENCE
Configuración del sistema.

```sql
CREATE TABLE ADM_CUST_PREFERENCE (
    PREFERENCE_NAME  VARCHAR2(255),
    PREFERENCE_VALUE VARCHAR2(255)
);
```

**Configuración requerida:**
```sql
INSERT INTO ADM_CUST_PREFERENCE (PREFERENCE_NAME, PREFERENCE_VALUE)
VALUES ('EMAIL_EMISOR', 'noreply@aerocivil.gov.co');
```

---

## 💡 Ejemplos de Uso

### 1️⃣ Envío Simple sin Adjuntos

```sql
DECLARE
    v_id_notif NUMBER;
BEGIN
    v_id_notif := FN_ENVIAR_NOTIFICACION(
        p_codigo_plantilla => 'BIENVENIDA',
        p_destinatario     => 'juan.perez@ejemplo.com'
    );

    DBMS_OUTPUT.PUT_LINE('Notificación enviada. ID: ' || v_id_notif);
END;
/
```

### 2️⃣ Con Placeholders JSON

```sql
DECLARE
    v_id_notif     NUMBER;
    v_placeholders CLOB;
BEGIN
    -- Construir JSON con placeholders
    v_placeholders := '{
        "NOMBRE_COMPLETO": "Juan Pérez García",
        "CODIGO_CONFIRMACION": "ABC-123-XYZ",
        "FECHA_VENCIMIENTO": "31/12/2025"
    }';

    v_id_notif := FN_ENVIAR_NOTIFICACION(
        p_codigo_plantilla => 'CONFIRMACION',
        p_destinatario     => 'juan.perez@ejemplo.com',
        p_placeholders     => v_placeholders
    );

    DBMS_OUTPUT.PUT_LINE('Notificación enviada. ID: ' || v_id_notif);
END;
/
```

### 3️⃣ Con Adjuntos Específicos

```sql
DECLARE
    v_id_notif NUMBER;
BEGIN
    -- Enviar correo con 3 archivos adjuntos
    v_id_notif := FN_ENVIAR_NOTIFICACION(
        p_codigo_plantilla => 'DOCUMENTOS',
        p_destinatario     => 'usuario@ejemplo.com',
        p_ids_archivos     => '1001,1002,1003'
    );

    DBMS_OUTPUT.PUT_LINE('Notificación enviada. ID: ' || v_id_notif);
END;
/
```

### 4️⃣ Construyendo IDs Dinámicamente

```sql
DECLARE
    v_id_notif     NUMBER;
    v_ids_archivos VARCHAR2(4000);
BEGIN
    -- Obtener IDs de archivos de una persona específica
    SELECT LISTAGG(ID_ARCHIVO, ',') WITHIN GROUP (ORDER BY ID_ARCHIVO)
    INTO v_ids_archivos
    FROM ADM_ARCHIVO
    WHERE ID_PERSONA = 5001
      AND TIPO_DOCUMENTO = 'CERTIFICADO'
      AND DBMS_LOB.GETLENGTH(ARCHIVO) <= (5 * 1024 * 1024); -- Pre-filtrar por tamaño

    -- Enviar correo con los archivos encontrados
    IF v_ids_archivos IS NOT NULL THEN
        v_id_notif := FN_ENVIAR_NOTIFICACION(
            p_codigo_plantilla => 'ENVIO_CERTIFICADOS',
            p_destinatario     => 'piloto@ejemplo.com',
            p_id_persona       => 5001,
            p_ids_archivos     => v_ids_archivos
        );

        DBMS_OUTPUT.PUT_LINE('Notificación enviada con archivos. ID: ' || v_id_notif);
    ELSE
        DBMS_OUTPUT.PUT_LINE('No se encontraron archivos válidos para enviar.');
    END IF;
END;
/
```

### 5️⃣ Uso en Proceso APEX

```sql
-- Proceso After Submit en APEX
DECLARE
    v_id_notif     NUMBER;
    v_placeholders CLOB;
BEGIN
    -- Construir JSON con items de APEX
    v_placeholders := APEX_JSON.STRINGIFY(
        APEX_JSON.TO_JSONB(
            P_VALUES => APEX_T_VARCHAR2(
                'NOMBRE_COMPLETO', :P10_NOMBRE_COMPLETO,
                'NUMERO_LICENCIA', :P10_NUMERO_LICENCIA,
                'FECHA_EXPEDICION', TO_CHAR(:P10_FECHA_EXP, 'DD/MM/YYYY')
            )
        )
    );

    v_id_notif := FN_ENVIAR_NOTIFICACION(
        p_codigo_plantilla => 'LICENCIA_APROBADA',
        p_destinatario     => :P10_EMAIL,
        p_con_copia        => 'supervisor@aerocivil.gov.co',
        p_id_persona       => :P10_ID_PERSONA,
        p_placeholders     => v_placeholders,
        p_ids_archivos     => :P10_IDS_DOCUMENTOS
    );

    -- Mostrar mensaje de éxito en APEX
    APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE :=
        'Notificación enviada correctamente. ID: ' || v_id_notif;

EXCEPTION
    WHEN OTHERS THEN
        APEX_APPLICATION.G_PRINT_ERROR_MESSAGE :=
            'Error al enviar notificación: ' || SQLERRM;
        RAISE;
END;
```

---

## ⚠️ Validaciones y Límites

### Límites de Archivos

| Concepto | Límite | Comportamiento |
|----------|--------|----------------|
| **Tamaño máximo por archivo** | 5 MB (5,242,880 bytes) | Archivos mayores se omiten automáticamente |
| **Cantidad de archivos** | Sin límite explícito | Limitado por la configuración de `apex_mail` |
| **Formato de IDs** | Números separados por comas | Ejemplo: `'100,200,300'` |

### Validaciones Automáticas

✅ **Formato de email**: Validación con expresión regular RFC 5322 básica

✅ **Plantilla activa**: Verifica que la plantilla exista y tenga `ACTIVO = 'S'`

✅ **Tamaño de archivos**: Validación automática antes de adjuntar

✅ **JSON de placeholders**: Validación de formato JSON correcto

### Mensajes de Advertencia

Si hay archivos omitidos por exceder el límite, verás un mensaje como:

```
Correo enviado correctamente, pero 2 archivo(s) fueron omitidos por exceder 5MB:
reporte_anual.pdf (7.5 MB), presentacion.pptx (6.2 MB)
```

---

## 🔍 Consultas Útiles para Debugging

### Ver Notificaciones Recientes

```sql
SELECT
    ID_NOTIFICACION,
    REMITENTE,
    DESTINATARIO,
    ASUNTO,
    CASE ID_ESTADO
        WHEN 1 THEN 'Enviado'
        WHEN 3 THEN 'Pendiente'
        WHEN 4 THEN 'Suspendido'
        ELSE 'Desconocido'
    END AS ESTADO,
    FECHA_REGISTRO,
    FECHA_ENVIO
FROM ADM_NOTIFICACION
ORDER BY FECHA_REGISTRO DESC
FETCH FIRST 20 ROWS ONLY;
```

### Verificar Tamaño de Archivos

```sql
SELECT
    ID_ARCHIVO,
    NOMBRE_CARGUE_USUARIO,
    ROUND(DBMS_LOB.GETLENGTH(ARCHIVO) / (1024 * 1024), 2) AS TAMANO_MB,
    MIME_TYPE,
    CASE
        WHEN DBMS_LOB.GETLENGTH(ARCHIVO) > (5 * 1024 * 1024)
        THEN '❌ EXCEDE LÍMITE'
        ELSE '✅ OK'
    END AS VALIDACION
FROM ADM_ARCHIVO
WHERE ARCHIVO IS NOT NULL
ORDER BY DBMS_LOB.GETLENGTH(ARCHIVO) DESC;
```

### Ver Plantillas Activas

```sql
SELECT
    CODIGO,
    ASUNTO,
    SUBSTR(CUERPO_HTML, 1, 100) AS PREVIEW_CUERPO,
    ACTIVO
FROM ADM_PLANT_NOTIF
WHERE ACTIVO = 'S'
ORDER BY CODIGO;
```

### Ver Cola de Correos APEX

```sql
SELECT
    mail_id,
    mail_to,
    mail_subject,
    mail_send_count,
    mail_send_error
FROM APEX_MAIL_QUEUE
ORDER BY mail_id DESC;
```

---

## ❌ Códigos de Error

| Código | Descripción | Solución |
|--------|-------------|----------|
| `-20001` | Código de plantilla es obligatorio | Proporcionar `p_codigo_plantilla` válido |
| `-20002` | Destinatario es obligatorio | Proporcionar `p_destinatario` válido |
| `-20003` | Formato de email inválido | Verificar formato del email (usuario@dominio.com) |
| `-20004` | Plantilla no encontrada o inactiva | Verificar que la plantilla exista y esté activa |
| `-20005` | Error al parsear JSON de placeholders | Verificar sintaxis JSON en `p_placeholders` |
| `-20006` | Error al enviar correo | Verificar configuración de `apex_mail` y ACLs |
| `-20007` | Error general inesperado | Revisar logs y configuración del sistema |

---

## ⚙️ Configuración Requerida

### 1. Configurar SMTP en APEX

```sql
-- En SQL Workshop > SQL Commands
BEGIN
    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'SMTP_HOST_ADDRESS',
        p_value     => 'smtp.tu-servidor.com'
    );

    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'SMTP_HOST_PORT',
        p_value     => '587'
    );

    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'SMTP_USERNAME',
        p_value     => 'usuario@dominio.com'
    );

    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'SMTP_PASSWORD',
        p_value     => 'tu_password'
    );

    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'SMTP_TLS_MODE',
        p_value     => 'STARTTLS'
    );

    COMMIT;
END;
/
```

### 2. Configurar ACL para Oracle

```sql
-- Permitir conexiones de red (requerido para SMTP)
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host       => 'smtp.tu-servidor.com',
        lower_port => 587,
        upper_port => 587,
        ace        => xs$ace_type(
            privilege_list => xs$name_list('connect','resolve'),
            principal_name => 'APEX_240200',  -- Ajustar según tu versión
            principal_type => xs_acl.ptype_db
        )
    );
    COMMIT;
END;
/
```

### 3. Verificar Configuración

```sql
-- Verificar parámetros SMTP
SELECT parameter, value
FROM APEX_INSTANCE_PARAMETERS
WHERE parameter LIKE 'SMTP%';

-- Probar envío simple
BEGIN
    APEX_MAIL.SEND(
        p_from => 'noreply@aerocivil.gov.co',
        p_to   => 'tu-email@ejemplo.com',
        p_subj => 'Test APEX Mail',
        p_body => 'Este es un correo de prueba.'
    );
    APEX_MAIL.PUSH_QUEUE;
    COMMIT;
END;
/
```

---

## 📚 Estructura de Plantillas

Las plantillas en `ADM_PLANT_NOTIF` pueden usar placeholders con la sintaxis `{NOMBRE_VARIABLE}`:

### Ejemplo de Plantilla

```sql
INSERT INTO ADM_PLANT_NOTIF (CODIGO, ASUNTO, CUERPO_HTML, ACTIVO)
VALUES (
    'BIENVENIDA',
    'Bienvenido {NOMBRE_COMPLETO} al Sistema',
    '<!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
    </head>
    <body style="font-family: Arial, sans-serif;">
        <h2>¡Bienvenido {NOMBRE_COMPLETO}!</h2>
        <p>Tu código de confirmación es: <strong>{CODIGO_CONFIRMACION}</strong></p>
        <p>Este código es válido hasta: {FECHA_VENCIMIENTO}</p>
        <br>
        <p>Saludos,<br>
        Aeronáutica Civil</p>
    </body>
    </html>',
    'S'
);
```

---

## 🚀 Mejores Prácticas

1. **Pre-validar archivos**: Antes de llamar la función, verifica el tamaño de los archivos
2. **Usar placeholders**: Centraliza las plantillas y usa JSON para personalización
3. **Manejo de errores**: Siempre envuelve las llamadas en bloques `BEGIN/EXCEPTION/END`
4. **Logs**: Consulta regularmente `ADM_NOTIFICACION` para auditoría
5. **Pruebas**: Usa correos de prueba antes de enviar a usuarios finales

---

## 📄 Licencia

Sistema de Notificaciones - Aeronáutica Civil de Colombia

---

## 👥 Soporte

Para soporte técnico o reporte de issues, contactar al equipo de desarrollo del sistema APEX.

**Versión**: 2.0
**Última actualización**: 2025-01-13
