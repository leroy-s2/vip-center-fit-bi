# JMeter — simulación de la web del gimnasio

Los planes golpean la API como si fuera la web operativa:
**JMeter → API (POST) → ORIGEN**, y el CDC + ETL lo llevan al Data Warehouse cada 10 minutos.

El Data Warehouse vigente es el modelo de **7 hechos**: `FactVentas`, `FactMembresias`,
`FactAsistencias`, `FactSesionesEntrenamiento`, `FactSeguimientoFisico`, `FactReclamos` y
`FactRetenciones`. Los POST siguen escribiendo en las 15 tablas operativas de ORIGEN (el ETL es
quien consolida).

## 1. Generar los datasets (seeder determinista)

```bash
dotnet run --project src/VipCenterFit.Seeder -c Release -- --seed 1234 --clientes 200 --out jmeter/data
```

Genera 13 CSV reproducibles (mismo `--seed` ⇒ mismos datos), uno por endpoint de escritura:

`clientes`, `empleados`, `membresias`, `ventas`, `renovaciones`, `avisos`, `asistencias`,
`objetivos`, `evaluaciones`, `reclamos`, `sesiones_programadas`, `evaluaciones_programadas`,
`retenciones`.

Incluyen las columnas nuevas de la reestructuración: `codigoEmpleado`, `skFechaMeta`,
`fechaCierre`/`escalado`/`areaResponsable` y `fechaCancelacion`/`motivoCancelacion`.

## 2. Ejecutar los planes

```bash
# Requiere la API levantada (dotnet run --project src/VipCenterFit.Api  ó  docker compose up api)
jmeter -n -t jmeter/escritura-oltp.jmx -l resultados/escritura.jtl -e -o resultados/escritura-html
jmeter -n -t jmeter/lectura-kpis.jmx   -l resultados/lectura.jtl   -e -o resultados/lectura-html
```

| Plan | Qué hace |
| :--- | :--- |
| `lectura-kpis.jmx` | GET de las 14 vistas de KPI por REST, `/api/v1/etl/estado` y OData (vistas + modelo en estrella). |
| `escritura-oltp.jmx` | POST de los 13 endpoints de escritura con payloads desde CSV. |
| `vipcenterfit-vm.jmx` | Plan único con **ambos grupos** (el que se usa contra la VM). Los planes anteriores se derivan de éste. |

> El plan de la VM usa `-Jhost=<ip>` y `-Jport=5080`. Los CSV se leen desde
> `/home/leroy/JMeter/data`; ajusta las rutas de los `CSVDataSet` si corres desde otra máquina.

## 3. Ver el efecto

Las escrituras quedan en `ORIGEN`; en la siguiente corrida del job `VIPFIT_ETL_10min`
(o forzándolo a mano) se reflejan en el DW:

```bash
docker exec vipfit-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
  -Q "EXEC BI_VIP_CENTER_FIT_STG.dbo.usp_Ingesta_CDC; EXEC BI_VIP_CENTER_FIT_DW.dbo.usp_Transformar_CargarDataMart;"
```

Para verificar el modelo (granos de los snapshots, huecos en la serie y rangos de KPI):

```bash
docker exec vipfit-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -b \
  -i /sql/06_pruebas_datamart_metricas.sql
```

> `-n` = modo sin interfaz. Si querés simular "escrituras en cualquier momento", corré el plan
> de escritura repetidamente con distinto `--seed` (datos nuevos) y deja que el job de 10 min
> procese por lotes.
