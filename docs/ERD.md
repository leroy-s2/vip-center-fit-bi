# ERD — Esquema BI_VIP_CENTER_FIT

> Generado automáticamente por `scripts/erd.mjs` desde `prisma/schema.prisma`.
> Modelos: 12. `PK` = clave primaria, `UK` = clave única.
>
> **Arquitectura: Data Warehouse en constelación.** El modelo tiene 3 data mart por área
> de negocio, cada uno una **estrella**, que **comparten las dimensiones conformadas** del
> Las relaciones provienen de las **FOREIGN KEY** declaradas en el DW.

## Vista general (constelación)

```mermaid
erDiagram
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
    string codigo_empleado UK
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
    string tipo_plan
    string tipo_operacion
    string promocion
  }
  FactVentas {
    bigint sk_venta PK
    int id_pago_bk UK
    int sk_fecha_pago
    int sk_cliente
    int sk_plan
    int sk_empleado
    int id_membresia_bk
    decimal monto_neto
    decimal descuento_aplicado
    decimal precio_lista
    string metodo_pago
  }
  FactMembresias {
    bigint sk_membresia PK
    int id_membresia_bk
    int sk_fecha_corte
    int sk_cliente
    int sk_plan
    int sk_empleado
    int sk_fecha_inicio
    int sk_fecha_fin
    int duracion_dias
    decimal precio_final
    string estado_membresia
    int dias_desde_vencimiento
    boolean es_renovacion
    int id_membresia_anterior_bk
    int id_membresia_nueva_bk
    int sk_fecha_renovacion
    int dias_anticipacion_renovacion
    decimal monto_renovacion
    boolean aviso_emitido
    int sk_fecha_aviso
    int dias_antes_vencimiento
    string medio_aviso
    string estado_aviso
    int avisos_emitidos_dia
  }
  FactAsistencias {
    bigint sk_asistencia PK
    int id_asistencia_bk UK
    int sk_fecha_asistencia
    int sk_cliente
    int sk_plan
    int sk_empleado
    int hora_ingreso
    int cantidad_asistencias
    boolean es_acceso_valido
  }
  FactSesionesEntrenamiento {
    bigint sk_sesion PK
    int id_sesion_bk UK
    int sk_fecha_programada
    int sk_cliente
    int sk_plan
    int sk_empleado
    string tipo_sesion
    int hora_programada
    string estado_sesion
    boolean asistio
    int duracion_minutos
    int sk_fecha_cancelacion
    string motivo_cancelacion
  }
  FactSeguimientoFisico {
    bigint sk_seguimiento PK
    int id_objetivo_bk
    int sk_cliente
    int sk_empleado
    int sk_fecha_corte
    int sk_fecha_inicio
    int sk_fecha_meta
    int id_evaluacion_bk
    int id_evaluacion_programada_bk
    string tipo_objetivo
    string unidad_medida
    string estado_objetivo
    decimal valor_inicial
    decimal valor_actual
    decimal valor_esperado
    decimal avance_alcanzado
    decimal avance_esperado
    decimal porcentaje_progreso
    decimal peso
    decimal altura
    decimal grasa_corporal
    decimal masa_muscular
    boolean evaluacion_exigible
    boolean evaluacion_completada
    boolean evaluacion_pendiente
    string estado_evaluacion
  }
  FactReclamos {
    bigint sk_reclamo PK
    int id_reclamo_bk UK
    int sk_fecha_reclamo
    int sk_cliente
    int sk_empleado
    string categoria
    string estado
    int sk_fecha_resolucion
    int sk_fecha_cierre
    int dias_resolucion
    boolean resuelto_en_mostrador
    boolean escalado
    string area_responsable
  }
  FactRetenciones {
    bigint sk_retencion PK
    int id_retencion_bk UK
    int sk_fecha_retencion
    int sk_cliente
    int sk_empleado
    int id_membresia_bk
    int sk_fecha_vencimiento
    string canal
    string motivo
    string resultado
    boolean recuperada
    decimal monto_oferta
  }
  etl_control {
    string proceso PK
    bigint ultimo_staging_id
    datetime ultima_carga
    bigint filas_ultima_carga
  }
  FactVentas }o--|| DimCliente : "sk_cliente"
  FactVentas }o--|| DimEmpleado : "sk_empleado"
  FactVentas }o--|| DimFecha : "sk_fecha_pago"
  FactVentas }o--|| DimPlan : "sk_plan"
  FactMembresias }o--|| DimCliente : "sk_cliente"
  FactMembresias }o--|| DimEmpleado : "sk_empleado"
  FactMembresias }o--|| DimFecha : "sk_fecha_aviso"
  FactMembresias }o--|| DimFecha : "sk_fecha_corte"
  FactMembresias }o--|| DimFecha : "sk_fecha_fin"
  FactMembresias }o--|| DimFecha : "sk_fecha_inicio"
  FactMembresias }o--|| DimFecha : "sk_fecha_renovacion"
  FactMembresias }o--|| DimPlan : "sk_plan"
  FactAsistencias }o--|| DimCliente : "sk_cliente"
  FactAsistencias }o--|| DimEmpleado : "sk_empleado"
  FactAsistencias }o--|| DimFecha : "sk_fecha_asistencia"
  FactAsistencias }o--|| DimPlan : "sk_plan"
  FactSesionesEntrenamiento }o--|| DimCliente : "sk_cliente"
  FactSesionesEntrenamiento }o--|| DimEmpleado : "sk_empleado"
  FactSesionesEntrenamiento }o--|| DimFecha : "sk_fecha_programada"
  FactSesionesEntrenamiento }o--|| DimFecha : "sk_fecha_cancelacion"
  FactSesionesEntrenamiento }o--|| DimPlan : "sk_plan"
  FactSeguimientoFisico }o--|| DimCliente : "sk_cliente"
  FactSeguimientoFisico }o--|| DimEmpleado : "sk_empleado"
  FactSeguimientoFisico }o--|| DimFecha : "sk_fecha_corte"
  FactSeguimientoFisico }o--|| DimFecha : "sk_fecha_inicio"
  FactSeguimientoFisico }o--|| DimFecha : "sk_fecha_meta"
  FactReclamos }o--|| DimCliente : "sk_cliente"
  FactReclamos }o--|| DimEmpleado : "sk_empleado"
  FactReclamos }o--|| DimFecha : "sk_fecha_reclamo"
  FactReclamos }o--|| DimFecha : "sk_fecha_cierre"
  FactReclamos }o--|| DimFecha : "sk_fecha_resolucion"
  FactRetenciones }o--|| DimCliente : "sk_cliente"
  FactRetenciones }o--|| DimEmpleado : "sk_empleado"
  FactRetenciones }o--|| DimFecha : "sk_fecha_retencion"
  FactRetenciones }o--|| DimFecha : "sk_fecha_vencimiento"
```

