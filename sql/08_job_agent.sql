/*=============================================================================
  VIP CENTER FIT - JOB DEL PIPELINE BI (SQL Server Agent)

  Crea (o recrea) el job "VIPFIT_ETL_10min" que cada 10 minutos ejecuta:

      Paso 1  BI_VIP_CENTER_FIT_STG.dbo.usp_Ingesta_CDC
              Toma los cambios de CDC desde la última marca de agua (LSN) y los
              deja en las tablas stg.* (incremental).

      Paso 2  BI_VIP_CENTER_FIT_DW.dbo.usp_Transformar_CargarDataMart
              Procesa SÓLO las filas nuevas del staging y hace MERGE en el Data
              Mart (incremental por StagingID).

  Requisito: SQL Server Agent habilitado y en ejecución. El propio capture job
  de CDC (que llena las tablas cdc.*_CT) también depende de Agent. Para
  habilitarlo en el contenedor:

      docker exec -u root vipfit-mssql /opt/mssql/bin/mssql-conf set sqlagent.enabled true
      docker restart vipfit-mssql

  El script es idempotente: si el job o el calendario ya existen, se eliminan y
  se vuelven a crear.
=============================================================================*/

USE msdb;
GO

/* Idempotencia: se eliminan job y calendario previos si existen. */
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'VIPFIT_ETL_10min')
    EXEC msdb.dbo.sp_delete_job @job_name = N'VIPFIT_ETL_10min', @delete_unused_schedule = 1;
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = N'VIPFIT_Cada10Min')
    EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'VIPFIT_Cada10Min';
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'VIPFIT_ETL_10min',
    @enabled = 1,
    @description = N'Pipeline BI VIP Center Fit: ingesta CDC + ETL incremental al Data Mart, cada 10 minutos.';
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'VIPFIT_ETL_10min',
    @step_id = 1,
    @step_name = N'1. Ingesta CDC -> Staging',
    @subsystem = N'TSQL',
    @database_name = N'BI_VIP_CENTER_FIT_STG',
    @command = N'EXEC dbo.usp_Ingesta_CDC;',
    @on_success_action = 3,   -- continuar con el paso siguiente
    @on_fail_action = 2;      -- terminar con error
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'VIPFIT_ETL_10min',
    @step_id = 2,
    @step_name = N'2. ETL incremental -> Data Mart',
    @subsystem = N'TSQL',
    @database_name = N'BI_VIP_CENTER_FIT_DW',
    @command = N'EXEC dbo.usp_Transformar_CargarDataMart;',
    @on_success_action = 1,   -- terminar con éxito
    @on_fail_action = 2;      -- terminar con error
GO

/* Cada 10 minutos, todos los días: freq_type=4 (diario),
   freq_subday_type=4 (minutos), freq_subday_interval=10. */
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'VIPFIT_Cada10Min',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 10,
    @active_start_time = 0;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'VIPFIT_ETL_10min',
    @schedule_name = N'VIPFIT_Cada10Min';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'VIPFIT_ETL_10min',
    @server_name = N'(LOCAL)';
GO

/* Verificación. */
SELECT
    j.name AS Job,
    j.enabled AS Habilitado,
    s.name AS Calendario,
    s.freq_subday_interval AS CadaMinutos,
    s.active_start_time,
    c.step_name AS Paso
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobschedules js ON js.job_id = j.job_id
LEFT JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id
LEFT JOIN msdb.dbo.sysjobsteps c ON c.job_id = j.job_id
WHERE j.name = N'VIPFIT_ETL_10min'
ORDER BY c.step_id;
GO
