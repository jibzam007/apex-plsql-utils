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



## 👥 Soporte

Para soporte técnico o reporte de issues, contactar al equipo de desarrollo del sistema APEX.

**Versión**: 2.0
**Última actualización**: 2025-01-13
