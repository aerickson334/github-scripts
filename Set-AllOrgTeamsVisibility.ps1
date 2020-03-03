$parametersJsonPath = Join-Path $PSScriptRoot 'parameters.json'
if (-not (Test-Path $parametersJsonPath)) {
    throw 'Please create a ''parameters.json'' file.'
}

$privacy = Read-Host "Enter the level of privacy that every team should have. This is either 'secret' or 'closed'"
if ($privacy -ne 'secret' -and $privacy -ne 'closed') {
    throw "'$privacy' is not a valid level of privacy. Enter either 'secret' or 'closed'."
}

$parameters = ConvertFrom-Json -InputObject (Get-Content -Raw -Path $parametersJsonPath)
$username = $parameters.UserName
$personalAccessToken = $parameters.PersonalAccessToken
$organizationName = $parameters.OrganizationName
$gitHubApiBaseUrl = $parameters.GitHubApiBaseUrl

$credential = [pscredential]::new($username, ($personalAccessToken | ConvertTo-SecureString -AsPlainText -Force))

function Test-IsUserOrganizationAdmin {

    $uri = "$gitHubApiBaseUrl/orgs/$organizationName/memberships/$username"
 
    $response = Invoke-WebRequest -Uri $uri `
                                  -Authentication Basic `
                                  -Method Get `
                                  -Credential $credential

    $membership = ConvertFrom-Json $response.Content 

    return $membership.Role -eq 'admin'
}

function Test-IsUserTeamMaintainer {
    param (
        [string]$teamSlug
    )

    $uri = "$gitHubApiBaseUrl/orgs/$organizationName/teams/$teamSlug/memberships/$username"
 
    $response = Invoke-WebRequest -Uri $uri `
                                  -Authentication Basic `
                                  -Method Get `
                                  -Credential $credential

    $membership = ConvertFrom-Json $response.Content 

    return $membership.Role -eq 'maintainer'
}

function Update-Team {
    param (
        [string]$teamName,
        [string]$teamSlug,
        [string]$teamDescription
    )

    $uri = "$gitHubApiBaseUrl/orgs/$organizationName/teams/$teamSlug"
 
    $requestBody = ConvertTo-Json @{name = $teamName; description = $teamDescription; privacy = $privacy}
    Invoke-WebRequest -Uri $uri `
                      -Authentication Basic `
                      -Method Patch `
                      -Body $requestBody `
                      -Credential $credential | Out-Null
}

$isUserOrganizationAdmin = Test-IsUserOrganizationAdmin 

$uri = "$gitHubApiBaseUrl/orgs/$organizationName/teams"
while ($uri) {

    $response = Invoke-WebRequest -Uri $uri `
                                  -Authentication Basic `
                                  -Method Get `
                                  -Credential $credential

    $teams = ConvertFrom-Json $response.Content
    $teams | ForEach-Object { 

        if ($_.Privacy -ne $privacy) {
    
            if ($isUserOrganizationAdmin -or (Test-IsUserTeamMaintainer $_.Slug)) {

                $teamName = $_.Name
                Write-Host "Setting $teamName privacy level to '$privacy'."
                Update-Team $_.Name $_.Slug $_.Description
            } 
        }
    }

    $uri = $response.RelationLink['next']
}