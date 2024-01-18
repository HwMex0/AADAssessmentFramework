function Invoke-AADUsersAssessment {
    Write-Host "[#] Executing AAD User Assessment module..." -ForegroundColor Cyan

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

    # Initialize the URL for the first request to list users
    $graphApiUrl = "https://graph.microsoft.com/beta/users"

    # Initialize an array to hold all users
    $allUsers = @()

    # Loop to handle pagination
    do {
        try {
            $response = Invoke-RestMethod -Uri $graphApiUrl -Headers $headers -Method Get
            $allUsers += $response.value
            # Update the URL for the next request
            $graphApiUrl = if ($response.'@odata.nextLink') { $response.'@odata.nextLink' } else { $null }
        } catch {
            Write-Warning "Failed to retrieve users from Graph API. Error: $_"
            return
        }
    } while ($graphApiUrl)

    # Initialize an array to hold the enhanced user objects
    $enhancedUsers = @()
    $successfulUserCount = 0
    foreach ($user in $allUsers) {
        # Initialize variables for additional details
        $memberOf, $licenseDetails, $appRoleAssignments, $managerName = $null, $null, $null, "None"
        # Get additional details for each user
        # Define the base URL for user-specific requests
        $userApiUrl = "https://graph.microsoft.com/beta/users/$($user.id)"

        # Get additional details for each user
        try {
            $memberOfResponse = Invoke-RestMethod -Uri "$userApiUrl/memberOf" -Headers $headers -Method Get
            $memberOf = $memberOfResponse.value | ForEach-Object { $_.displayName }
            $memberOfString = $memberOf -join ", "
        } catch {
            Write-Warning "Failed to retrieve memberOf for user $($user.userPrincipalName). Error: $_"
        }

        try {
            $AppRoleAssignmentsResponse = Invoke-RestMethod -Uri "$userApiUrl/appRoleAssignments" -Headers $headers -Method Get
            $AppRoleAssignments = $AppRoleAssignmentsResponse.value | ForEach-Object { $_.resourceDisplayName }
            $AppRoleAssignmentsOfString = $AppRoleAssignments -join ", "
        } catch {
            Write-Warning "Failed to retrieve AppRoleAssignments for user $($user.userPrincipalName). Error: $_"
        }

        try {
            $licenseResponse = Invoke-RestMethod -Uri "$userApiUrl/licenseDetails" -Headers $headers -Method Get
            $licenseDetails = $licenseResponse.value | ForEach-Object { $_.skuPartNumber }
            $licenseDetailsString = $licenseDetails -join ", "
        } catch {
            Write-Warning "Failed to retrieve licenseDetails for user $($user.userPrincipalName). Error: $_"
        }
        try {
            $manager = Invoke-RestMethod -Uri "$graphApiUrl/$($user.id)/manager" -Headers $headers -Method Get
            $managerName = $manager.displayName
        } catch {
        }

        # Create a custom object with all the details
        $enhancedUser = [PSCustomObject]@{
            Id = $user.id
            UserPrincipalName = $user.userPrincipalName
            DisplayName = $user.displayName
            UserType = $user.userType
            Mail = $user.mail
            OfficeLocation = $user.officeLocation
            MemberOf = $memberOfString
            AppRoleAssignments = $AppRoleAssignmentsOfString
            Manager = $managerName
            License = $licenseDetailsString
            onPremisesSyncEnabled = if ($user.onPremisesSyncEnabled -eq $true) { "TRUE" } else { "FALSE" }
            passwordPolicies = $user.passwordPolicies
        }

        # Add the enhanced user object to the array
        $enhancedUsers += $enhancedUser
        $successfulUserCount++
        if ($successfulUserCount % 250 -eq 0) {
            Write-Host "[+] Processed $successfulUserCount users so far..." -ForegroundColor DarkGreen
        }
    }

    # Export the enhanced user information to a CSV file
    $filePath = "./AAD_User_Assessment.csv"
        try {
            $enhancedUsers | Export-Csv -Path $filePath -NoTypeInformation
        } catch {
        Write-Warning "Failed to export user data to CSV. Error: $_"
        return
        }
        Write-Host "[+] AAD Users Assessment Done - Exported results to $filePath" -ForegroundColor Green
    }
