# Operación — VIP Center Fit BI

## Arranque

```bash
npm run db:bootstrap      # levanta SQL Server, habilita Agent, reconstruye todo y crea el job
dotnet run --project src/VipCenterFit.Api        # API en http://localhost:5080
# o:
docker compose up -d --build                     # mssql + api
```

## SQL Server Agent y el job

- **Requisito de CDC**: SQL Server Agent debe estar activo (el *capture job* llena `cdc.*_CT`).
  El bootstrap lo habilita y reinicia el contenedor si hace falta:
  ```bash
  docker exec -u root vipfit-mssql /opt/mssql/bin/mssql-conf set sqlagent.enabled true
  docker restart vipfit-mssql
  ```
- **Job** `VIPFIT_ETL_10min` (cada 10 min): `usp_Ingesta_CDC` + `usp_Transformar_CargarDataMart`.
  - Forzarlo: `EXEC msdb.dbo.sp_start_job N'VIPFIT_ETL_10min';`
  - Historial: `SELECT * FROM msdb.dbo.sysjobhistory ORDER BY instance_id DESC;`
- **Estado**: `GET /api/v1/etl/estado` (LSN CDC + marcas de agua del ETL).

## Backups

```bash
docker exec vipfit-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -i /sql/11_backup.sql
```
Genera `ORIGEN_*.bak`, `STG_*.bak`, `DW_*.bak` en `/var/opt/mssql/backup` (volumen `mssql_data`).
En Azure SQL los backups son automáticos (retención configurable).

## Seguridad

| Login | Permiso | Uso |
| --- | --- | --- |
| `api_writer` | DML en `dbo` de ORIGEN | la API en producción |
| `etl_runner` | EXECUTE + DML en STG/DW | ejecuta ingesta + ETL |
| `pbi_lector` | SELECT en `dim`, `dm_*`, vistas `dbo.DM_*` | Power BI |

- **Contraseñas**: en sandbox están en `sql/10_usuarios_permisos.sql`; en producción van en
  **Key Vault** y se inyectan por variables de entorno (`ConnectionStrings__*`).
- **TLS**: en local la API escucha HTTP; en producción terminar TLS en el reverse proxy /
  Container Apps con certificado de Key Vault (`Encrypt=True` en las cadenas).
- **API key**: si `ApiKey` está configurada, se exige el header `X-Api-Key`
  (excepto `/health`, `/swagger`, `/odata`).

## Power BI

- **SQL read-only**: servidor del DW, base `BI_VIP_CENTER_FIT_DW`, usuario `pbi_lector`.
  Para Power BI **Service on-prem** se requiere gateway de datos.
- **OData**: consumir `https://<host>/odata/DM_*` (sin gateway).

## Troubleshooting

- **Error 313 de CDC** (`insufficient number of arguments`): significa que se consultó un
  `capture_instance` con un `from_lsn` menor a su `min_lsn`. `usp_Ingesta_CDC` ya acota el
  LSN por instancia; si reaparece, verificar `cdc.change_tables.start_lsn`.
- **El ETL no procesa nada**: revisar `dbo.etl_control`; si la marca de agua quedó por
  encima del `MAX(StagingID)` del staging (p.ej. tras un `TRUNCATE` manual), reiniciarla a 0.
- **La API no conecta**: `ConnectionStrings__*` apuntan a `localhost,14330` en local y a
  `mssql,1433` dentro de docker compose.
