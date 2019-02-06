function Compose-HTMLReport {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $report
    )
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