function Invoke-AADAppAssessment {

    # Get the current date
    $currentDate = Get-Date

    # Define the date format expected from Azure CLI
    $azureCliDateFormat = "MM/dd/yyyy HH:mm:ss"
    Write-Host "[#] Executing AAD Applicaiton Assessment module..." -ForegroundColor Cyan
    # Retrieve all applications with their details
    $applications = az ad app list --all --query "[].{DisplayName:displayName, AppId:appId, AppCreationDateTime:createdDateTime}" | ConvertFrom-Json

    # Initialize an array to hold applications with extended details
    $extendedApplications = @()

    foreach ($app in $applications) {
        # Retrieve credentials (secrets) for each application
        $credentials = az ad app credential list --id $app.AppId | ConvertFrom-Json

        # Check each credential for expiration
        foreach ($credential in $credentials) {
            # Initialize default values
            $endDate = $null
            $startDate = $null
            $isExpired = $null

            # Try to parse endDate and startDate
            try {
                if ($credential.endDateTime) {
                    $endDate = [datetime]::ParseExact($credential.endDateTime, $azureCliDateFormat, $null)
                    $isExpired = $endDate -lt $currentDate
                }

                if ($credential.startDateTime) {
                    $startDate = [datetime]::ParseExact($credential.startDateTime, $azureCliDateFormat, $null)
                }
            } catch {
                Write-Warning "Error parsing dates for credential in app: $($app.DisplayName). Details: $($_.Exception.Message)"
            }

            # Add extended information for each application
            $extendedApp = $app | Select-Object *, @{Name="SecretEndDate"; Expression={$endDate}}, @{Name="SecretStartDate"; Expression={$startDate}}, @{Name="IsSecretExpired"; Expression={$isExpired}}
            $extendedApplications += $extendedApp
        }
    }

    # Export the extended applications information to CSV
    $filePath = "./AzureAD_Applications_Assessment.csv" 
    $extendedApplications | Export-Csv -Path $filePath -NoTypeInformation
    Write-Host "[+] AAD Applicaiton Assessment Done - Exported results to $filePath" -ForegroundColor Green
}