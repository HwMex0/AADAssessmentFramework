function Show-AsciiArtLogo {
    Write-Host "  ___    ___ ______  ___            _ _ _   _____       _ _       "
    Write-Host " / _ \  / _ \|  _  \/ _ \          | (_) | /  ___|     (_) |      "
    Write-Host "/ /_\ \/ /_\ \ | | / /_\ \_   _  __| |_| |_\ `--. _   _ _| |_ ___ "
    Write-Host "|  _  ||  _  | | | |  _  | | | |/ _` | | __|`--. \ | | | | __/ _ \"
    Write-Host "| | | || | | | |/ /| | | | |_| | (_| | | |_/\__/ / |_| | | ||  __/"
    Write-Host "\_| |_/\_| |_/___/ \_| |_/\__,_|\__,_|_|\__\____/ \__,_|_|\__\___|"
    Write-Host "                                                                  "
    Write-Host "                                                                  "    
    Write-Host "            Azure AD Aduit Framework                   " -ForegroundColor Green
    Write-Host "                 Author: HwMex0                         " -ForegroundColor Green
    Get-AzCliCurrentUser -ForegroundColor Green
    Write-Host ""
}

function Get-AzCliCurrentUser {
    try {
        # Execute the az account show command
        $currentUser = az account show | ConvertFrom-Json

        # Check if the user information is available
        if ($currentUser -and $currentUser.user) {
            Write-Host "`nYou are connected to Azure as: $($currentUser.user.name)`n" -ForegroundColor Cyan
        } else {
            Write-Host "You are not connected to Azure. Please run 'az login --allow-no-subscriptions' to connect." -ForegroundColor Yellow
        }
    } catch {
        Write-Error "An error occurred: $_"
    }
}


function Check-AzureConnection {
    $azCheck = az account show --output json
    if ($azCheck -eq $null -or $azCheck -eq '') {
        # User is not connected, prompt to connect
        Write-Host "You are not connected to Azure. Please run 'az login --allow-no-subscriptions' to connect." -ForegroundColor Yellow
        return $false
    } else {
        # Convert array to string if necessary
        if ($azCheck -is [System.Array]) {
            $azCheck = $azCheck -join ""
        }

        # User is connected
        $userInfo = ConvertFrom-Json $azCheck
        $userName = $userInfo.user.name
        Write-Host "You are connected to Azure as $userName." -ForegroundColor Green
        Start-Sleep -Seconds 1
        return $true
    }
}

# Check if the user is connected to Azure
if (-not (Check-AzureConnection)) {
    # Exit the script if the user is not connected
    return
}



$modulesDirectory = ".\modules"                                                                                                           

function Show-MainMenu {
    while ($true) {
        Clear-Host
        Show-AsciiArtLogo
        Write-Host "1. Execute Azure AD Full Assessment" -ForegroundColor Yellow
        Write-Host "2. Run Azure AD App Assessment Module" -ForegroundColor Yellow
        Write-Host "3. Run Azure AD Users Assessment Module" -ForegroundColor Yellow
        Write-Host "4. Run Azure AD Groups Assessment Module" -ForegroundColor Yellow
        Write-Host "5. Exit" -ForegroundColor Yellow
        $choice = Read-Host "Please enter your choice"

        switch ($choice) {
            "1" {
                Invoke-AADAppAssessment
                Invoke-AADUsersAssessment
                Invoke-AADGroupsAssessment
                break
            }
            "2" {
                Invoke-AADAppAssessment
                break
            }
            "3" {
                Invoke-AADUsersAssessment
                break
            }
            "4" {
                Invoke-AADGroupsAssessment
                break
            }
            "5" {
                Write-Host "Exiting..." -ForegroundColor Green
                return
            }
            default {
                Write-Host "Invalid choice, please try again." -ForegroundColor Red
            }
        }

        Write-Host "Press any key to return to the main menu..." -ForegroundColor Magenta
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Check if the modules directory exists
if (Test-Path -Path $modulesDirectory -PathType Container) {
    try {
        # Import all modules in the directory using a wildcard
        Get-ChildItem -Path $modulesDirectory -Filter "*.ps1" | ForEach-Object {
            . $_.FullName
            Write-Host "Imported module: $($_.FullName)"
            Start-Sleep -Seconds 0.5
        }
    } catch {
        Write-Host "An error occurred while importing modules: $_.Exception.Message"
        Start-Sleep -Seconds 2
    }
} else {
    Write-Host "Modules directory $modulesDirectory not found."
}




# Start the main menu
Show-MainMenu
