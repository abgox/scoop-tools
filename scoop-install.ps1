#Requires -Version 5.1

$restArgs = [string[]]$args

Microsoft.PowerShell.Core\Set-StrictMode -Off

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
                $keys = $obj.Keys
                foreach ($k in $keys) {
                    $ht[$k] = ConvertRecursively $obj[$k]
                }
                return $ht
            }

            # PSCustomObject -> @{ }
            if ($obj -is [System.Management.Automation.PSCustomObject]) {
                $ht = @{}
                $props = $obj.PSObject.Properties
                foreach ($p in $props) {
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

function Get-LocalizedString {
    param($Text)

    $CNText = @{
        'A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when downloading the app via Scoop.' = '一个 PowerShell 脚本，它允许你添加 Scoop 配置，以便在通过 Scoop 下载应用时使用替换后的 URL 而非原始 URL。'
        'For more information, please visit: '                                                                                                                  = '详情请查看: '
        'No app specified to install.'                                                                                                                          = '没有指定要安装的应用。'
        'Failed to get scoop configuration. Please check if scoop is properly installed.'                                                                       = '获取 scoop 配置失败，请检查 scoop 是否正常安装'
        'Example:'                                                                                                                                              = '参考配置:'
        "You haven't added the relevant configuration yet."                                                                                                     = '你还没有添加相关配置。'
    }

    if ($PSUICulture -like 'zh*') {
        return $CNText[$Text]
    }
    return $Text
}

function Replace-Multiple {
    param (
        [string]$InputString,
        [string[]]$Patterns,
        [string[]]$Replacements
    )

    for ($i = 0; $i -lt $Patterns.Count; $i++) {
        $replacement = $Replacements[$i], $Replacements[0] | Select-Object -First 1
        $InputString = $InputString -replace $Patterns[$i], $replacement
    }

    return $InputString
}

function Get-ScoopInstallRoot {
    $commands = @()
    $commands += Get-Command scoop.ps1 -ErrorAction SilentlyContinue
    $commands += Get-Command scoop -CommandType ExternalScript, Application -ErrorAction SilentlyContinue

    foreach ($command in $commands) {
        if (-not $command -or -not $command.Source) {
            continue
        }
        $source = $command.Source
        if ($source -match '^(?<root>.+?)\\apps\\scoop\\current\\bin\\scoop\.ps1$') {
            return $matches.root
        }
        if ($source -match '^(?<root>.+?)\\shims\\scoop(\.ps1|\.cmd)?$') {
            return $matches.root
        }
    }
}

function Get-ScoopConfig {
    try {
        $config = scoop.ps1 config
        if ($LASTEXITCODE -ne 0) {
            throw "scoop config exited with code $LASTEXITCODE"
        }
        return $config
    }
    catch {
        Get-LocalizedString 'Failed to get scoop configuration. Please check if scoop is properly installed.' | Write-Host -ForegroundColor Red
        exit 1
    }
}

function Get-ScoopRoot {
    param($Config)

    $root = $env:SCOOP
    if (-not $root) {
        $root = $Config.root_path
    }
    if (-not $root) {
        $root = Get-ScoopInstallRoot
    }
    if (-not $root) {
        $root = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('UserProfile'), 'scoop')
    }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($root)
}

function Test-ScoopOutdated {
    param($Config)

    if (-not $Config.last_update) {
        return $true
    }

    try {
        $lastUpdate = if ($Config.last_update -is [datetime]) {
            [DateTimeOffset]$Config.last_update
        }
        else {
            [DateTimeOffset]::Parse($Config.last_update, [System.Globalization.CultureInfo]::InvariantCulture)
        }
        return (([DateTimeOffset]::Now - $lastUpdate).TotalHours -ge 3)
    }
    catch {
        return $true
    }
}

function Update-ScoopIfNeeded {
    param(
        $Config,
        [bool]$Skip
    )

    if ($Skip -or -not (Test-ScoopOutdated $Config)) {
        return
    }

    try {
        Invoke-ScoopCommand -Command 'update' -Arguments @() -Context 'Scoop'
    }
    catch {
        Write-Host 'Failed to update Scoop. Aborting.' -ForegroundColor Red
        exit 1
    }
}

function Get-AppInfo {
    param([string]$App)

    $info = scoop.ps1 info $App
    if ($LASTEXITCODE -ne 0 -or $null -in $info.Name, $info.Source) {
        return
    }
    return $info
}

function Get-AppManifestPath {
    param(
        $Info,
        [string]$ScoopRoot
    )

    if (-not $Info -or -not $Info.Name -or -not $Info.Source) {
        return
    }
    if ($Info.Source -match '^(ht|f)tps?://|\\\\') {
        return
    }

    $name = $Info.Name -replace '\s+\(DEPRECATED\)$', ''
    $bucketRoot = Join-Path (Join-Path $ScoopRoot 'buckets') $Info.Source
    if (-not (Test-Path -LiteralPath $bucketRoot)) {
        return
    }

    $searchPaths = @()
    if (Test-Path -LiteralPath (Join-Path $bucketRoot 'bucket')) {
        $searchPaths += Join-Path $bucketRoot 'bucket'
    }
    $searchPaths += $bucketRoot

    foreach ($searchPath in $searchPaths) {
        $manifest = Get-ChildItem -LiteralPath $searchPath -Filter "$name.json" -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
        if ($manifest) {
            return $manifest.FullName
        }
    }
}

function Get-AppDependency {
    param($Info)

    if (-not $Info.Dependencies) {
        return @()
    }
    return $Info.Dependencies -split '\s+\|\s+'
}

function Invoke-ScoopCommand {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [string]$Context
    )

    & scoop.ps1 $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "scoop $Command failed for $Context (exit code $LASTEXITCODE)"
    }
}

