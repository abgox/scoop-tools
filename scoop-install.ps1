#Requires -Version 5.1

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$restArgs
)

Set-StrictMode -Off

function Get-LocalizedString {
    param($Text)

    $CNText = @{
        "Please install Git first: "                                                                                                                            = "请先安装 Git: "
        "A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when downloading the app via Scoop." = "一个 PowerShell 脚本，它允许你添加 Scoop 配置，以便在通过 Scoop 下载应用时使用替换后的 URL 而非原始 URL。"
        "For more information, please visit: "                                                                                                                  = "详情请查看: "
        "No app specified to install."                                                                                                                          = "没有指定要安装的应用。"
        "Failed to get scoop configuration. Please check if scoop is properly installed."                                                                       = "获取 scoop 配置失败，请检查 scoop 是否正常安装"
        "Undoing local file changes in the following scoop buckets by git stash:"                                                                               = "正在通过 git stash 撤销以下 scoop bucket 中的本地文件更改:"
        "You haven't set the root directory of scoop yet."                                                                                                      = "你还没有设置 scoop 的根目录。"
        "Example:"                                                                                                                                              = "参考配置:"
        "You haven't added the relevant configuration yet."                                                                                                     = "你还没有添加相关配置。"
    }

    if ($PSUICulture -like 'zh*') {
        return $CNText[$Text]
    }
    return $Text
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Get-LocalizedString "Please install Git first: " | Write-Host -ForegroundColor Red -NoNewline
    Write-Host "scoop install abyss/Git.Git" -ForegroundColor Magenta
    exit 1
}


if (-not $restArgs) {
    Write-Host "scoop-install" -ForegroundColor Magenta
    Write-Host "--------------------"
    Get-LocalizedString "A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when downloading the app via Scoop." | Write-Host -ForegroundColor Cyan
    Get-LocalizedString "For more information, please visit: " | Write-Host -ForegroundColor Cyan -NoNewline
    Write-Host "https://scoop-tools.abgox.com" -ForegroundColor Blue -NoNewline
    Write-Host " | " -ForegroundColor Cyan -NoNewline
    Write-Host "https://gitee.com/abgox/scoop-tools" -ForegroundColor Blue -NoNewline
    Write-Host " | " -ForegroundColor Cyan -NoNewline
    Write-Host "https://github.com/abgox/scoop-tools" -ForegroundColor Blue
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

if ($appList.Length -eq 0) {
    Get-LocalizedString "No app specified to install." | Write-Host -ForegroundColor Red
    exit 1
}

function ConvertFrom-JsonAsHashtable {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    begin {
        $buffer = [System.Text.StringBuilder]::new()
    }

    process {
        if ($InputObject -is [array]) {
            [void]$buffer.AppendLine(($InputObject -join "`n"))
        }
        else {
            [void]$buffer.AppendLine($InputObject)
        }
    }

    end {
        $jsonString = $buffer.ToString().Trim()
        if (-not $jsonString) { return $null }

        if ($PSVersionTable.PSVersion.Major -ge 7) {
            return ConvertFrom-Json $jsonString -AsHashtable
        }

        $jsonString = [regex]::Replace($jsonString, '(?<!\\)""\s*:', { '"emptyKey_' + [Guid]::NewGuid() + '":' })

        $jsonString = [regex]::Replace($jsonString, ',\s*(?=[}\]]\s*$)', '')

        $parsed = ConvertFrom-Json $jsonString

        function ConvertRecursively {
            param($obj)

            if ($null -eq $obj) { return $null }

            # IDictionary (Hashtable, Dictionary<,>) -> @{ }
            if ($obj -is [System.Collections.IDictionary]) {
                $ht = @{}
                foreach ($k in $obj.Keys) {
                    $ht[$k] = ConvertRecursively $obj[$k]
                }
                return $ht
            }

            # PSCustomObject -> @{ }
            if ($obj -is [System.Management.Automation.PSCustomObject]) {
                $ht = @{}
                foreach ($p in $obj.PSObject.Properties) {
                    $ht[$p.Name] = ConvertRecursively $p.Value
                }
                return $ht
            }

            # IEnumerable (array、ArrayList), exclude string and byte[]
            if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string]) -and -not ($obj -is [byte[]])) {
                $list = [System.Collections.Generic.List[object]]::new()
                foreach ($item in $obj) {
                    $list.Add((ConvertRecursively $item))
                }
                return , $list.ToArray()
            }

            # ohter types (string, int, bool, datetime...)
            return $obj
        }

        return ConvertRecursively $parsed
    }
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
    Get-LocalizedString "Failed to get scoop configuration. Please check if scoop is properly installed." | Write-Host -ForegroundColor Red
    exit 1
}
$currentPath = Get-Location
$origin = $config.'abgox-scoop-install-url-replace-from'
$replace = $config.'abgox-scoop-install-url-replace-to'

