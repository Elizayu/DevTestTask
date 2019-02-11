[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    $token = "a6b55fd0ac3a6272c48aad9d3ed8354de5239caf",
    [Parameter(Mandatory = $false)]
    $owner = "v-elyuda-microsoft.com",
    [Parameter(Mandatory = $false)]
    $appName = "DevTaskTest"
)
. "$PSScriptRoot/Functions.ps1"

$baseUri = "https://api.appcenter.ms/v0.1/apps"
$branchesUri = "$baseUri/$owner/$appName/branches"
$appBranches = Get-AppCenterRequest -uri $branchesUri
$builtBranchesSummary = @()

#getting actual configured branches with active builds
$actualBranches = @()
$actualBranches = Get-ActiveBuilds -appBranches $appBranches

#to remember builds that should be built
$hasPendingBuilds = $true
$hasBuildInProgress = $false

#do while there are builds in a queue or some builds in progress or non started (to be sure that a branch is built)
while ($hasPendingBuilds -or $hasBuildInProgress) {
    $hasPendingBuilds = $false
    #loop through all configured branches
    foreach ($item in $actualBranches.Branches) {
        $branchName = $item.Branch.branch.name
        $actualBranches = Get-ActiveBuilds -appBranches $appBranches
        #can't queue any builds if there have been already two queued or running
        if ($actualBranches.ActiveBuildsCount.Count -lt 2) {
            if ($branchInfo.LatestCommit.sha -ne $branchInfo.LatestBuild.sourceVersion ) {
                #to verify if a build should be build (if there have been already builds on a latest commit)
                $ifBuild = Check-GoingToBuild -branchInfo $item
                if ($ifBuild) {
                    Write-Host "Build #$($ifBuild.id) in $($branchName) was queued"
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
            Wait-QueueIsDrained -actualBranches $actualBranches
        }
    }
    #to let all the post requests executed
    Start-Sleep -Seconds 2
    #when branch loop ends then we are to check if there are queued builds left to be sure the branch is built
    $actualBranches = Get-ActiveBuilds -appBranches $appBranches
    if ($actualBranches.Flag) {
        Wait-QueueIsDrained
    }
}
$actualBranches.Branches | % { $builtBranchesSummary += $_  }
$htmlReport = Compose-BuiltBranchesHTMLReport -branchesToReport $builtBranchesSummary
Invoke-Item -Path $htmlReport