[CmdletBinding()]
param
(
    #set to false just for test purposes
    [Parameter(Mandatory = $true)]
    $token = "",
    [Parameter(Mandatory = $false)]
    $owner = "v-elyuda-microsoft.com",
    [Parameter(Mandatory = $false)]
    $appName = "DevTaskTest"
)
#function to perform post request to app canter api
function  Post-AppCenterRequest {
    param
    (
        [Parameter(Mandatory = $true)]
        $uri
    )
    try {
        $request = Invoke-RestMethod -Method Post -Uri $uri -Headers @{'X-Api-Token' = $token} -ContentType "application/json"
        return $request
    } catch {
        Throw "An error occured while $uri"
    }
}

#function to perform get request to app canter api
function  Get-AppCenterRequest {
    param
    (
        [Parameter(Mandatory = $true)]
        $uri
    )
    try {
        $request = Invoke-RestMethod -Method Get -Uri $uri -Headers @{'X-Api-Token' = $token} -ContentType "application/json"
        if ($request) {
            return $request
        } else {

        }
    } catch {
        Throw "An error occured while $uri"
    }
}
function Get-ActiveBuilds {
    [CmdletBinding()]
    param
    (
        $appBranches
    )
    $activeBranchesWithBuilds = @()
    foreach ($br in $appBranches) {

        $branchBuilds = @()
        $branchName = $br.branch.name

        if ($br.configured -eq $true) {
            $branchBuildsUri = "$baseUri/$owner/$appName/branches/$($branchName.Replace('/','%2F'))/builds"
            $branchBuilds = Get-AppCenterRequest -uri $branchBuildsUri
            $activeBranchBuilds = ($branchBuilds | Where-Object {$_.status -ne "completed"})
            $activeBranchesWithBuilds += @{Branch = $br; Builds = $activeBranchBuilds; LatestCommit = $br.branch.commit; LatestBuild = $br.lastBuild}
        }
    }
    return $activeBranchesWithBuilds
}

$baseUri = "https://api.appcenter.ms/v0.1/apps"
$report = @()
$branchesUri = "$baseUri/$owner/$appName/branches"
$appBranches = Get-AppCenterRequest -uri $branchesUri

#getting actual configured bracnhes with active builds
$actualBranches = @()
$actualBranches = Get-ActiveBuilds -appBranches $appBranches
$activeBranchesWithBuildsCount = $actualBranches.builds | Measure-Object

#to remember builds that should be built
$hasPendingBuilds = $true
$hasBuildInProgress = $false

#do while there are builds in a queue or some builds in progress or non started (to be sure that a branch is built)
while ($hasPendingBuilds -or $hasBuildInProgress) {

    $hasPendingBuilds = $false
    #loop through all configured branches
    foreach ($item in $actualBranches) {

        $branchName = $item.Branch.branch.name
        $actualBranches = Get-ActiveBuilds -appBranches $appBranches
        $activeBranchesWithBuildsCount = $actualBranches.builds | Measure-Object

        #can't queue any builds if there have been already two queued or running
        if ($activeBranchesWithBuildsCount.Count -lt 2) {

            #to verify if a build should be build (if there have been already builds on a latest commit)
            if ($item.LatestCommit.sha -ne $item.LatestBuild.sourceVersion) {
                #build
                $branchBuildsUri = "$baseUri/$owner/$appName/branches/$($branchName.Replace('/','%2F'))/builds"
                $createdBuild = Post-AppCenterRequest -uri $branchBuildsUri

                if ($createdBuild.id) {
                    Write-Host "Build #$($createdBuild.id) in $($branchName) was queued"
                }
            } else {
                continue
            }
        } else {
            #if there are builds in a queue then we should wait until they finish
            $hasPendingBuilds = $true

            #wait some time to let the queued builds finith
            $flag = Read-Host "Would you like to wait [y/n]?"
            if ($flag -eq "y") {
                Start-Sleep -Seconds 10
            }
        }
    }
    #when branch loop ends then we are to check if there are queued builds left to be sure the branch is built
    $actualBranches = Get-ActiveBuilds -appBranches $appBranches
    $activeBranchesWithBuildsCount = $actualBranches.builds | Measure-Object
    $hasBuildInProgress = ($activeBranchesWithBuildsCount -eq 0)
}

$actualBranches | % { $report += $_  }
Import-Module "$PSScriptRoot\Compose-HTMLReport.ps1" -Force
$htmlReport = Compose-HTMLReport -report $report
Invoke-Item -Path $htmlReport