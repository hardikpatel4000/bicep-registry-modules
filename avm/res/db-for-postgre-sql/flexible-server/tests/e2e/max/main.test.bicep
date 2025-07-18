targetScope = 'subscription'

metadata name = 'Using Customer-Managed-Keys with User-Assigned identity'
metadata description = 'This instance deploys the module using Customer-Managed-Keys using a User-Assigned Identity to access the Customer-Managed-Key secret.'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'dep-${namePrefix}-dbforpostgresql.flexibleservers-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
var enforcedLocation = 'uksouth' // Enforcing location with available zones

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'dfpfmax'

@description('Generated. Used as a basis for unique resource names.')
param baseTime string = utcNow('u')

@description('Optional. The password to leverage for the login.')
@secure()
param password string = newGuid()

@description('Optional. A token to inject into the name of each resource.')
param namePrefix string = '#_namePrefix_#'

// ============ //
// Dependencies //
// ============ //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: enforcedLocation
}

module nestedDependencies 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, enforcedLocation)}-nestedDependencies'
  params: {
    // Adding base time to make the name unique as purge protection must be enabled (but may not be longer than 24 characters total)
    keyVaultName: 'dep-${namePrefix}-kv-${serviceShort}-${substring(uniqueString(baseTime), 0, 3)}'
    managedIdentityName: 'dep-${namePrefix}-msi-${serviceShort}'
  }
}

// ============== //
// Test Execution //
// ============== //

@batchSize(1)
module testDeployment '../../../main.bicep' = [
  for iteration in ['init', 'idem']: {
    scope: resourceGroup
    name: '${uniqueString(deployment().name, enforcedLocation)}-test-${serviceShort}-${iteration}'
    params: {
      name: '${namePrefix}${serviceShort}001'
      location: enforcedLocation
      availabilityZone: 1
      highAvailability: 'Disabled'
      highAvailabilityZone: 2
      administratorLogin: 'adminUserName'
      administratorLoginPassword: password
      skuName: 'Standard_D2s_v3'
      tier: 'GeneralPurpose'
      geoRedundantBackup: 'Disabled'
      customerManagedKey: {
        keyName: nestedDependencies.outputs.keyName
        keyVaultResourceId: nestedDependencies.outputs.keyVaultResourceId
        userAssignedIdentityResourceId: nestedDependencies.outputs.managedIdentityResourceId
      }
      managedIdentities: {
        userAssignedResourceIds: [
          nestedDependencies.outputs.managedIdentityResourceId
        ]
      }
      serverThreatProtection: 'Enabled'
      autoGrow: 'Enabled'
    }
  }
]
