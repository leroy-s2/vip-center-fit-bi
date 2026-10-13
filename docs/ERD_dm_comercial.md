# ERD — Data Mart: dm_comercial

> Generado automáticamente por `scripts/erd.mjs` desde `prisma/schema.dm_comercial.prisma`.
> Modelos: 9. `PK` = clave primaria, `UK` = clave única.
>
> **Data Mart `dm_comercial`**: una **estrella** (sus hechos) más las
> **dimensiones conformadas** del esquema `dim` que comparte con el resto de la constelación.
> Las relaciones provienen de las **FOREIGN KEY** declaradas en el DW.

## Estrella: Comercial — ventas y membresías

`esquema: dm_comercial`

```mermaid
erDiagram
  FactAvisos {
    bigint sk_aviso PK
    int id_aviso_bk UK
    int sk_fecha_aviso
    int sk_cliente
    int sk_empleado
    int id_membresia_bk
    int dias_antes_vencimiento
    string medio
    string estado
  }
  FactMembresias {
    bigint sk_membresia PK
    int id_membresia_bk UK
    int sk_cliente
    int sk_plan
    int sk_promocion
    int sk_empleado
    int sk_fecha_inicio
    int sk_fecha_fin
    int duracion_dias
    decimal precio_final
    boolean es_renovacion
    string estado_membresia
    int dias_anticipacion_renovacion
  }
  FactRenovaciones {
    bigint sk_renovacion PK
    int id_renovacion_bk UK
    int sk_fecha_renovacion
    int sk_cliente
    int sk_empleado
    int id_membresia_anterior_bk
    int id_membresia_nueva_bk
    int dias_anticipacion
    decimal monto
  }
  FactVentas {
    bigint sk_venta PK
    int id_pago_bk UK
    int sk_fecha_pago
    int sk_cliente
    int sk_plan
    int sk_promocion
    int sk_empleado
    int id_membresia_bk
    decimal monto_neto
    decimal descuento_aplicado
    decimal precio_lista
    string metodo_pago
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
  DimPlan {
    int sk_plan PK
    int sk_plan_origen
    int id_plan_bk UK
    string nombre_plan
    int duracion_dias
    decimal precio_referencial
    string categoria_duracion
  }
  DimPromocion {
    int sk_promocion PK
    int sk_promocion_origen
    int id_promocion_bk UK
    string nombre_promocion
    string tipo_descuento
    decimal valor_descuento
  }
  FactAvisos }o--|| DimCliente : "sk_cliente"
  FactAvisos }o--|| DimEmpleado : "sk_empleado"
  FactAvisos }o--|| DimFecha : "sk_fecha_aviso"
  FactMembresias }o--|| DimCliente : "sk_cliente"
  FactMembresias }o--|| DimEmpleado : "sk_empleado"
  FactMembresias }o--|| DimFecha : "sk_fecha_fin"
  FactMembresias }o--|| DimFecha : "sk_fecha_inicio"
  FactMembresias }o--|| DimPlan : "sk_plan"
  FactMembresias }o--|| DimPromocion : "sk_promocion"
  FactRenovaciones }o--|| DimCliente : "sk_cliente"
  FactRenovaciones }o--|| DimEmpleado : "sk_empleado"
  FactRenovaciones }o--|| DimFecha : "sk_fecha_renovacion"
  FactVentas }o--|| DimCliente : "sk_cliente"
  FactVentas }o--|| DimEmpleado : "sk_empleado"
  FactVentas }o--|| DimFecha : "sk_fecha_pago"
  FactVentas }o--|| DimPlan : "sk_plan"
  FactVentas }o--|| DimPromocion : "sk_promocion"
```

## Matriz bus (hecho → dimensiones conformadas)

| Data mart | Hecho | Dimensiones |
| --- | --- | --- |
| Comercial — ventas y membresías | FactAvisos | DimCliente, DimEmpleado, DimFecha |
| Comercial — ventas y membresías | FactMembresias | DimCliente, DimEmpleado, DimFecha, DimPlan, DimPromocion |
| Comercial — ventas y membresías | FactRenovaciones | DimCliente, DimEmpleado, DimFecha |
| Comercial — ventas y membresías | FactVentas | DimCliente, DimEmpleado, DimFecha, DimPlan, DimPromocion |

