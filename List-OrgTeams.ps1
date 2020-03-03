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
$uri = "$gitHubApiBaseUrl/orgs/$organizationName/teams"

while ($uri) {

    $response = Invoke-WebRequest -Uri $uri `
                                  -Authentication Basic `
                                  -Credential $credential

    $teams = ConvertFrom-Json $response.Content
    $teams | ForEach-Object { 
        $_
    }

    $uri = $response.RelationLink['next']
}
