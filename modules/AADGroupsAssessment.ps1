function Invoke-AADGroupsAssessment {
    Write-Host "[#] Executing AAD Group Assessment module..." -ForegroundColor Cyan
    # Log in and get an access token for the Graph API
    try {
        $accessToken = az account get-access-token --resource https://graph.microsoft.com | ConvertFrom-Json | Select-Object -ExpandProperty accessToken
    } catch {
        Write-Warning "Failed to obtain access token for Graph API. Error: $_"
        return
    }

    # Headers for Graph API requests
    $headers = @{
        Authorization = "Bearer $accessToken"
    }

    # Initialize the URL for the first request to list groups
    $graphApiUrl = "https://graph.microsoft.com/v1.0/groups"

    # Initialize an array to hold all groups
    $allGroups = @()

    # Loop to handle pagination
    do {
        try {
            $response = Invoke-RestMethod -Uri $graphApiUrl -Headers $headers -Method Get
            $allGroups += $response.value
            # Check if there is a next link
            $graphApiUrl = if ($response.'@odata.nextLink') { $response.'@odata.nextLink' } else { $null }
        } catch {
            Write-Warning "Failed to retrieve groups from Graph API. Error: $_"
            return
        }
    } while ($graphApiUrl)

    # Initialize an array to hold the enhanced group objects
    $enhancedGroups = @()

    foreach ($group in $allGroups) {
        # Fetch security-related group properties
        try {
            $groupDetails = Invoke-RestMethod -Uri "$graphApiUrl/$($group.id)" -Headers $headers -Method Get
            $securityEnabled = $groupDetails.securityEnabled
            $groupType = $groupDetails.groupType

            # Add security-related properties to the custom object
            $enhancedGroup.SecurityEnabled = $securityEnabled
            $enhancedGroup.GroupType = $groupType

            # Retrieve group owners
            try {
                $owners = Invoke-RestMethod -Uri "$graphApiUrl/$($group.id)/owners" -Headers $headers -Method Get
                # Add owners to the custom object
                $enhancedGroup.Owners = $owners.value
            } catch {
            }
            # Retrieve group members
            try {
                $members = Invoke-RestMethod -Uri "$graphApiUrl/$($group.id)/members" -Headers $headers -Method Get
                # Add members to the custom object
                $enhancedGroup.Members = $members.value
            } catch {
            }

        } catch {
        }
        # Create a custom object with all the details
        $enhancedGroup = [PSCustomObject]@{
            Id = $group.id
            DisplayName = $group.displayName
            Description = $group.description
            createdDateTime = $group.createdDateTime
            onPremisesSyncEnabled = if ($group.onPremisesSyncEnabled -eq $true) { "TRUE" } else { "FALSE" }
            isMicrosoft365Group = if ($group.groupType -contains "Unified" -or "TRUE" -or "FALSE" -and $group.mailEnabled -eq $true) { "TRUE" } else { "FALSE" }
            isSecurityGroup = if (-not $group.groupType -and $group.mailEnabled -eq $false -and $group.securityEnabled -eq $true) { "TRUE" } else { "FALSE" }
            isMailEnabledSecurityGroup = if (-not $group.groupType -and $group.mailEnabled -eq $true -and $group.securityEnabled -eq $true) { "TRUE" } else { "FALSE" }
            isDistributionGroup = if (-not $group.groupType -and $group.mailEnabled -eq $true -and $group.securityEnabled -eq $false) { "TRUE" } else { "FALSE" }

        }
        # Add the enhanced group object to the array
        $enhancedGroups += $enhancedGroup
    }

    # Export the enhanced group information to a CSV file
    $filePath = "./AAD_Group_Assessment.csv"
    try {
        $enhancedGroups | Export-Csv -Path $filePath -NoTypeInformation
    } catch {
        Write-Warning "Failed to export group data to CSV. Error: $_"
        return
    }
    Write-Host "[+] AAD Groups Assessment Done - Exported results to $filePath" -ForegroundColor Green
}
