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
        'You need admin rights to update global apps.'                                                                                                          = '你需要管理员权限才能更新全局应用。'
        'No app specified to update.'                                                                                                                           = '没有指定要更新的应用。'
        'Failed to get scoop configuration. Please check if scoop is properly installed.'                                                                       = '获取 scoop 配置失败，请检查 scoop 是否正常安装'
        'Example:'                                                                                                                                              = '参考配置:'
        "You haven't added the relevant configuration yet."                                                                                                     = '你还没有添加相关配置。'
        'No app to update.'                                                                                                                                     = '没有可以更新的应用。'
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

function Get-GlobalRoot {
    param($Config)

    $root = $env:SCOOP_GLOBAL
    if (-not $root) {
        $root = $Config.global_path
    }
    if (-not $root) {
        $root = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('CommonApplicationData'), 'scoop')
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

function Get-AppUpdateStatus {
    $items = @(scoop.ps1 status --local 6>$null)
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $outdated = @{}
    $missingDependencies = @{}

    foreach ($item in $items) {
        if (-not $item.Name -or $item.Info -match 'Held package') {
            continue
        }

        $level = if ($item.Info -match 'Global install') { 'global' } else { 'user' }
        $key = "$($item.Name)|$level"

        if ($item.'Latest Version') {
            $outdated[$key] = $true
        }
        if ($item.'Missing Dependencies') {
            $missingDependencies[$key] = $true
        }
    }

    return @{
        Outdated            = $outdated
        MissingDependencies = $missingDependencies
    }
}

function Test-AppInstalledAtLevel {
    param(
        $Info,
        [string]$Level
    )

    $entries = @($Info.Installed -split "`n" | Where-Object { $_ })
    if ($Level -eq 'global') {
        return [bool]($entries | Where-Object { $_ -match '\*global\*' })
    }
    return [bool]($entries | Where-Object { $_ -notmatch '\*global\*' })
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

function Install-AppDependency {
    param(
        [string]$App,
        [string]$Level
    )

    if ($visitedDependencies.ContainsKey($App)) {
        return
    }
    $visitedDependencies[$App] = $true

    $info = Get-AppInfo -App $App
    if (-not $info) {
        throw "Error fetching scoop info for ${App}"
    }

    if (-not $independent) {
        foreach ($dependency in Get-AppDependency $info) {
            Install-AppDependency -App $dependency -Level $Level
        }
    }

    if (Test-AppInstalledAtLevel -Info $info -Level $Level) {
        return
    }

    $manifestPath = Get-AppManifestPath -Info $info -ScoopRoot $scoopRoot
    if (-not $manifestPath) {
        return
    }

    $installParams = @()
    if ($Level -eq 'global') {
        $installParams += '--global'
    }
    $installParams += '--no-update-scoop'
    foreach ($param in $ScoopParams) {
        if ($param -in '-k', '--no-cache', '-s', '--skip-hash-check') {
            $installParams += $param
        }
    }

    $arguments = @($App) + $installParams
    Invoke-WithReplacedManifest -App $App -ManifestPath $manifestPath -OriginPatterns $originPatterns -ReplacePatterns $replacePatterns -Action {
        Invoke-ScoopCommand -Command 'install' -Arguments $arguments -Context $App
    }
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

function Update-App {
    param(
        [string]$App,
        [string]$Level,
        [switch]$SkipMissing
    )

    $info = Get-AppInfo -App $App
    if (-not $info) {
        if ($SkipMissing) {
            return
        }
        throw "Error fetching scoop info for ${App}"
    }

    $manifestPath = Get-AppManifestPath -Info $info -ScoopRoot $scoopRoot
    if (-not $manifestPath) {
        if ($SkipMissing) {
            return
        }
        throw "Manifest not found for ${App}"
    }

    if (-not $independent) {
        foreach ($dependency in Get-AppDependency $info) {
            Install-AppDependency -App $dependency -Level $Level
        }
    }

    $arguments = @($App)
    if ($Level -eq 'global') {
        $arguments += '--global'
    }
    $arguments += $ScoopParams

    Invoke-WithReplacedManifest -App $App -ManifestPath $manifestPath -OriginPatterns $originPatterns -ReplacePatterns $replacePatterns -Action {
        Invoke-ScoopCommand -Command 'update' -Arguments $arguments -Context $App
    }
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $admin = [Security.Principal.WindowsBuiltInRole]::Administrator
    return [Security.Principal.WindowsPrincipal]::new($identity).IsInRole($admin)
}

# Main

if (-not $restArgs) {
    Write-Host 'scoop-update' -ForegroundColor Magenta
    Write-Host '--------------------'
    Get-LocalizedString 'A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when downloading the app via Scoop.' | Write-Host -ForegroundColor Cyan
    Get-LocalizedString 'For more information, please visit: ' | Write-Host -ForegroundColor Cyan -NoNewline
    Write-Host 'https://scoop-tools.abgox.com' -ForegroundColor Blue
    return
}

$appList = @()
$ScoopParams = @()
$all = $false
$global = $false
$independent = $false

foreach ($arg in $restArgs) {
    if ($arg -like '-*') {
        if ($arg -in '-a', '--all') {
            $all = $true
        }
        elseif ($arg -in '-g', '--global') {
            $global = $true
        }
        else {
            if ($arg -eq '--independent' -or $arg -match '^-[^-]*i') {
                $independent = $true
            }
            $ScoopParams += $arg
        }
    }
    else {
        if ($arg -eq '*') {
            $all = $true
        }
        else {
            $appList += @{
                Name  = $arg.Trim()
                Level = $null
            }
        }
    }
}

if ($global -and -not (Test-Admin)) {
    Get-LocalizedString 'You need admin rights to update global apps.' | Write-Host -ForegroundColor Red
    exit 1
}

if (-not $all -and $appList.Length -eq 0) {
    Get-LocalizedString 'No app specified to update.' | Write-Host -ForegroundColor Red
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

Update-ScoopIfNeeded -Config $config -Skip:$false

$scoopRoot = Get-ScoopRoot -Config $config
$globalRoot = Get-GlobalRoot -Config $config

if ($all) {
    $appList = @()
    $dirs = @(
        @{
            Path  = "$scoopRoot\apps"
            Level = 'user'
        }
    )
    if ($global) {
        $dirs += @{
            Path  = "$globalRoot\apps"
            Level = 'global'
        }
    }

    foreach ($dir in $dirs) {
        if (Test-Path $dir.Path) {
            $apps = Get-ChildItem $dir.Path -Directory | Where-Object { $_.Name -ne 'scoop' } | Select-Object -ExpandProperty Name
            foreach ($app in $apps) {
                $appList += @{
                    Name  = $app
                    Level = $dir.Level
                }
            }
        }
    }
}

if ($appList.Length -eq 0) {
    Get-LocalizedString 'No app to update.' | Write-Host -ForegroundColor Red
    return
}

$updateStatus = if ($all) { Get-AppUpdateStatus } else { $null }
$visitedDependencies = @{}
$failedApps = @()
foreach ($item in $appList) {
    $app = $item.Name
    $level = $item.Level

    if ($null -eq $level) {
        $level = if ($global) { 'global' } else { 'user' }
    }

    if ($updateStatus -and $null -ne $item.Level) {
        $key = "$app|$level"
        $isOutdated = $updateStatus.Outdated.ContainsKey($key)
        $hasMissingDependencies = $updateStatus.MissingDependencies.ContainsKey($key)

        if (-not $isOutdated -and -not $hasMissingDependencies) {
            continue
        }

        if (-not $isOutdated -and $hasMissingDependencies) {
            if (-not $independent) {
                try {
                    $info = Get-AppInfo -App $app
                    if ($info) {
                        foreach ($dependency in Get-AppDependency $info) {
                            Install-AppDependency -App $dependency -Level $level
                        }
                    }
                }
                catch {
                    Write-Host $_.Exception.Message -ForegroundColor Red
                    $failedApps += $app
                }
            }
            continue
        }
    }

    try {
        Update-App -App $app -Level $level -SkipMissing:($null -ne $item.Level)
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $failedApps += $app
    }
}

if ($failedApps.Count -gt 0) {
    exit 1
}
