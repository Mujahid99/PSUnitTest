function Load-Dll {
    param ([string]$assembly)
    
    Write-Host $assembly -ForegroundColor Yellow
    $fileStream = ([System.IO.FileInfo] (Get-Item $assembly)).OpenRead();
    $assemblyBytes = new-object byte[] $fileStream.Length
    $fileStream.Read($assemblyBytes, 0, $fileStream.Length) | Out-Null;
    $fileStream.Close();
    $assemblyLoaded = [System.Reflection.Assembly]::Load($assemblyBytes);
}

function Get-DecryptedRpId([string]$id) {
    if ([string]::IsNullOrEmpty($id)) {
        return $null
    }

    $response = Invoke-RestMethod -uri "https://dev.replenium.com/utilities-service/api/id-hashing/decrypt/$($id)" -method Post
    return $response
}

function Get-EncryptedRpId([string]$id) { 
    if ([string]::IsNullOrEmpty($id)) {
        return $null
    }

    $response = Invoke-RestMethod -uri "https://dev.replenium.com/utilities-service/api/id-hashing/encrypt/$($id)" -method Post
    return $response
}

function Get-RpClientIdMappings {
    return @{
        Jackpack  = 18;
        RenewLife = 23;
        BurtsBees = 26;
        Kombrew   = @(30, 31, 32, 33)
    }
}

function Get-RpServicesEndpoints {
    param(
        [ValidateSet(“local”, ”dev”, ”perf”, "stage", "integ")] 
        [string]$targetCluster = 'local',

        [ValidateSet(“local”, ”dev”, ”perf”, "stage", "integ")] 
        [string]$sourceCluster = 'integ'
    )

    $ErrorActionPreference = "Stop"

    $clusters = @{
        local = 'http://localhost';
        dev   = 'https://dev.replenium.com';
        perf  = 'https://perf.replenium.com';
        stage = 'https://staging.replenium.com';
        integ = 'https://integ.replenium.com';
    }

    $target = $clusters.$targetCluster
    $source = $clusters.$sourceCluster

    if ($target.Contains('localhost')) {
        $mapping = @{
            "$($source)/identity-service"   = "$($target):19052";
            "$($source)/orders-service"     = "$($target):19054"
            "$($source)/products-service"   = "$($target):19058";
            "$($source)/promotions-service" = "$($target):19060";
            "$($source)/payments-service"   = "$($target):19056";
            "$($source)/users-service"      = "$($target):19064";
            "$($source)/retailer-proxy"     = "$($target):19062";
        }
    }
    else {
        $mapping = @{
            "$($source)/identity-service"   = "$($target)/identity-service";
            "$($source)/orders-service"     = "$($target)/orders-service"
            "$($source)/products-service"   = "$($target)/products-service";
            "$($source)/promotions-service" = "$($target)/promotions-service";
            "$($source)/payments-service"   = "$($target)/payments-service";
            "$($source)/users-service"      = "$($target)/users-service";
            "$($source)/retailer-proxy"     = "$($target)/retailer-proxy";
        }
    }

    $configuration = [PsCustomObject]@{
        Target   = $target;
        Source   = $source;
        Identity = $mapping["$($source)/identity-service"];
        Services = $mapping;
    }

    return $configuration
}

function Get-RpAuthorizationToken {
    param(
        [ValidateSet('bb.retailer-admin@replenium.com', 'jp.agent@replenium.com', 'rl.agent@replenium.com')]
        [string]$username,

        
        [string]$password,

        [ValidateSet('rp_admin', 'rp')]
        [string]$clientid,

        [string]$endpoint
    )

    Write-Host "Retrieving access token" -ForegroundColor Cyan
    
    $headers = @{ 'Content-Type' = "application/x-www-form-urlencoded" }
    $body = "grant_type=password&username=$($username)&password=$($password)&client_id=$($clientid)"
    
    $response = Invoke-WebRequest -uri "$($endpoint)/connect/token" -headers $headers -body $body -method Post
    $access = $response.Content | ConvertFrom-Json 

    return $access
}

