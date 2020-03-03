$parametersJsonPath = Join-Path $PSScriptRoot 'parameters.json'
if (-not (Test-Path $parametersJsonPath)) {
    throw 'Please create a ''parameters.json'' file.'
}

$teamSlug = Read-Host "Enter the slug of the team to add to every repo"
if (-not $teamSlug) {
    throw "'$teamSlug' is not valid."
}

$permission = Read-Host "Enter the permission to grant the team on every repository. This is either 'pull', 'push', or 'admin'"
if ($permission -ne 'pull' -and $permission -ne 'push' -and $permission -ne 'admin') {
    throw "'$permission' is not a valid permission. Enter either 'pull', 'push', or 'admin'."
}

$parameters = ConvertFrom-Json -InputObject (Get-Content -Raw -Path $parametersJsonPath)
$username = $parameters.UserName
$personalAccessToken = $parameters.PersonalAccessToken
$organizationName = $parameters.OrganizationName
$gitHubApiBaseUrl = $parameters.GitHubApiBaseUrl

$credential = [pscredential]::new($username, ($personalAccessToken | ConvertTo-SecureString -AsPlainText -Force))

function Get-Team {
    param (
        [string]$repoName
    )

    $uri = "$gitHubApiBaseUrl/orgs/$organizationName/teams/$teamSlug"
        
    try {
        $response = Invoke-WebRequest -Uri $uri `
                                      -Authentication Basic `
                                      -Method Get `
                                      -Credential $credential

        $team = ConvertFrom-Json $response.Content
        return $team
    }
    catch {
        return $null
    }
}

function Test-CanTeamAccessRepo {
    param (
        [string]$repoName,
        [string]$teamId
    )

    $uri = "$gitHubApiBaseUrl/teams/$teamId/repos/$organizationName/$repoName"
        
    try {
        Invoke-WebRequest -Uri $uri `
                          -Authentication Basic `
                          -Method Get `
                          -Credential $credential
        return $true
    }
    catch {
        return $false
    }
}

function Test-CanUserAdminRepo {
    param (
        [string]$repoName
    )

    $uri = "$gitHubApiBaseUrl/repos/$organizationName/$repoName/collaborators/$username/permission"
        
    try {
        $response = Invoke-WebRequest -Uri $uri `
                                      -Authentication Basic `
                                      -Method Get `
                                      -Credential $credential

        $permissions = ConvertFrom-Json $response.Content
        return $permissions.Permission -eq 'admin'
    }
    catch {
        return $false
    }
}

function Add-TeamAccessToRepo {
    param (
        [string]$repoName
    )

    $uri = "$gitHubApiBaseUrl/orgs/$organizationName/teams/$teamSlug/repos/$organizationName/$repoName"
        
    $requestBody = ConvertTo-Json @{permission = 'pull'}
    Invoke-WebRequest -Uri $uri `
                        -Authentication Basic `
                        -Method Put `
                        -Body $requestBody `
                        -Credential $credential | Out-Null
}

$team = Get-Team $teamSlug 
if (-not $team) {
    throw "'$teamSlug' is not a valid team name."
}

$uri = "$gitHubApiBaseUrl/orgs/$organizationName/repos"
while ($uri) {

    $response = Invoke-WebRequest -Uri $uri `
                                  -Authentication Basic `
                                  -Method Get `
                                  -Credential $credential

    $repos = ConvertFrom-Json $response.Content
    $repos | Where-Object { $_.Fork -ne $true } | ForEach-Object { 

        $repoName = $_.Name

        $teamCanAccessRepo = Test-CanTeamAccessRepo $repoName $team.Id
        $userCanAdminRepo = Test-CanUserAdminRepo $repoName

        if (-not $teamCanAccessRepo -and $userCanAdminRepo) {
            Write-Host "Giving '$teamSlug' readonly access to '$repoName'"
            Add-TeamAccessToRepo $repoName
        }
    }

    $uri = $response.RelationLink['next']
}