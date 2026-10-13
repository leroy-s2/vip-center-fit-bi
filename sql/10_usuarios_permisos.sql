/*=============================================================================
  VIP CENTER FIT - USUARIOS Y PERMISOS MÍNIMOS

  Crea tres logins con el menor privilegio necesario:

    api_writer  -> escribe en ORIGEN (lo que usa la API/JMeter)
    etl_runner  -> ejecuta la ingesta CDC y el ETL incremental
    pbi_lector  -> lee el Data Warehouse (vistas DM_*, dim y dm_*) para Power BI

  Las contraseñas son de sandbox; en producción van en Key Vault / variables
  secretas y NO se versionan. El script es idempotente.
=============================================================================*/

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'api_writer')
    CREATE LOGIN api_writer WITH PASSWORD = 'ApiWriter!2026', CHECK_POLICY = ON;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'etl_runner')
    CREATE LOGIN etl_runner WITH PASSWORD = 'EtlRunner!2026', CHECK_POLICY = ON;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'pbi_lector')
    CREATE LOGIN pbi_lector WITH PASSWORD = 'PbiReader!2026', CHECK_POLICY = ON;
GO

/* api_writer: sólo escritura (DML) en el esquema dbo de ORIGEN. */
USE BI_VIP_CENTER_FIT_DW_ORIGEN;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'api_writer')
    CREATE USER api_writer FOR LOGIN api_writer;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO api_writer;
DENY VIEW DEFINITION TO api_writer;
GO

/* etl_runner: ejecuta la ingesta CDC en STG. */
USE BI_VIP_CENTER_FIT_STG;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'etl_runner')
    CREATE USER etl_runner FOR LOGIN etl_runner;
GRANT EXECUTE ON SCHEMA::dbo TO etl_runner;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::stg TO etl_runner;
GO

/* etl_runner: ejecuta el ETL y mantiene el modelo; pbi_lector: sólo lectura. */
USE BI_VIP_CENTER_FIT_DW;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'etl_runner')
    CREATE USER etl_runner FOR LOGIN etl_runner;
GRANT EXECUTE ON SCHEMA::dbo TO etl_runner;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dim TO etl_runner;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dm_comercial TO etl_runner;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dm_entrenamiento TO etl_runner;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dm_atencion TO etl_runner;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO etl_runner;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'pbi_lector')
    CREATE USER pbi_lector FOR LOGIN pbi_lector;
GRANT SELECT ON SCHEMA::dim TO pbi_lector;
GRANT SELECT ON SCHEMA::dm_comercial TO pbi_lector;
GRANT SELECT ON SCHEMA::dm_entrenamiento TO pbi_lector;
GRANT SELECT ON SCHEMA::dm_atencion TO pbi_lector;
/* Las vistas de KPIs están en dbo (DM_*). */
GRANT SELECT ON SCHEMA::dbo TO pbi_lector;
DENY VIEW DEFINITION TO pbi_lector;
GO

/* Verificación. */
SELECT name AS Login, type_desc, is_disabled FROM sys.server_principals
WHERE name IN ('api_writer', 'etl_runner', 'pbi_lector')
ORDER BY name;
GO
