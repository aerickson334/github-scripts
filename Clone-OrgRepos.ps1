$parametersJsonPath = Join-Path $PSScriptRoot 'parameters.json'
if (-not (Test-Path $parametersJsonPath)) {
    throw 'Please create a ''parameters.json'' file.'
}

$baseDirectory = Read-Host 'Enter the path to the directory where the repos will be cloned into'
if (-not (Test-Path $baseDirectory)) {
    throw "The path '$baseDirectory' is not valid."
}

$parameters = ConvertFrom-Json -InputObject (Get-Content -Raw -Path $parametersJsonPath)
$username = $parameters.UserName
$personalAccessToken = $parameters.PersonalAccessToken
$organizationName = $parameters.OrganizationName
$gitHubApiBaseUrl = $parameters.GitHubApiBaseUrl
$credential = [pscredential]::new($username, ($personalAccessToken | ConvertTo-SecureString -AsPlainText -Force))

$uri = "$gitHubApiBaseUrl/orgs/$organizationName/repos"
while ($uri) {

    $response = Invoke-WebRequest -Uri $uri `
                                  -Authentication Basic `
                                  -Method Get `
                                  -Credential $credential

    $repos = ConvertFrom-Json $response.Content
    $repos | Where-Object { $_.Fork -ne $true } | ForEach-Object { 

        $repoName = $_.Name
        $repoCloneUrl = $_.Clone_Url 

        $localPath = Join-Path $baseDirectory $repoName 
        if ($true -ne (Test-Path $localPath)) {
            
            Write-Host "Cloning $repoName..." -ForegroundColor Green
            git clone $repoCloneUrl $localPath --quiet
        }
        else {
            $currentLocation = Get-Location 
            Set-Location $localPath 

            Write-Host "Updating $repoName..." -ForegroundColor Green
            git pull --quiet 

            Set-Location $currentLocation
        }
    }

    $uri = $response.RelationLink['next']
}