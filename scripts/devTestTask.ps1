[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    $token = "",
    [Parameter(Mandatory = $false)]
    $owner = "",
    [Parameter(Mandatory = $false)]
    $appName = ""
)
. "$PSScriptRoot/Functions.ps1"

$baseUri = "https://api.appcenter.ms/v0.1/apps"
$branchesUri = "$baseUri/$owner/$appName/branches"
$appBranches = Get-AppCenterRequest -uri $branchesUri
$builtBranchesSummary = @()

#getting actual configured branches with active builds
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
                Write-Host "There are no new commits in branch $branchName"
                #moving to the next branch
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
$actualBranches | % { $builtBranchesSummary += $_  }
$htmlReport = Compose-BuiltBranchesHTMLReport -branchesToReport $builtBranchesSummary
Invoke-Item -Path $htmlReport