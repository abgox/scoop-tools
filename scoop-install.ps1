param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$restArgs
)

$version = "1.0.0"

$showCN = $PSUICulture -like 'zh*'

if (!$restArgs) {
    Write-Host "scoop-install " -ForegroundColor Magenta -NoNewline
    Write-Host "v$version" -ForegroundColor Cyan
    if ($showCN) {
        Write-Host "一个 PowerShell 脚本，它允许你添加 Scoop 配置，在 Scoop 安装应用时使用替换后的 url 而不是原始的 url。" -ForegroundColor Cyan
        Write-Host "详情请查看: " -ForegroundColor Cyan -NoNewline
    }
    else {
        Write-Host "A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when installing the app in Scoop." -ForegroundColor Cyan
        Write-Host "For more information, please visit: " -ForegroundColor Cyan -NoNewline
    }
    Write-Host "https://gitee.com/abgox/scoop-install" -ForegroundColor Blue -NoNewline
    Write-Host " 或 " -ForegroundColor Cyan -NoNewline
    Write-Host "https://github.com/abgox/scoop-install" -ForegroundColor Blue
    return
}

$appList = @()
$ScoopParams = @()

foreach ($arg in $restArgs) {
    if ($arg -like "-*") {
        if ($arg -eq "-reset") {
            $reset = $true
        }
        else {
            $ScoopParams += $arg
        }
    }
    else {
        $appList += $arg.Trim()
    }
}

function ConvertFrom-JsonToHashtable {
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

function Replace-Multiple {
    param (
        [string]$InputString,
        [string[]]$Patterns,
        [string[]]$Replacements
    )

    for ($i = 0; $i -lt $Patterns.Count; $i++) {
        if ($null -eq $Replacements[$i]) {
            $Replacements[$i] = $Replacements[0]
        }

        $InputString = $InputString -replace $Patterns[$i], $Replacements[$i]
    }

    return $InputString
}

try {
    $config = scoop config
}
catch {
    if ($showCN) {
        Write-Host "获取 scoop 配置失败，请检查 scoop 是否正常安装" -ForegroundColor Red
    }
    else {
        Write-Host "Failed to get scoop configuration. Please check if scoop is properly installed." -ForegroundColor Red
    }
    return
}
$currentPath = Get-Location
$origin = $config.'scoop-install-url-replace-from'
$replace = $config.'scoop-install-url-replace-to'
$originPatterns = $origin.Split('|||')
$replacePatterns = $replace.Split('|||')

if ($reset) {
    if ($showCN) {
        Write-Host "正在通过 git stash 撤销以下 scoop bucket 中的本地文件更改:" -ForegroundColor Green
    }
    else {
        Write-Host "Undoing local file changes in the following scoop buckets by git stash:" -ForegroundColor Green
    }

    Get-ChildItem "$($config.root_path)\buckets" | ForEach-Object {
        Set-Location $_.FullName
        Write-Host $_.FullName -ForegroundColor Cyan -NoNewline
        Write-Host ": " -NoNewline
        git stash -m "stash changes via scoop-install ($(Get-Date))"
    }
    Set-Location $currentPath
}

if ($null -eq $config.root_path) {
    if ($showCN) {
        Write-Host "你还没有设置 scoop 的根目录。" -ForegroundColor Yellow
        Write-Host "参考配置:" -ForegroundColor Cyan
        Write-Host 'scoop config root_path "D:\scoop"' -ForegroundColor Cyan
    }
    else {
        Write-Host "You haven't set the root directory of scoop yet." -ForegroundColor Yellow
        Write-Host "Example:" -ForegroundColor Cyan
        Write-Host 'scoop config root_path "D:\scoop"' -ForegroundColor Cyan
    }
    return
}

if ($origin -and $replace) {
    $hasConfig = $true
}
else {
    if ($showCN) {
        Write-Host '你还没有添加相关配置。' -ForegroundColor Yellow
        Write-Host "详情请查看: " -ForegroundColor Cyan -NoNewline
        Write-Host "https://gitee.com/abgox/scoop-install" -ForegroundColor Blue -NoNewline
        Write-Host " 或 " -ForegroundColor Cyan -NoNewline
        Write-Host "https://github.com/abgox/scoop-install" -ForegroundColor Blue
        Write-Host '参考配置:' -ForegroundColor Cyan
    }
    else {
        Write-Host "You haven't added the relevant configuration yet." -ForegroundColor Yellow
        Write-Host "For more information, please visit: " -ForegroundColor Cyan -NoNewline
        Write-Host "https://gitee.com/abgox/scoop-install" -ForegroundColor Blue -NoNewline
        Write-Host " or " -ForegroundColor Cyan -NoNewline
        Write-Host "https://github.com/abgox/scoop-install" -ForegroundColor Blue
        Write-Host 'Example:' -ForegroundColor Cyan
    }
    Write-Host 'scoop config scoop-install-url-replace-from "^https://github.com|||^https://raw.githubusercontent.com"' -ForegroundColor Cyan
    Write-Host 'scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com"' -ForegroundColor Cyan

    $hasConfig = $false
    return
}

foreach ($app in $appList) {
    $hasError = $false

    try {
        try {
            $info = scoop info $app
            $bucketPath = "$($config.root_path)\buckets\$($info.Bucket)"
            $appname = $info.Name

            if ($null -eq $info.Bucket -or $null -eq $info.Name) {
                throw
            }
        }
        catch {
            $hasError = $true
            throw "App not found or error manifest file."
        }

        $manifestPath = (Get-ChildItem "$bucketPath\bucket" -Recurse -Filter "$appname.json").FullName

        if ($PSEdition -eq 'Desktop') {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-JsonToHashtable
        }
        else {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        }

        if ($manifest.url) {
            $manifest.url = Replace-Multiple $manifest.url $originPatterns $replacePatterns
        }
        if ($manifest.architecture.'64bit'.url) {
            $manifest.architecture.'64bit'.url = Replace-Multiple $manifest.architecture.'64bit'.url $originPatterns $replacePatterns
        }
        if ($manifest.architecture.'32bit'.url) {
            $manifest.architecture.'32bit'.url = Replace-Multiple $manifest.architecture.'32bit'.url $originPatterns $replacePatterns
        }
        if ($manifest.architecture.arm64.url) {
            $manifest.architecture.arm64.url = Replace-Multiple $manifest.architecture.arm64.url $originPatterns $replacePatterns
        }

        $manifest | ConvertTo-Json -Depth 100 | Out-File $manifestPath -Encoding utf8 -Force

        scoop install $app @ScoopParams
    }
    finally {
        if ($hasConfig -and !$hasError) {
            Set-Location $bucketPath
            git checkout -- $manifestPath
            Set-Location $currentPath
        }
    }
}
