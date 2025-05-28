param(
    [string]$app
)

$app = $app.Trim()
$config = scoop config
$current_path = Get-Location

if ($app -eq "") {
    if ($PSUICulture -eq 'zh-CN') {
        Write-Host "正在清理 scoop bucket 中的本地更改:" -ForegroundColor Green
    }
    else {
        Write-Host "Clearing local changes in scoop bucket:" -ForegroundColor Green
    }

    Get-ChildItem "$($config.root_path)\buckets" | ForEach-Object {
        Set-Location $_.FullName
        Write-Host $_.FullName -ForegroundColor Cyan
        git checkout --quiet .
    }
    Set-Location $current_path
    return
}

try {
    $info = scoop info $app
    $bucket_path = "$($config.root_path)\buckets\$($info.Bucket)"

    $origin = $config.'scoop-install-url-replace-from'
    $replace = $config.'scoop-install-url-replace-to'

    $no_config = $false

    if ($origin -eq $null -or $replace -eq $null) {
        if ($PSUICulture -eq 'zh-CN') {
            Write-Host '你还没有添加相关配置。' -ForegroundColor Yellow
            Write-Host '参考配置:' -ForegroundColor Cyan
        }
        else {
            Write-Host "You haven't added the relevant configuration yet." -ForegroundColor Yellow
            Write-Host 'Example:' -ForegroundColor Cyan
        }
        Write-Host 'scoop config scoop-install-url-replace-from "https://github.com"' -ForegroundColor Cyan
        Write-Host 'scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com"' -ForegroundColor Cyan

        $no_config = $true
        return
    }

    $manifest_path = "$($bucket_path)\bucket\$($info.Name).json"
    if ($PSEdition -eq 'Desktop') {
        function ConvertFrom_JsonToHashtable {
            param(
                [Parameter(ValueFromPipeline = $true)]
                [string]$json
            )
            $matches = [regex]::Matches($json, '\s*"\s*"\s*:')
            foreach ($match in $matches) {
                $json = $json -replace $match.Value, "`"empty_key_$([System.Guid]::NewGuid().Guid)`":"
            }
            $json = [regex]::Replace($json, ",`n?(\s*`n)?\}", "}")

            function ProcessArray {
                param($array)
                $nestedArr = @()
                foreach ($item in $array) {
                    if ($item -is [System.Collections.IEnumerable] -and $item -isnot [string]) {
                        $nestedArr += , (ProcessArray $item)
                    }
                    elseif ($item -is [System.Management.Automation.PSCustomObject]) {
                        $nestedArr += ConvertToHashtable $item
                    }
                    else { $nestedArr += $item }
                }
                return , $nestedArr
            }

            function ConvertToHashtable {
                param($obj)
                $hash = @{}
                if ($obj -is [System.Management.Automation.PSCustomObject]) {
                    foreach ($_ in $obj | Get-Member -MemberType Properties) {
                        $k = $_.Name # Key
                        $v = $obj.$k # Value
                        if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) {
                            # Handle array (preserve nested structure)
                            $hash[$k] = ProcessArray $v
                        }
                        elseif ($v -is [System.Management.Automation.PSCustomObject]) {
                            # Handle object
                            $hash[$k] = ConvertToHashtable $v
                        }
                        else { $hash[$k] = $v }
                    }
                }
                else { $hash = $obj }
                $hash
            }
            # Recurse
            ConvertToHashtable ($json | ConvertFrom-Json)
        }
        $manifest = Get-Content $manifest_path -Raw | ConvertFrom_JsonToHashtable
    }
    else {
        $manifest = Get-Content $manifest_path -Raw | ConvertFrom-Json -AsHashtable
    }

    if ($manifest.url) {
        $manifest.url = $manifest.url -replace "^$($origin)", $replace
    }
    if ($manifest.architecture.'64bit'.url) {
        $manifest.architecture.'64bit'.url = $manifest.architecture.'64bit'.url -replace "^$($origin)", $replace
    }
    if ($manifest.architecture.'32bit'.url) {
        $manifest.architecture.'32bit'.url = $manifest.architecture.'32bit'.url -replace "^$($origin)", $replace
    }
    if ($manifest.architecture.arm64.url) {
        $manifest.architecture.arm64.url = $manifest.architecture.arm64.url -replace "^$($origin)", $replace
    }
    $manifest | ConvertTo-Json -Depth 100 | Out-File $manifest_path -Encoding utf8 -Force

    scoop install $app
}
finally {
    if ($no_config) {
        return
    }
    Set-Location $bucket_path
    git checkout --quiet .
    Set-Location $current_path
}
