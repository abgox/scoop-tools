param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$restArgs
)

Set-StrictMode -Off

$CN = $PSUICulture -like 'zh*'

if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    if ($CN) {
        Write-Host "请先安装 Git: " -ForegroundColor Red -NoNewline
    }
    else {
        Write-Host "Please install Git first: " -ForegroundColor Red -NoNewline
    }
    Write-Host "scoop install abyss/Git.Git" -ForegroundColor Magenta
    exit 1
}

if (!$restArgs) {
    Write-Host "scoop-update" -ForegroundColor Magenta
    Write-Host "--------------------"
    if ($CN) {
        Write-Host "一个 PowerShell 脚本，它允许你添加 Scoop 配置，在 Scoop 更新应用时使用替换后的 url 而不是原始的 url。" -ForegroundColor Cyan
        Write-Host "详情请查看: " -ForegroundColor Cyan -NoNewline
    }
    else {
        Write-Host "A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when updating the app in Scoop." -ForegroundColor Cyan
        Write-Host "For more information, please visit: " -ForegroundColor Cyan -NoNewline
    }
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
    if ($CN) {
        Write-Host "没有指定要更新的应用。" -ForegroundColor Red
    }
    else {
        Write-Host "No app specified to update." -ForegroundColor Red
    }
    exit 1
}

if ($PSEdition -eq 'Core') {
    function ConvertFrom-JsonAsHashtable {
        param(
            [Parameter(ValueFromPipeline = $true)]
            $InputObject
        )
        ConvertFrom-Json $InputObject -AsHashtable
    }
}
else {
    function ConvertFrom-JsonAsHashtable {
        param(
            [Parameter(ValueFromPipeline = $true)]
            $InputObject
        )

        begin {
            $buffer = [System.Text.StringBuilder]::new()
        }

        process {
            if ($InputObject -is [array]) {
                $null = $buffer.Append(($InputObject -join "`n"))
            }
            else {
                $null = $buffer.Append($InputObject)
            }
        }

        end {
            $jsonString = $buffer.ToString()

            if ($PSVersionTable.PSVersion.Major -ge 7) {
                return $jsonString | ConvertFrom-Json -AsHashtable
            }

            $jsonString = [regex]::Replace($jsonString, '(?<!\\)"\s*"\s*:', {
                    param($m)
                    '"emptyKey_' + [Guid]::NewGuid() + '":'
                })

            $jsonString = [regex]::Replace($jsonString, ',\s*(?=[}\]]\s*$)', '')

            function ProcessArray {
                param($array)
                $nestedArr = [System.Collections.ArrayList]::new()
                foreach ($item in $array) {
                    if ($item -is [System.Collections.IEnumerable] -and $item -isnot [string]) {
                        $null = $nestedArr.Add((ProcessArray $item))
                    }
                    elseif ($item -is [System.Management.Automation.PSCustomObject]) {
                        $null = $nestedArr.Add((ConvertToHashtable $item))
                    }
                    else {
                        $null = $nestedArr.Add($item)
                    }
                }
                return $nestedArr
            }

            function ConvertToHashtable {
                param($obj)
                if ($obj -is [Array]) {
                    return @($obj | ForEach-Object { ConvertToHashtable $_ })
                }
                elseif ($obj -is [PSCustomObject]) {
                    $h = @{}
                    foreach ($prop in $obj.PSObject.Properties) {
                        $h[$prop.Name] = ConvertToHashtable $prop.Value
                    }
                    return $h
                }
                else { return $obj }
            }

            ConvertToHashtable ($jsonString | ConvertFrom-Json)
        }
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
    if ($CN) {
        Write-Host "获取 scoop 配置失败，请检查 scoop 是否正常安装" -ForegroundColor Red
    }
    else {
        Write-Host "Failed to get scoop configuration. Please check if scoop is properly installed." -ForegroundColor Red
    }
    exit 1
}
$currentPath = Get-Location
$origin = $config.'abgox-scoop-install-url-replace-from'
$replace = $config.'abgox-scoop-install-url-replace-to'

if ($reset) {
    if ($CN) {
        Write-Host "正在通过 git stash 撤销以下 scoop bucket 中的本地文件更改:" -ForegroundColor Green
    }
    else {
        Write-Host "Undoing local file changes in the following scoop buckets by git stash:" -ForegroundColor Green
    }
    Get-ChildItem "$($config.root_path)\buckets" | ForEach-Object {
        Set-Location $_.FullName
        Write-Host $_.FullName -ForegroundColor Cyan -NoNewline
        Write-Host ": " -NoNewline
        git stash -m "stash changes via abgox/scoop-tools/scoop-update ($(Get-Date))"
    }
    Set-Location $currentPath
}

if ($null -eq $config.root_path) {
    if ($CN) {
        Write-Host "你还没有设置 scoop 的根目录。" -ForegroundColor Yellow
        Write-Host "参考配置:" -ForegroundColor Cyan
        Write-Host 'scoop config root_path "D:\scoop"' -ForegroundColor Cyan
    }
    else {
        Write-Host "You haven't set the root directory of scoop yet." -ForegroundColor Yellow
        Write-Host "Example:" -ForegroundColor Cyan
        Write-Host 'scoop config root_path "D:\scoop"' -ForegroundColor Cyan
    }
    exit 1
}

if ($origin -and $replace) {
    $hasConfig = $true
    $originPatterns = $origin.Split('|||')
    $replacePatterns = $replace.Split('|||')
}
else {
    if ($CN) {
        Write-Host '你还没有添加相关配置。' -ForegroundColor Yellow
        Write-Host "详情请查看: " -ForegroundColor Cyan -NoNewline
        Write-Host "https://gitee.com/abgox/scoop-tools" -ForegroundColor Blue -NoNewline
        Write-Host " 或 " -ForegroundColor Cyan -NoNewline
        Write-Host "https://github.com/abgox/scoop-tools" -ForegroundColor Blue
        Write-Host '参考配置:' -ForegroundColor Cyan
    }
    else {
        Write-Host "You haven't added the relevant configuration yet." -ForegroundColor Yellow
        Write-Host "For more information, please visit: " -ForegroundColor Cyan -NoNewline
        Write-Host "https://gitee.com/abgox/scoop-tools" -ForegroundColor Blue -NoNewline
        Write-Host " or " -ForegroundColor Cyan -NoNewline
        Write-Host "https://github.com/abgox/scoop-tools" -ForegroundColor Blue
        Write-Host 'Example:' -ForegroundColor Cyan
    }
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
            throw "App not found or error manifest file."
        }

        $manifestPath = (Get-ChildItem "$bucketPath\bucket" -Recurse -Filter "$appname.json").FullName

        if ($PSEdition -eq 'Desktop') {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-JsonAsHashtable
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

        scoop update $app @ScoopParams
    }
    finally {
        if ($hasConfig -and !$hasError) {
            Set-Location $bucketPath
            git checkout -- $manifestPath
            Set-Location $currentPath
        }
    }
}
