# a function to perform post request to app canter api
function  Post-AppCenterRequest {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $uri
    )
    try {
        $request = Invoke-RestMethod -Method Post -Uri $uri -Headers @{'X-Api-Token' = $token} -ContentType "application/json"
        return $request
    } catch {
        Throw "$_.Exception `n error requesting $uri"
    }
}
# a function to perform get request to app canter api
function  Get-AppCenterRequest {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $uri
    )
    try {
        $request = Invoke-RestMethod -Method Get -Uri $uri -Headers @{'X-Api-Token' = $token} -ContentType "application/json"
        return $request
    } catch {
        Throw "$_.Exception `n error requesting $uri"
    }
}
# a function to get only configured branches with a list of builds that are in progress or not started
function Get-ActiveBuilds {
    [CmdletBinding()]
    param
    (   [Parameter(Mandatory = $true)]
        $appBranches
    )
    $configuredBranches = @()
    $branchesSummary = @()
    foreach ($br in $appBranches) {

        $branchBuilds = @()
        $branchName = $br.branch.name

        if ($br.configured -eq $true) {
            $branchBuildsUri = "$baseUri/$owner/$appName/branches/$($branchName.Replace('/','%2F'))/builds"
            $branchBuilds = Get-AppCenterRequest -uri $branchBuildsUri
            $activeBranchBuilds = ($branchBuilds | Where-Object {$_.status -ne "completed"})
            $configuredBranches += @{Branch = $br; Builds = $activeBranchBuilds; LatestCommit = $br.branch.commit; LatestBuild = $br.lastBuild}
        }
    }
    $count = $configuredBranches.Builds | Measure-Object
    $hasbuildInProgress = !($count.Count -eq 0)
    $branchesSummary = @{Branches = $configuredBranches; ActiveBuildsCount = $count; Flag = $hasbuildInProgress}
    return $branchesSummary
}
# a function to convert gathered info about each branch to HTML table
function Compose-BuiltBranchesHTMLReport {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $branchesToReport
    )
    $head = Get-Content -Path "$PSScriptRoot\styles.txt"
    $body = "
        <p>Below there is a summary of the latest builds in branches</p>
        <table border = 1>
            <tr>
                <th>Branch Name</th>
                <th>Build Id</th>
                <th>Build Status</th>
                <th>Duration (min)</th>
                <th>Link to Build Logs</th>
            </tr>
        "
    foreach ($r in $branchesToReport) {

        $branchName = $r.Branch.branch.name

        if ($r.Branch.LastBuild) {
            $buildId = $r.Branch.LastBuild.id
            $buildResult = $r.Branch.LastBuild.Result
            $buildDuration = [math]::Round((New-TimeSpan -end $r.Branch.LastBuild.finishTime -Start $r.Branch.LastBuild.startTime).TotalMinutes, 4)
            $buildLogsLinkUri = "$baseUri/$owner/$appName/builds/$buildId/downloads/logs"
            $logsLink = (Get-AppCenterRequest -uri $buildLogsLinkUri).uri

            $body += "<tr>
                <td>$branchName</td>
                <td>$buildId</td>
                <td>$buildResult</td>
                <td>$buildDuration</td>
                <td><a href=$logsLink>Link</a></td>
                </tr>
            "
        } else {
            $body += "<tr>
                <td>$branchName</td>
                <td>No completed builds</td>
                <td>--</td>
                <td>--</td>
                <td><a href=-->Link</a></td>
                </tr>
            "
        }
    }
    $outFilePath = "$env:USERPROFILE\AppData\Local\Temp\devTestTaskReport.html"
    (ConvertTo-Html -Head $head -Body $body) | Out-File $outFilePath
    return $outFilePath
}
#a function to submit a new build in a branch if there has been no a build on the latest commit yet
function  Check-GoingToBuild {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $branchInfo
    )
    if ($branchInfo.LatestCommit.sha -ne $branchInfo.LatestBuild.sourceVersion) {
        $branchBuildsUri = "$baseUri/$owner/$appName/branches/$($branchName.Replace('/','%2F'))/builds"
        $createdBuild = Post-AppCenterRequest -uri $branchBuildsUri
        return $createdBuild
    } else {
        return $false
    }
}
#a function which allows to wait for some to let some build finish
function Wait-QueueIsDrained {
    $flag = Read-Host "Would you like to wait 10 sec for some build finish [y/n]?"
    if ($flag -eq "y") {
        Start-Sleep -Seconds 10
        # $actualBranches = Get-ActiveBuilds -appBranches $appBranches
    }
}