if ($reset) {
    Get-LocalizedString "Undoing local file changes in the following scoop buckets by git stash:" | Write-Host -ForegroundColor Green

    Get-ChildItem "$($config.root_path)\buckets" | ForEach-Object {
        Set-Location $_.FullName
        Write-Host $_.FullName -ForegroundColor Cyan -NoNewline
        Write-Host ": " -NoNewline
        git stash -m "stash changes via abgox/scoop-tools/scoop-install ($(Get-Date))"
    }
    Set-Location $currentPath
}

if ($null -eq $config.root_path) {
    Get-LocalizedString "You haven't set the root directory of scoop yet." | Write-Host -ForegroundColor Yellow
    Get-LocalizedString "Example:" | Write-Host -ForegroundColor Cyan
    Write-Host 'scoop config root_path "D:\scoop"' -ForegroundColor Cyan
    exit 1
}

if ($origin -and $replace) {
    $hasConfig = $true
    $originPatterns = $origin.Split('|||')
    $replacePatterns = $replace.Split('|||')
}
else {
    Get-LocalizedString "You haven't added the relevant configuration yet." | Write-Host -ForegroundColor Yellow
    Get-LocalizedString "For more information, please visit: " | Write-Host -ForegroundColor Cyan -NoNewline
    Write-Host "https://scoop-tools.abgox.com" -ForegroundColor Blue -NoNewline
    Write-Host " | " -ForegroundColor Cyan -NoNewline
    Write-Host "https://gitee.com/abgox/scoop-tools" -ForegroundColor Blue -NoNewline
    Write-Host " | " -ForegroundColor Cyan -NoNewline
    Write-Host "https://github.com/abgox/scoop-tools" -ForegroundColor Blue

    Get-LocalizedString "Example:" | Write-Host -ForegroundColor Cyan
    Write-Host 'scoop config abgox-scoop-install-url-replace-from "^https://github.com|||^https://raw.githubusercontent.com"' -ForegroundColor Cyan
    Write-Host 'scoop config abgox-scoop-install-url-replace-to "https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com"' -ForegroundColor Cyan

    $hasConfig = $false
    exit 1
}

foreach ($app in $appList) {
    $hasError = $false

    try {
        try {
            $info = scoop info $app
            $bucketPath = "$($config.root_path)\buckets\$($info.Source)"
            $appname = $info.Name

            if ($null -eq $info.Source -or $null -eq $info.Name) {
                throw
            }
        }
        catch {
            $hasError = $true
            throw "Error fetching scoop info for ${app}: $_"
        }

        $manifestFile = Get-ChildItem "$bucketPath\bucket" -Recurse -Filter "$appname.json" -ErrorAction Stop
        if ($manifestFile.Count -gt 1) {
            throw "Multiple manifest files found for $appname"
        }
        $manifestPath = $manifestFile.FullName

        $manifest = Get-Content $manifestPath -Raw -Encoding utf8 | ConvertFrom-JsonAsHashtable

        $urlOperations = @(
            @{
                Get = { $manifest.url }
                Set = { param($value) $manifest.url = $value }
            },
            @{
                Get = { $manifest.architecture.'64bit'.url }
                Set = { param($value) $manifest.architecture.'64bit'.url = $value }
            },
            @{
                Get = { $manifest.architecture.'32bit'.url }
                Set = { param($value) $manifest.architecture.'32bit'.url = $value }
            },
            @{
                Get = { $manifest.architecture.arm64.url }
                Set = { param($value) $manifest.architecture.arm64.url = $value }
            }
        )

        foreach ($operation in $urlOperations) {
            $urlValue = & $operation.Get
            if ($urlValue) {
                if ($urlValue -is [array]) {
                    $newValue = @($urlValue | ForEach-Object { Replace-Multiple $_ $originPatterns $replacePatterns })
                }
                else {
                    $newValue = Replace-Multiple $urlValue $originPatterns $replacePatterns
                }
                & $operation.Set $newValue
            }
        }

        try {
            $manifest | ConvertTo-Json -Depth 100 | Out-File $manifestPath -Encoding utf8 -Force -ErrorAction Stop
        }
        catch {
            $hasError = $true
            throw "Failed to write manifest: $_"
        }

        scoop install $app @ScoopParams
    }
    finally {
        if (-not $hasError -and $hasConfig) {
            Set-Location $bucketPath
            git checkout -- $manifestPath
            Set-Location $currentPath
        }
    }
}
