# ERD — Data Mart: dm_atencion

> Generado automáticamente por `scripts/erd.mjs` desde `prisma/schema.dm_atencion.prisma`.
> Modelos: 7. `PK` = clave primaria, `UK` = clave única.
>
> **Data Mart `dm_atencion`**: una **estrella** (sus hechos) más las
> **dimensiones conformadas** del esquema `dim` que comparte con el resto de la constelación.
> Las relaciones provienen de las **FOREIGN KEY** declaradas en el DW.

## Estrella: Atención y reclamos

`esquema: dm_atencion`

```mermaid
erDiagram
  FactReclamos {
    bigint sk_reclamo PK
    int id_reclamo_bk UK
    int sk_fecha_reclamo
    int sk_cliente
    int sk_empleado
    string categoria
    string estado
    datetime fecha_resolucion
    int dias_resolucion
    boolean resuelto_en_mostrador
  }
  FactRetenciones {
    bigint sk_retencion PK
    int id_retencion_bk UK
    int sk_fecha_retencion
    int sk_cliente
    int sk_empleado
    int id_membresia_bk
    string canal
    string motivo
    string resultado
    decimal monto_oferta
  }
  DimCliente {
    int sk_cliente PK
    int sk_cliente_origen
    int id_cliente_bk UK
    string dni
    string nombre_completo
    string sexo
    string rango_etario
    string estado_cliente
    datetime fecha_registro_origen
    datetime fecha_inicio_validez
    datetime fecha_fin_validez
    boolean es_actual
  }
  DimEmpleado {
    int sk_empleado PK
    int sk_empleado_origen
    int id_empleado_bk UK
    string dni
    string nombre_completo
    string cargo
    string area
  }
  DimFecha {
    int sk_fecha PK
    datetime fecha UK
    int anio
    int trimestre
    int semestre
    int mes
    string nombre_mes
    int dia
    string dia_semana
    boolean es_fin_de_semana
  }
  FactReclamos }o--|| DimCliente : "sk_cliente"
  FactReclamos }o--|| DimEmpleado : "sk_empleado"
  FactReclamos }o--|| DimFecha : "sk_fecha_reclamo"
  FactRetenciones }o--|| DimCliente : "sk_cliente"
  FactRetenciones }o--|| DimEmpleado : "sk_empleado"
  FactRetenciones }o--|| DimFecha : "sk_fecha_retencion"
```

## Matriz bus (hecho → dimensiones conformadas)

| Data mart | Hecho | Dimensiones |
| --- | --- | --- |
| Atención y reclamos | FactReclamos | DimCliente, DimEmpleado, DimFecha |
| Atención y reclamos | FactRetenciones | DimCliente, DimEmpleado, DimFecha |

