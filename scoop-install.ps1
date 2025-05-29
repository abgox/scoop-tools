param(
    [string]$app,
    [switch]$reset
)

$app = $app.Trim()
$config = scoop config
$current_path = Get-Location

if ($reset) {
    if ($PSUICulture -like "zh*") {
        Write-Host "正在清除以下 scoop bucket 中的本地文件更改:" -ForegroundColor Green
    }
    else {
        Write-Host "Clearing local file changes in the following scoop buckets:" -ForegroundColor Green
    }

    Get-ChildItem "$($config.root_path)\buckets" | ForEach-Object {
        Set-Location $_.FullName
        Write-Host $_.FullName -ForegroundColor Cyan
        git checkout --quiet .
    }
    Set-Location $current_path
}

if ($app -eq "") {
    if (!$reset) {
        if ($PSUICulture -like "zh*") {
            Write-Host "scoop-install 是一个 PowerShell 脚本，它允许你添加 Scoop 配置，在 Scoop 安装应用时使用替换后的 url 而不是原始的 url。" -ForegroundColor Blue
            Write-Host "`n用法: scoop-install.ps1 [-reset] <app>" -ForegroundColor Blue
            Write-Host "`n详情请查看: https://gitee.com/abgox/scoop-install" -ForegroundColor Blue
        }
        else {
            Write-Host "scoop-install is a PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when installing the app in Scoop." -ForegroundColor Blue
            Write-Host "`nUsage: scoop-install.ps1 [-reset] <app>" -ForegroundColor Blue
            Write-Host "`nFor more information, please visit: https://gitee.com/abgox/scoop-install" -ForegroundColor Blue
        }
    }
    return
}

try {
    $info = scoop info $app
    $bucket_path = "$($config.root_path)\buckets\$($info.Bucket)"
    $manifest_path = "$($bucket_path)\bucket\$($info.Name).json"

    $origin = $config.'scoop-install-url-replace-from'
    $replace = $config.'scoop-install-url-replace-to'

    $has_config = $true

    if ($origin -eq $null -or $replace -eq $null) {
        if ($PSUICulture -like "zh*") {
            Write-Host '你还没有添加相关配置。' -ForegroundColor Yellow
            Write-Host '参考配置:' -ForegroundColor Cyan
        }
        else {
            Write-Host "You haven't added the relevant configuration yet." -ForegroundColor Yellow
            Write-Host 'Example:' -ForegroundColor Cyan
        }
        Write-Host 'scoop config scoop-install-url-replace-from "https://github.com"' -ForegroundColor Cyan
        Write-Host 'scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com"' -ForegroundColor Cyan

        $has_config = $false
        return
    }

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
    if ($has_config) {
        Set-Location $bucket_path
        git checkout -- "bucket/$($info.Name).json"
        Set-Location $current_path
    }
}
