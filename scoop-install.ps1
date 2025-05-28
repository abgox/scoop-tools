param(
    [string]$app
)

$app = $app.Trim()

if ($app -eq "") {
    $config = scoop config
    $current_path = Get-Location

    Get-ChildItem "$($config.root_path)\buckets" | ForEach-Object {
        Set-Location $_.FullName
        Write-Host "Clearing local changes in scoop bucket $($_.Name)" -ForegroundColor Green
        git checkout --quiet .
    }
    Set-Location $current_path
    return
}

try {
    $config = scoop config
    $info = scoop info $app

    $origin = $config.'scoop-install-url-replace-from'
    $replace = $config.'scoop-install-url-replace-to'

    $bucket_path = "$($config.root_path)\buckets\$($info.Bucket)"

    if ($replace -ne $null) {
        $manifest_path = "$($bucket_path)\bucket\$($info.Name).json"
        if ($PSEdition -eq 'Desktop') {
            function ConvertFrom_JsonToHashtable {
                param(
                    [Parameter(ValueFromPipeline = $true)]
                    [string]$json
                )
                # Handle json string
                $matches = [regex]::Matches($json, '\s*"\s*"\s*:')
                foreach ($match in $matches) {
                    $json = $json -replace $match.Value, "`"empty_key_$([System.Guid]::NewGuid().Guid)`":"
                }
                $json = [regex]::Replace($json, ",`n?(\s*`n)?\}", "}")
                function ConvertToHashtable {
                    param($obj)
                    $hash = @{}
                    if ($obj -is [System.Management.Automation.PSCustomObject]) {
                        foreach ($_ in $obj | Get-Member -MemberType Properties) {
                            $k = $_.Name # Key
                            $v = $obj.$k # Value
                            if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) {
                                # Handle array (preserve nested structure)
                                $arr = @()
                                foreach ($item in $v) {
                                    if ($item -is [System.Collections.IEnumerable] -and $item -isnot [string]) {
                                        # Nested array - recurse
                                        $nestedArr = @()
                                        foreach ($nestedItem in $item) {
                                            if ($nestedItem -is [System.Management.Automation.PSCustomObject]) {
                                                $nestedArr += ConvertToHashtable $nestedItem
                                            }
                                            else { $nestedArr += $nestedItem }
                                        }
                                        $arr += , $nestedArr  # Note the comma to preserve array structure
                                    }
                                    else {
                                        if ($item -is [System.Management.Automation.PSCustomObject]) {
                                            $arr += ConvertToHashtable $item
                                        }
                                        else { $arr += $item }
                                    }
                                }
                                $hash[$k] = $arr
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
    }

    scoop install $app
}
finally {
    Set-Location $bucket_path
    git checkout --quiet .
    Set-Location $current_path
}