function Try-RpWebRequest {
    param(
        [string]$url,
        [string]$method = $null,
        [hashtable]$headers = $null,
        [string]$body = $null,
        [string]$type = $null
    )

    $erroractionpreference = "Stop"

    $return = [PsCustomObject]@{
        Started  = $(Get-Date)
        Url      = $url;
        Method   = $method;
        Headers  = $headers;
        Body     = $body;
        Type     = $type;
        Status   = $null;
        Code     = $null;
        Content  = $null;
        Error    = $null;
        Duration = $null;
    }

    $parameters = @{ Uri = $url; }

    if ($method) { $parameters.Add("Method", $method) }
    if ($headers) { $parameters.Add("Headers", $headers) }
    if ($body) { $parameters.Add("Body", $body) }
    if ($type) { $parameters.Add("ContentType", $type) }

    Write-Host "$($method) $($url) : " -NoNewline

    try {
        $response = Invoke-WebRequest @parameters

        $return.Code = $response.StatusCode
        $return.Status = $response.StatusDescription
        $return.Content = $response.Content

        Write-Host "$($return.Status)" -ForegroundColor Green
    }
    catch [System.Net.WebException] {
        $return.Code = [int]$_.Exception.Response.StatusCode
        $return.Status = "$($_.Exception.Response.StatusCode)"
        $return.Error = $_.Exception.Message;
        
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $return.Content = $reader.ReadToEnd()
            $reader.Close()
        }

        Write-Host "$($return.Error)" -ForegroundColor Red
    
        if ($return.Content) {
            Write-Host "CONTENT : $($return.Content)" -ForegroundColor DarkGray
        }
    }

    $return.Duration = $(Get-Date).Subtract($return.Started)

    Write-Host ""

    return $return
}

function Parse-HAR {
    param([string]$path)

    $ErrorActionPreference = "Stop"

    write-host "Loading HAR $($path)" -ForegroundColor Cyan

    $har = Get-Content $path -Encoding UTF8 | ConvertFrom-Json
     
    Write-Host "Found $($har.log.entries.Count) entries..." -ForegroundColor Cyan

    return $har
}

function Run-Entry {
    param(
        [pscustomobject]$entry, 
        [PsCustomObject]$configuration = $null,
        [string]$authorization = $null
    )

    $url = $entry.request.url;
    $method = $entry.request.method;
    $body = $entry.request.postData.text;
    $headers = @{}

    foreach ($header in $entry.request.headers) {
        # headers used by replenium
        if (@('Authorization', 'Channel-Id', 'Content-Type', 'Seller-Id').Contains($header.Name)) {
            # overrides authorization if provided
            if ($header.name -eq 'Authorization' -and $authorization -ne $null) {
                $headers.Add($header.Name, $authorization)
            } 
            else {
                $headers.Add($header.Name, $header.Value)
            }
        }
    }

    if ($configuration -ne $null) {
        # replace endpoint with target endpoint
        foreach ($serviceUrl in $configuration.Services.Keys) {
            if ($entry.request.url.StartsWith($serviceUrl)) {
                $redirectUrl = $configuration.Services[$serviceUrl];
                $url = $entry.request.url.Replace($serviceUrl, $redirectUrl)
                break
            }
        }
    }

    $response = Try-RpWebRequest -url $url -method $method -headers $headers -body $body

    return $response
}

function Convert-XmlString
{
    param
    (
        [string]$text
    )
    # Escape Xml markup characters (http://www.w3.org/TR/2006/REC-xml-20060816/#syntax)
    $text.replace('&', '&amp;').replace("'", '&apos;').replace('"', '&quot;').replace('<', '&lt;').replace('>', '&gt;')
}

function Convert-TextToXml
{
    param
    (
        $rootNode = 'root',
        $node = 'node',
        $path = $(Throw 'Missing argument: path'),
        $destination = $(Throw 'Missing argument: destination')
    )
    Get-Content -Path $path | ForEach-Object `
        -Begin {
            Write-Output "<$rootNode>"
        } `
        -Process {
            Write-Output "  <$node>$(Convert-XmlString -text $_)</$node>"
        } `
        -End {
            Write-Output "</$rootNode>"
        } | Set-Content -Path $destination -Force
}