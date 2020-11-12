param(
    [string]$harFilePath,

    [string]$harResultFilePath,

    [ValidateSet(“local”, ”dev”, ”perf”, "stage", "integ")] 
    [string]$targetCluster,

    [ValidateSet(“local”, ”dev”, ”perf”, "stage", "integ")] 
    [string]$sourceCluster,

    [ValidateSet('BB.retailer-admin@replenium.com', 'jp.agent@replenium.com', 'rl.agent@replenium.com')]
    [string]$username,

    
    [string]$password,

    [ValidateSet('rp_admin', 'rp')]
    [string]$clientid,

    [switch]$preserveAuth
)
$harFilePath = "C:\Users\devrpvm-user\Documents\grocerkey.har"
$targetCluster="stage"
$sourceCluster= "integ"
$username="bb.retailer-admin@replenium.com"
$password ="Test1234-"
$clientid= "rp_admin"

# imports functionality 
# keeps automation simple
. C:\Users\devrpvm-user\Documents\PSUnitTest\RpFunctions-Mujahid.ps1

$ErrorActionPreference = "Stop"

$config = Get-RpServicesEndpoints -targetCluster $targetCluster -sourceCluster $sourceCluster 

# get and parse HAR 
# does not filter or clean
$har = Parse-HAR -path $harFilePath
   
# chrome hars have _resourceType
# required to filter by xhr
if ($har.log.entries._resourceType.Count -eq 0) {
    Write-Error "_resourceType is not available in HAR. This property is only in HAR generated from Chrome"
}

# filter to api resource type calls only
$xhrs = $har.log.entries | where _resourceType -eq xhr
$har.log.entries = $xhrs

# filter to replenium or localhost calls only
$rplms = $har.log.entries | where { $har.log.entries.request.url -like "*replenium.com*" -or $har.log.entries.request.url -like "*localhost*" }
$har.log.entries = $rplms

Write-Host "Filtered to $($har.log.entries.Count) replenium entries..." -ForegroundColor Cyan

# sometimes auth can be reused if the token has not expired
# if not this will request new token using provided credentials
$token = $null;
if (!$preserveAuth) {
    $authorization = Get-RpAuthorizationToken -endpoint $config.Identity -username  $username  -password $password -clientid $clientid
    $token = "Bearer $($authorization.access_token)"
}

$i = 0
$responses = @()

foreach ($entry in $har.log.entries) {
    # designed to be used in adhoc manor if nessesary 
    $response = Run-Entry -entry $entry -configuration $config -authorization $token

    # adds original entry to response and a index
    # added for evaluation and re-execution purposes
    $response | Add-Member -MemberType NoteProperty -Name Entry -Value $entry
    $response | Add-Member -MemberType NoteProperty -Name Index -Value $i
    $responses += $response 
    $i++
}
$muj = $responses | Export-Clixml -Path C:\Users\devrpvm-user\Documents\PSUnitTest\TestResults\sample.xml

#$muj = $responses | Out-File .\ali.trx

return $muj

Convert-TextToXml -rootNode 'BuildAndPackageAll' -node 'message' -path '.\export.txt' -destination '.\export2.xml';
