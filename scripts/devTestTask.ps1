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

$baseUri = "https://api.appcenter.ms/v0.1/apps"
$report = @()

$branchesUri = "$baseUri/$owner/$appName/branches"
$appBranches = Get-AppCenterRequest -uri $branchesUri

foreach ($br in $appBranches) {

    $branchBuilds = @()
    $branchName = $br.branch.name

    if ($br.configured -eq $true) {
        $branchBuildsUri = "$baseUri/$owner/$appName/branches/$($branchName.Replace('/','%2F'))/builds"
        $branchBuilds = Get-AppCenterRequest -uri $branchBuildsUri
        $count = ($branchBuilds | Where-Object {$_.status -ne "completed"}) | Measure-Object

        if ($count.Count -lt 2) {
            do {
                $createdBuild = Post-AppCenterRequest -uri $branchBuildsUri
                if ($createdBuild.id) {
                    Write-Output "Build #$($createdBuild.id) in $($branchName) was queued"                    
                    $count.Count++
                }
            } while ($count.Count -le 1)
        } else {
            Write-Warning "There are almoust $($count.Count) builds in $($branchName) builds queued"
        }
        $latestCompletedBuild = $branchBuilds | Where-Object {$_.status -eq "completed"} | select -First 1
        $report += @{Branch = $branchName ; LatestBuild = $latestCompletedBuild}
    } else {
        Write-Warning "The branch $branchName hasn't been configured yet to run builds"
    }    
}

$body = ""
$head = '
<style>
	body {
        font-family: "Calibri";
	    font-size:11.0pt;
	}
    table {
        border-collapse: collapse;
    }
    th {
	    font-family:"Calibri";
	    font-size:11.0pt;
	    font-weight: normal;
        text-align: center;
    }
    td {
	    font-family:"Calibri";
	    font-size:10.0pt;
        border: 1px solid black;
        padding: 4px;
    }
  </style>
'
$body += "
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
foreach ($r in $report) {

     $branchName = $r.Branch
    if ($r.LatestBuild) {       
        $buildId = $r.LatestBuild.id
        $buildResult = $r.LatestBuild.Result
        $buildDuration = [math]::Round((New-TimeSpan -end $R.LatestBuild.finishTime -Start $R.LatestBuild.startTime).TotalMinutes, 4)
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

Invoke-Item $outFilePath