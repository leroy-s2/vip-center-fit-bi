/*=============================================================================
  VIP CENTER FIT - BACKUP DE LAS 3 BASES

  Genera backups completos y comprimidos en el volumen del contenedor
  (/var/opt/mssql/backup). En Azure SQL los backups son automáticos; este script
  es para una instancia self-hosted (Docker/VM o un job de SQL Agent).

  Uso:
    docker exec vipfit-mssql /opt/mssql-tools18/bin/sqlcmd \
      -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -i /sql/11_backup.sql
=============================================================================*/

SET NOCOUNT ON;

DECLARE @dir NVARCHAR(4000) = N'/var/opt/mssql/backup';
DECLARE @ts  NVARCHAR(20)   = FORMAT(SYSUTCDATETIME(), 'yyyyMMdd_HHmmss');

/* xp_create_subdir es idempotente: no falla si el directorio ya existe. */
EXEC master.dbo.xp_create_subdir @dir;

/* BACKUP .. TO DISK NO acepta expresiones: se arma la ruta en variables. */
DECLARE @fOrigen NVARCHAR(4000) = @dir + N'/ORIGEN_' + @ts + N'.bak';
DECLARE @fStg    NVARCHAR(4000) = @dir + N'/STG_' + @ts + N'.bak';
DECLARE @fDw     NVARCHAR(4000) = @dir + N'/DW_' + @ts + N'.bak';

BACKUP DATABASE [BI_VIP_CENTER_FIT_DW_ORIGEN] TO DISK = @fOrigen
    WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;

BACKUP DATABASE [BI_VIP_CENTER_FIT_STG] TO DISK = @fStg
    WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;

BACKUP DATABASE [BI_VIP_CENTER_FIT_DW] TO DISK = @fDw
    WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;

SELECT @ts AS TimestampBackup, @dir AS Directorio;
GO
