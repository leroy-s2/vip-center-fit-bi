# JMeter — simulación de la web del gimnasio

Los planes golpean la API como si fuera la web operativa:
**JMeter → API (POST) → ORIGEN**, y el CDC + ETL lo llevan al Data Warehouse cada 10 minutos.

## 1. Generar los datasets (seeder determinista)

```bash
dotnet run --project src/VipCenterFit.Seeder -c Release -- --seed 1234 --clientes 200 --out jmeter/data
```

Genera `jmeter/data/*.csv` reproducibles (mismo `--seed` ⇒ mismos datos). Los encabezados
coinciden con los campos que espera la API.

## 2. Ejecutar los planes

```bash
# Requiere la API levantada (dotnet run --project src/VipCenterFit.Api  ó  docker compose up api)
jmeter -n -t jmeter/escritura-oltp.jmx -l resultados/escritura.jtl -e -o resultados/escritura-html
jmeter -n -t jmeter/lectura-kpis.jmx   -l resultados/lectura.jtl   -e -o resultados/lectura-html
```

- `escritura-oltp.jmx`: POST de clientes, membresías, ventas, asistencias y reclamos (payloads desde CSV).
- `lectura-kpis.jmx`: GET de KPIs (REST) y OData.

## 3. Ver el efecto

Las escrituras quedan en `ORIGEN`; en la siguiente corrida del job `VIPFIT_ETL_10min`
(o forzándolo a mano) se reflejan en el DW:

```bash
docker exec vipfit-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
  -Q "EXEC BI_VIP_CENTER_FIT_STG.dbo.usp_Ingesta_CDC; EXEC BI_VIP_CENTER_FIT_DW.dbo.usp_Transformar_CargarDataMart;"
```

> `-n` = modo sin interfaz. Si querés simular "escrituras en cualquier momento", corré el plan
> de escritura repetidamente con distinto `--seed` (datos nuevos) y deja que el job de 10 min
> procese por lotes.
