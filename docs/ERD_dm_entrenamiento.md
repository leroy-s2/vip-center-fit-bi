# ERD — Data Mart: dm_entrenamiento

> Generado automáticamente por `scripts/erd.mjs` desde `prisma/schema.dm_entrenamiento.prisma`.
> Modelos: 10. `PK` = clave primaria, `UK` = clave única.
>
> **Data Mart `dm_entrenamiento`**: una **estrella** (sus hechos) más las
> **dimensiones conformadas** del esquema `dim` que comparte con el resto de la constelación.
> Las relaciones provienen de las **FOREIGN KEY** declaradas en el DW.

## Estrella: Entrenamiento

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
  }
  FactEvaluaciones {
    bigint sk_evaluacion PK
    int id_evaluacion_bk UK
    int sk_fecha_evaluacion
    int sk_cliente
    int sk_empleado
    int id_objetivo_bk
    decimal peso
    decimal altura
    decimal grasa_corporal
    decimal masa_muscular
  }
  FactEvaluacionesProgramadas {
    bigint sk_evaluacion_programada PK
    int id_evaluacion_programada_bk UK
    int sk_fecha_programada
    int sk_cliente
    int sk_empleado
    int id_objetivo_bk
    string tipo_evaluacion
    string estado_evaluacion
    int id_evaluacion_bk
  }
  FactObjetivos {
    bigint sk_objetivo PK
    int id_objetivo_bk UK
    int sk_fecha_inicio
    int sk_cliente
    string tipo_objetivo
    decimal valor_inicial
    decimal valor_objetivo
    string unidad_medida
    string estado
  }
  FactSesionesProgramadas {
    bigint sk_sesion_programada PK
    int id_sesion_bk UK
    int sk_fecha_programada
    int sk_cliente
    int sk_plan
    int sk_empleado
    string tipo_sesion
    int hora_programada
    string estado_sesion
    int duracion_minutos
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
  FactAsistencias }o--|| DimCliente : "sk_cliente"
  FactAsistencias }o--|| DimEmpleado : "sk_empleado"
  FactAsistencias }o--|| DimFecha : "sk_fecha_asistencia"
  FactAsistencias }o--|| DimPlan : "sk_plan"
  FactEvaluaciones }o--|| DimCliente : "sk_cliente"
  FactEvaluaciones }o--|| DimEmpleado : "sk_empleado"
  FactEvaluaciones }o--|| DimFecha : "sk_fecha_evaluacion"
  FactEvaluacionesProgramadas }o--|| DimCliente : "sk_cliente"
  FactEvaluacionesProgramadas }o--|| DimEmpleado : "sk_empleado"
  FactEvaluacionesProgramadas }o--|| DimFecha : "sk_fecha_programada"
  FactObjetivos }o--|| DimCliente : "sk_cliente"
  FactObjetivos }o--|| DimFecha : "sk_fecha_inicio"
  FactSesionesProgramadas }o--|| DimCliente : "sk_cliente"
  FactSesionesProgramadas }o--|| DimEmpleado : "sk_empleado"
  FactSesionesProgramadas }o--|| DimFecha : "sk_fecha_programada"
  FactSesionesProgramadas }o--|| DimPlan : "sk_plan"
```

## Matriz bus (hecho → dimensiones conformadas)

| Data mart | Hecho | Dimensiones |
| --- | --- | --- |
| Entrenamiento | FactAsistencias | DimCliente, DimEmpleado, DimFecha, DimPlan |
| Entrenamiento | FactEvaluaciones | DimCliente, DimEmpleado, DimFecha |
| Entrenamiento | FactEvaluacionesProgramadas | DimCliente, DimEmpleado, DimFecha |
| Entrenamiento | FactObjetivos | DimCliente, DimFecha |
| Entrenamiento | FactSesionesProgramadas | DimCliente, DimEmpleado, DimFecha, DimPlan |