## Data Mart: Atención y reclamos

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
    int sk_fecha_resolucion
    int sk_fecha_cierre
    int dias_resolucion
    boolean resuelto_en_mostrador
    boolean escalado
    string area_responsable
  }
  FactRetenciones {
    bigint sk_retencion PK
    int id_retencion_bk UK
    int sk_fecha_retencion
    int sk_cliente
    int sk_empleado
    int id_membresia_bk
    int sk_fecha_vencimiento
    string canal
    string motivo
    string resultado
    boolean recuperada
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
    string codigo_empleado UK
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
  FactReclamos }o--|| DimFecha : "sk_fecha_cierre"
  FactReclamos }o--|| DimFecha : "sk_fecha_resolucion"
  FactRetenciones }o--|| DimCliente : "sk_cliente"
  FactRetenciones }o--|| DimEmpleado : "sk_empleado"
  FactRetenciones }o--|| DimFecha : "sk_fecha_retencion"
  FactRetenciones }o--|| DimFecha : "sk_fecha_vencimiento"
```

## Data Mart: Comercial — ventas y membresías

`esquema: dm_comercial`

```mermaid
erDiagram
  FactVentas {
    bigint sk_venta PK
    int id_pago_bk UK
    int sk_fecha_pago
    int sk_cliente
    int sk_plan
    int sk_empleado
    int id_membresia_bk
    decimal monto_neto
    decimal descuento_aplicado
    decimal precio_lista
    string metodo_pago
  }
  FactMembresias {
    bigint sk_membresia PK
    int id_membresia_bk
    int sk_fecha_corte
    int sk_cliente
    int sk_plan
    int sk_empleado
    int sk_fecha_inicio
    int sk_fecha_fin
    int duracion_dias
    decimal precio_final
    string estado_membresia
    int dias_desde_vencimiento
    boolean es_renovacion
    int id_membresia_anterior_bk
    int id_membresia_nueva_bk
    int sk_fecha_renovacion
    int dias_anticipacion_renovacion
    decimal monto_renovacion
    boolean aviso_emitido
    int sk_fecha_aviso
    int dias_antes_vencimiento
    string medio_aviso
    string estado_aviso
    int avisos_emitidos_dia
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
    string codigo_empleado UK
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
    string tipo_plan
    string tipo_operacion
    string promocion
  }
  FactVentas }o--|| DimCliente : "sk_cliente"
  FactVentas }o--|| DimEmpleado : "sk_empleado"
  FactVentas }o--|| DimFecha : "sk_fecha_pago"
  FactVentas }o--|| DimPlan : "sk_plan"
  FactMembresias }o--|| DimCliente : "sk_cliente"
  FactMembresias }o--|| DimEmpleado : "sk_empleado"
  FactMembresias }o--|| DimFecha : "sk_fecha_aviso"
  FactMembresias }o--|| DimFecha : "sk_fecha_corte"
  FactMembresias }o--|| DimFecha : "sk_fecha_fin"
  FactMembresias }o--|| DimFecha : "sk_fecha_inicio"
  FactMembresias }o--|| DimFecha : "sk_fecha_renovacion"
  FactMembresias }o--|| DimPlan : "sk_plan"
