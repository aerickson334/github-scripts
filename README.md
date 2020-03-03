# GitHub Scripts

PowerShell scripts to interact with GitHub's REST API v3. 

## Prerequisites

- Copy the file `parameters.example.json` to `paramters.json`, and fill in the placeholder values with actual values. 

## Add-TeamToAllOrgRepos.ps1

Adds a team (specified by a team slug) to every repo in an organization. You can also specify the level of permissions that the team has to the repo. 

Useful if you want to ensure that all repos in an org are visible to a team, that a team can admin every repo, etc.

## Clone-OrgRepos.ps1 

Clone every repo in an organization into a specified directory.

## List-OrgMembersByContributionCount.ps1 

Lists every member of an organization, and how many contributions they have made to all repos in the organization.

Useful if you need to purge inactive users.

## List-OrgRepos.ps1 

Lists all repos in an organization.

## List-OrgTeams.ps1 

Lists all teams in an organization.

## Set-AllOrgTeamsVisibility.ps1 

Sets the team visibility for every team in an organization. 