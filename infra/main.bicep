// =============================================================================
// VIP Center Fit BI - Infraestructura Azure (boceto)
//
// Despliega lo necesario para correr la API + SQL + secretos + observabilidad:
//   - Log Analytics / Application Insights
//   - SQL Server (Azure SQL logical server + database) para las 3 bases
//   - Key Vault (cadenas de conexión y API key)
//   - Container Apps (la API ASP.NET Core) leyendo secretos de Key Vault
//
// Nota: en local el pipeline corre con Docker (docker-compose.yml); este archivo
// es para el despliegue en Azure. Ajustar por entornos/CI antes de usarlo.
// =============================================================================

targetScope = 'resourceGroup'

@description('Región de despliegue.')
param location string = resourceGroup().location

@description('Login administrador del servidor SQL.')
param sqlAdminLogin string = 'vipadmin'

@secure()
@description('Password del administrador SQL.')
param sqlAdminPassword string

@secure()
@description('API key para los endpoints de escritura/lectura (header X-Api-Key).')
param apiKey string

@description('Imagen de la API publicada (ACR o Docker Hub).')
param apiImage string = 'vipcenterfit/api:latest'

var sqlServerName = 'vipfit-sql-${uniqueString(resourceGroup().id)}'
var kvName = 'vipfit-kv-${uniqueString(resourceGroup().id)}'
var logsName = 'vipfit-logs-${uniqueString(resourceGroup().id)}'
var appInsightsName = 'vipfit-appi-${uniqueString(resourceGroup().id)}'
var sqlDbName = 'BI_VIP_CENTER_FIT_DW'
var envName = 'vipfit-env'

// --- Observabilidad ---------------------------------------------------------
resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logsName
  location: location
  properties: { retentionInDays: 30 }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
  }
}

// --- SQL Server + Data Warehouse -------------------------------------------
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  sku: { name: 'Basic', tier: 'Basic' }
  properties: { collation: 'SQL_Latin1_General_CP1_CI_AS' }
}

// --- Key Vault (secretos) ---------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enableSoftDelete: true
  }
}

resource secretApiKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ApiKey'
  properties: { value: apiKey }
}

resource secretSql 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'SqlAdminPassword'
  properties: { value: sqlAdminPassword }
}

// --- Container Apps (API) ---------------------------------------------------
resource managedEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: { customerId: logs.properties.customerId, sharedKey: logs.listKeys().primarySharedKey }
    }
  }
}

resource apiApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'vipfit-api'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    managedEnvironmentId: managedEnv.id
    configuration: {
      ingress: { external: true, targetPort: 8080 }
      secrets: [
        { name: 'sql-password', keyVaultUrl: secretSql.properties.secretUri, identity: 'system' }
        { name: 'api-key', keyVaultUrl: secretApiKey.properties.secretUri, identity: 'system' }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: apiImage
          env: [
            { name: 'ASPNETCORE_URLS', value: 'http://+:8080' }
            { name: 'ApiKey', secretRef: 'api-key' }
            { name: 'ConnectionStrings__Dw', value: 'Server=${sqlServer.properties.fullyQualifiedDomainName};Database=${sqlDbName};User Id=${sqlAdminLogin};Password=secretref:sql-password;TrustServerCertificate=True;Encrypt=True' }
            { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
          ]
        }
      ]
    }
  }
}

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output keyVaultName string = keyVault.name
output apiFqdn string = apiApp.properties.configuration.ingress.fqdn