```

## Data Mart: Entrenamiento

`esquema: dm_entrenamiento`

```mermaid
erDiagram
  FactAsistencias {
    bigint sk_asistencia PK
    int id_asistencia_bk UK
    int sk_fecha_asistencia
    int sk_cliente
    int sk_plan
    int sk_empleado
    int hora_ingreso
    int cantidad_asistencias
    boolean es_acceso_valido
  }
  FactSesionesEntrenamiento {
    bigint sk_sesion PK
    int id_sesion_bk UK
    int sk_fecha_programada
    int sk_cliente
    int sk_plan
    int sk_empleado
    string tipo_sesion
    int hora_programada
    string estado_sesion
    boolean asistio
    int duracion_minutos
    int sk_fecha_cancelacion
    string motivo_cancelacion
  }
  FactSeguimientoFisico {
    bigint sk_seguimiento PK
    int id_objetivo_bk
    int sk_cliente
    int sk_empleado
    int sk_fecha_corte
    int sk_fecha_inicio
    int sk_fecha_meta
    int id_evaluacion_bk
    int id_evaluacion_programada_bk
    string tipo_objetivo
    string unidad_medida
    string estado_objetivo
    decimal valor_inicial
    decimal valor_actual
    decimal valor_esperado
    decimal avance_alcanzado
    decimal avance_esperado
    decimal porcentaje_progreso
    decimal peso
    decimal altura
    decimal grasa_corporal
    decimal masa_muscular
    boolean evaluacion_exigible
    boolean evaluacion_completada
    boolean evaluacion_pendiente
    string estado_evaluacion
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
    string codigo_empleado UK
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
    string tipo_plan
    string tipo_operacion
    string promocion
  }
  FactAsistencias }o--|| DimCliente : "sk_cliente"
  FactAsistencias }o--|| DimEmpleado : "sk_empleado"
  FactAsistencias }o--|| DimFecha : "sk_fecha_asistencia"
  FactAsistencias }o--|| DimPlan : "sk_plan"
  FactSesionesEntrenamiento }o--|| DimCliente : "sk_cliente"
  FactSesionesEntrenamiento }o--|| DimEmpleado : "sk_empleado"
  FactSesionesEntrenamiento }o--|| DimFecha : "sk_fecha_programada"
  FactSesionesEntrenamiento }o--|| DimFecha : "sk_fecha_cancelacion"
  FactSesionesEntrenamiento }o--|| DimPlan : "sk_plan"
  FactSeguimientoFisico }o--|| DimCliente : "sk_cliente"
  FactSeguimientoFisico }o--|| DimEmpleado : "sk_empleado"
  FactSeguimientoFisico }o--|| DimFecha : "sk_fecha_corte"
  FactSeguimientoFisico }o--|| DimFecha : "sk_fecha_inicio"
  FactSeguimientoFisico }o--|| DimFecha : "sk_fecha_meta"
```

## Matriz bus (hecho → dimensiones conformadas)

| Data mart | Hecho | Dimensiones |
| --- | --- | --- |
| Atención y reclamos | FactReclamos | DimCliente, DimEmpleado, DimFecha |
| Atención y reclamos | FactRetenciones | DimCliente, DimEmpleado, DimFecha |
| Comercial — ventas y membresías | FactVentas | DimCliente, DimEmpleado, DimFecha, DimPlan |
| Comercial — ventas y membresías | FactMembresias | DimCliente, DimEmpleado, DimFecha, DimPlan |
| Entrenamiento | FactAsistencias | DimCliente, DimEmpleado, DimFecha, DimPlan |
| Entrenamiento | FactSesionesEntrenamiento | DimCliente, DimEmpleado, DimFecha, DimPlan |
| Entrenamiento | FactSeguimientoFisico | DimCliente, DimEmpleado, DimFecha |

