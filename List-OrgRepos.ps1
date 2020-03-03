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
$uri = "$gitHubApiBaseUrl/orgs/$organizationName/repos"

while ($uri) {

    $response = Invoke-WebRequest -Uri $uri `
                                  -Authentication Basic `
                                  -Credential $credential

    $repos = ConvertFrom-Json $response.Content
    $repos | Where-Object { $_.Fork -ne $true } | ForEach-Object { 
        $_ 
    }

    $uri = $response.RelationLink['next']
}