function Invoke-WithReplacedManifest {
    param(
        [string]$App,
        [string]$ManifestPath,
        [string[]]$OriginPatterns,
        [string[]]$ReplacePatterns,
        [scriptblock]$Action
    )

    $originalBytes = [System.IO.File]::ReadAllBytes($ManifestPath)
    $manifest = [System.IO.File]::ReadAllText($ManifestPath) | ConvertFrom-JsonAsHashtable

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

    $urlChanged = $false
    foreach ($operation in $urlOperations) {
        $urlValue = & $operation.Get
        if ($urlValue) {
            if ($urlValue -is [array]) {
                $newValue = @($urlValue | ForEach-Object { Replace-Multiple $_ $OriginPatterns $ReplacePatterns })
                if (($newValue -join "`n") -ne ($urlValue -join "`n")) {
                    $urlChanged = $true
                }
            }
            else {
                $newValue = Replace-Multiple $urlValue $OriginPatterns $ReplacePatterns
                if ($newValue -ne $urlValue) {
                    $urlChanged = $true
                }
            }
            & $operation.Set $newValue
        }
    }

    $hasChanged = $false
    try {
        if ($urlChanged) {
            $newContent = $manifest | ConvertTo-Json -Depth 100
            try {
                Set-Content -LiteralPath $ManifestPath -Value $newContent -Encoding utf8 -Force -ErrorAction Stop
                $hasChanged = $true
            }
            catch {
                throw "Failed to write manifest: $_"
            }
        }

        & $Action
    }
    finally {
        if ($hasChanged) {
            [System.IO.File]::WriteAllBytes($ManifestPath, $originalBytes)
        }
    }
}

function Install-App {
    param([string]$App)

    if ($visitedApps.ContainsKey($App)) {
        return
    }
    $visitedApps[$App] = $true

    $info = Get-AppInfo -App $App
    if (-not $info) {
        throw "Error fetching scoop info for ${App}"
    }

    if (-not $independent) {
        foreach ($dependency in Get-AppDependency $info) {
            Install-App -App $dependency
        }
    }

    $manifestPath = Get-AppManifestPath -Info $info -ScoopRoot $scoopRoot
    if (-not $manifestPath) {
        throw "Manifest not found for ${App}"
    }

    $arguments = @($App) + $ScoopParams
    Invoke-WithReplacedManifest -App $App -ManifestPath $manifestPath -OriginPatterns $originPatterns -ReplacePatterns $replacePatterns -Action {
        Invoke-ScoopCommand -Command 'install' -Arguments $arguments -Context $App
    }
}

# Main

if (-not $restArgs) {
    Write-Host 'scoop-install' -ForegroundColor Magenta
    Write-Host '--------------------'
    Get-LocalizedString 'A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when downloading the app via Scoop.' | Write-Host -ForegroundColor Cyan
    Get-LocalizedString 'For more information, please visit: ' | Write-Host -ForegroundColor Cyan -NoNewline
    Write-Host 'https://scoop-tools.abgox.com' -ForegroundColor Blue
    return
}

$appList = @()
$ScoopParams = @()

$valueOptions = @('-a', '--arch')
$independent = $false

for ($i = 0; $i -lt $restArgs.Count; $i++) {
    $arg = $restArgs[$i]

    if ($arg -in $valueOptions) {
        if ($i + 1 -ge $restArgs.Count) {
            Write-Host "Option $arg requires an argument." -ForegroundColor Red
            exit 1
        }
        $ScoopParams += $arg
        $ScoopParams += $restArgs[++$i]
    }
    elseif ($arg -like '-*') {
        if ($arg -eq '--independent' -or $arg -match '^-[^-]*i') {
            $independent = $true
        }
        $ScoopParams += $arg
    }
    else {
        $appList += $arg.Trim()
    }
}

if ($appList.Length -eq 0) {
    Get-LocalizedString 'No app specified to install.' | Write-Host -ForegroundColor Red
    return
}

$config = Get-ScoopConfig

$origin = $config.'abgox-scoop-install-url-replace-from'
$replace = $config.'abgox-scoop-install-url-replace-to'

if ($origin -and $replace) {
    $originPatterns = $origin -split '\|+'
    $replacePatterns = $replace -split '\|+'
}
else {
    Get-LocalizedString "You haven't added the relevant configuration yet." | Write-Host -ForegroundColor Yellow
    Get-LocalizedString 'For more information, please visit: ' | Write-Host -ForegroundColor Cyan -NoNewline
    Write-Host 'https://scoop-tools.abgox.com' -ForegroundColor Blue

    Get-LocalizedString 'Example:' | Write-Host -ForegroundColor Cyan
    Write-Host 'scoop config abgox-scoop-install-url-replace-from "^https://github.com|^https://raw.githubusercontent.com"' -ForegroundColor Cyan
    Write-Host 'scoop config abgox-scoop-install-url-replace-to "https://gh-proxy.org/github.com|https://gh-proxy.org/raw.githubusercontent.com"' -ForegroundColor Cyan

    exit 1
}

$skipScoopUpdate = $ScoopParams -contains '--no-update-scoop' -or ($ScoopParams | Where-Object { $_ -match '^-[^-]*u' })
Update-ScoopIfNeeded -Config $config -Skip:$skipScoopUpdate
if (-not $skipScoopUpdate) {
    # Prevent Scoop from auto-updating while a manifest is patched.
    $ScoopParams += '--no-update-scoop'
}

$scoopRoot = Get-ScoopRoot -Config $config

$visitedApps = @{}
$failedApps = @()
foreach ($app in $appList) {
    try {
        Install-App -App $app
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $failedApps += $app
    }
}

if ($failedApps.Count -gt 0) {
    exit 1
}
