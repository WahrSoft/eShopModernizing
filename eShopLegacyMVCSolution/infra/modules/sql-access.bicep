// =============================================================================
// SQL Access module - Configure managed identity access to SQL Database
// =============================================================================

@description('SQL Server name')
param sqlServerName string

@description('Database name')
param databaseName string

@description('App Service managed identity principal ID')
param appServicePrincipalId string

@description('App Service name for creating the SQL user')
param appServiceName string

// Reference existing SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' existing = {
  name: sqlServerName
}

// Reference existing SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' existing = {
  parent: sqlServer
  name: databaseName
}

// This deployment script will create the contained database user for the managed identity
// This is required because Bicep cannot directly execute SQL commands
resource sqlUserDeploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'create-sql-user-${replace(appServiceName, '-', '')}'
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptManagedIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    timeout: 'PT30M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'ServerName'
        value: sqlServer.properties.fullyQualifiedDomainName
      }
      {
        name: 'DatabaseName'
        value: databaseName
      }
      {
        name: 'AppServiceName'
        value: appServiceName
      }
      {
        name: 'ManagedIdentityClientId'
        value: scriptManagedIdentity.properties.clientId
      }
    ]
    scriptContent: '''
      # Connect to Azure SQL Database using managed identity and create database user
      try {
        # Install required modules
        if (!(Get-Module -ListAvailable -Name SqlServer)) {
          Install-Module -Name SqlServer -Force -AllowClobber
        }
        
        # Get access token for Azure SQL
        $resourceURI = "https${environment().suffixes.sqlServerHostname}/"
        $tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&api-version=2019-08-01"
        $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthURI
        $accessToken = $tokenResponse.access_token
        
        # Create connection string with access token
        $connectionString = "Server=tcp:$env:ServerName,1433;Database=$env:DatabaseName;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
        
        # SQL commands to create user and assign roles
        $createUserSql = @"
        IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$env:AppServiceName')
        BEGIN
          CREATE USER [$env:AppServiceName] FROM EXTERNAL PROVIDER;
        END
        
        -- Grant necessary permissions for Entity Framework
        ALTER ROLE db_datareader ADD MEMBER [$env:AppServiceName];
        ALTER ROLE db_datawriter ADD MEMBER [$env:AppServiceName];
        ALTER ROLE db_ddladmin ADD MEMBER [$env:AppServiceName];
        
        -- Grant permissions for EF migrations and schema operations
        GRANT CREATE TABLE TO [$env:AppServiceName];
        GRANT CREATE VIEW TO [$env:AppServiceName];
        GRANT CREATE PROCEDURE TO [$env:AppServiceName];
        GRANT CREATE FUNCTION TO [$env:AppServiceName];
        GRANT CREATE SEQUENCE TO [$env:AppServiceName];
"@
        
        # Execute SQL commands
        Invoke-Sqlcmd -ConnectionString $connectionString -AccessToken $accessToken -Query $createUserSql -QueryTimeout 120
        
        Write-Output "Successfully created database user and assigned permissions for $env:AppServiceName"
        
        # Set output for verification
        $DeploymentScriptOutputs = @{}
        $DeploymentScriptOutputs['result'] = "Success: Database user created for $env:AppServiceName"
      }
      catch {
        Write-Error "Failed to create database user: $_"
        throw
      }
    '''
  }
  dependsOn: [
    sqlDatabase
  ]
}

// User-assigned managed identity for the deployment script
resource scriptManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'sql-script-identity-${replace(appServiceName, '-', '')}'
  location: resourceGroup().location
}

// Grant the script identity SQL DB Contributor role on the SQL Server
resource scriptSqlAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: sqlServer
  name: guid(sqlServer.id, scriptManagedIdentity.id, '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec') // SQL DB Contributor
    principalId: scriptManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Output
output deploymentScriptResult string = sqlUserDeploymentScript.properties.outputs.result