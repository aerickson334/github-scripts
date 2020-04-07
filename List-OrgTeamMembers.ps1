$parametersJsonPath = Join-Path $PSScriptRoot 'parameters.json'
if (-not (Test-Path $parametersJsonPath)) {
    throw 'Please create a ''parameters.json'' file.'
}

$parameters = ConvertFrom-Json -InputObject (Get-Content -Raw -Path $parametersJsonPath)
$username = $parameters.UserName
$personalAccessToken = $parameters.PersonalAccessToken
$organizationName = $parameters.OrganizationName
$gitHubApiBaseUrl = $parameters.GitHubApiBaseUrl

$credential = [pscredential]::new($userName, ($personalAccessToken | ConvertTo-SecureString -AsPlainText -Force))

$users = @()
$teams = @()

function Get-User {
    param (
        [string]$username
    )

    $uri = "$gitHubApiBaseUrl/users/$username"
        
    try {
        $response = Invoke-WebRequest -Uri $uri `
                                      -Authentication Basic `
                                      -Method Get `
                                      -Credential $credential

        $user = ConvertFrom-Json $response.Content
        return $user
    }
    catch {
        return $null
    }
}

function Get-TeamMembers {
    param (
        [string]$teamSlug
    )

    $teamMembers = @()

    $uri = "$gitHubApiBaseUrl/orgs/$organizationName/teams/$teamSlug/members"
    while ($uri) {
    
        $response = Invoke-WebRequest -Uri $uri `
                                      -Authentication Basic `
                                      -Method Get `
                                      -Credential $credential
    
        try {

            $teamMembersPage = ConvertFrom-Json $response.Content
            $teamMembersPage | ForEach-Object { 
                $teamMembers += $_
            }
        }
        catch {
            
        }
    
        $uri = $response.RelationLink['next']
    }

    return $teamMembers
}

Write-Host 'Getting Organization Members...' -ForegroundColor Green
$uri = "$gitHubApiBaseUrl/orgs/$organizationName/members"
while ($uri) {

    $response = Invoke-WebRequest -Uri $uri `
                                  -Authentication Basic `
                                  -Method Get `
                                  -Credential $credential

    $members = ConvertFrom-Json $response.Content
    $members | ForEach-Object { 

        $username = $_.login 
        $user = Get-User $username

        $users += $user
    }

    $uri = $response.RelationLink['next']
}

Write-Host 'Getting Organization Teams...' -ForegroundColor Green
$uri = "$gitHubApiBaseUrl/orgs/$organizationName/teams"
while ($uri) {

    $response = Invoke-WebRequest -Uri $uri `
                                  -Authentication Basic `
                                  -Credential $credential

    $teamsPage = ConvertFrom-Json $response.Content
    $teamsPage | ForEach-Object { 
        $teams += $_
    }

    $uri = $response.RelationLink['next']
}

if (Test-Path -Path 'members-by-team.csv') {
    Remove-Item 'members-by-team.csv'
}

Add-Content -Path 'members-by-team.csv' -Value 'Team,Member'

Write-Host 'Getting Members By Team...' -ForegroundColor Green
$teams | Sort-Object Name -Unique | ForEach-Object { 
    $teamName = $_.Name

    $teamMembers = Get-TeamMembers $_.Slug 
    $teamMembers | ForEach-Object {

        $login = $_.login
        $user = $users | Where-Object { $_.login -eq $login } | Select-Object -First 1
        $name = if ($user) { $user.name } else { $login }
        Add-Content -Path 'members-by-team.csv' -Value "$teamName,$name"
    }
}