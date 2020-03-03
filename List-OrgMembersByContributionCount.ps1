$parametersJsonPath = Join-Path $PSScriptRoot 'parameters.json'
if (-not (Test-Path $parametersJsonPath)) {
    throw 'Please create a ''parameters.json'' file.'
}

$parameters = ConvertFrom-Json -InputObject (Get-Content -Raw -Path $parametersJsonPath)
$username = $parameters.UserName
$personalAccessToken = $parameters.PersonalAccessToken
$organizationName = $parameters.OrganizationName
$gitHubApiBaseUrl = $parameters.GitHubApiBaseUrl
$credential = [pscredential]::new($username, ($personalAccessToken | ConvertTo-SecureString -AsPlainText -Force))

class Contributor {
    [string]$username 
    [string]$name 
    [string]$email
    [int]$publicRepos
    [datetime]$created 
    [datetime]$updated
    [int]$contributions
}

$contributors = @()

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

function Get-RepositoryContributors {
    param (
        [string]$repoName
    )

    $repoContributors = @()

    $uri = "$gitHubApiBaseUrl/repos/$organizationName/$repoName/contributors"
    while ($uri) {
    
        $response = Invoke-WebRequest -Uri $uri `
                                      -Authentication Basic `
                                      -Method Get `
                                      -Credential $credential
    
        try {

            $contributions = ConvertFrom-Json $response.Content
            $contributions | ForEach-Object { 
                        
                $repoContributor = New-Object -TypeName Contributor 
                $repoContributor.username = $_.login 
                $repoContributor.contributions = $_.contributions
    
                $repoContributors += $repoContributor
            }
        }
        catch {
            
        }
    
        $uri = $response.RelationLink['next']
    }

    return $repoContributors
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

        $contributor = New-Object -TypeName Contributor 
        $contributor.username = $username 
        $contributor.name = $user.name
        $contributor.email = $user.email
        $contributor.created = $user.created_at 
        $contributor.updated = $user.updated_at
        $contributor.publicRepos = $user.public_repos

        $contributors += $contributor
    }

    $uri = $response.RelationLink['next']
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
        Write-Host "Getting Contributors to '$repoName'..." -ForegroundColor Green
        $repoContributors = Get-RepositoryContributors $repoName 

        $repoContributors | ForEach-Object { 
            $repoContributor = $_ 
            $contributors | Where-Object { $_.username -eq $repoContributor.username } | ForEach-Object {

                $_.contributions += $repoContributor.contributions
            }
        }

        Start-Sleep -Seconds 1
    }

    $uri = $response.RelationLink['next']
}

$contributors | Sort-Object -Property contributions -Descending | ConvertTo-Csv | Set-Content -Path (Join-Path $PSScriptRoot 'contributors.csv')
$contributors | Sort-Object -Property contributions -Descending | Format-Table