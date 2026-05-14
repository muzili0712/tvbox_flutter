# TVBox 源诊断工具 (Windows PowerShell 5.x 兼容)
# 用法: powershell -ExecutionPolicy Bypass -File .\diagnose.ps1

param(
    [string]$SourceUrl = "https://9280.kstore.vip/cat/index.js",
    [string]$TestKeyword = "庆余年",
    [switch]$SkipSearch,
    [switch]$SkipCategory,
    [switch]$SkipDetail,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  TVBox Source Diagnostic Tool v1.0" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  Source: $SourceUrl" -ForegroundColor Gray
Write-Host "  Keyword: $TestKeyword" -ForegroundColor Gray
Write-Host ""

# 1. Check environment
Write-Host "[1/5] Checking environment..." -ForegroundColor Yellow

try {
    $nodeVer = node --version 2>$null
    Write-Host "  Node.js: $nodeVer" -ForegroundColor Green
} catch {
    Write-Host "  Node.js not found!" -ForegroundColor Red
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$nodejsDir = Join-Path $scriptDir "ios\Runner\nodejs-project"
$nodeModulesDir = Join-Path $nodejsDir "node_modules"

if (-not (Test-Path $nodeModulesDir)) {
    Write-Host "  Installing npm dependencies..." -ForegroundColor Yellow
    Push-Location $nodejsDir
    npm install --legacy-peer-deps 2>$null
    Pop-Location
}
Write-Host "  Dependencies OK" -ForegroundColor Green

# 2. Download source
Write-Host ""
Write-Host "[2/5] Downloading source..." -ForegroundColor Yellow

$tempDir = Join-Path $env:TEMP "tvbox-diag-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$indexJsPath = Join-Path $tempDir "index.js"
try {
    Invoke-WebRequest -Uri $SourceUrl -OutFile $indexJsPath -TimeoutSec 30
    $fileSize = (Get-Item $indexJsPath).Length
    Write-Host "  Downloaded: $([math]::Round($fileSize/1KB, 1)) KB" -ForegroundColor Green
} catch {
    Write-Host "  Download failed: $_" -ForegroundColor Red
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$configJsPath = Join-Path $tempDir "index.config.js"
Set-Content -Path $configJsPath -Value "const config = { video: { sites: [] } };`nexport default config;" -Encoding UTF8

# 3. Start Spider server
Write-Host ""
Write-Host "[3/5] Starting Spider server..." -ForegroundColor Yellow

$mainJsPath = Join-Path $nodejsDir "src\main.js"
$stdoutLog = Join-Path $tempDir "server-stdout.log"
$stderrLog = Join-Path $tempDir "server-stderr.log"

$env:NODE_PATH = $nodeModulesDir

# Create wrapper to capture ports
$wrapperJs = Join-Path $tempDir "wrapper.js"
$wrapperContent = @"
const path = require('path');
const http = require('http');

const origListen = http.Server.prototype.listen;
http.Server.prototype.listen = function() {
    var args = Array.prototype.slice.call(arguments);
    var callback = typeof args[args.length - 1] === 'function' ? args[args.length - 1] : null;
    var self = this;
    var newCallback = function() {
        var addr = self.address();
        if (addr) {
            console.log('SERVER_PORT:' + addr.port);
        }
        if (callback) callback.call(self);
    };
    if (callback) {
        args[args.length - 1] = newCallback;
    } else {
        args.push(newCallback);
    }
    return origListen.apply(this, args);
};

globalThis.catServerFactory = function(handle) {
    var port = 0;
    var server = require('http').createServer(function(req, res) {
        handle(req, res);
    });
    server.on('listening', function() {
        port = server.address().port;
        console.log('SPIDER_PORT:' + port);
    });
    return server;
};

globalThis.catDartServerPort = function() { return 0; };

require('$($mainJsPath.Replace('\', '/'))');
"@
Set-Content -Path $wrapperJs -Value $wrapperContent -Encoding UTF8

$proc = Start-Process -FilePath "node" -ArgumentList $wrapperJs -WorkingDirectory $nodejsDir -PassThru -NoNewWindow -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

Start-Sleep -Seconds 3

if ($proc.HasExited) {
    Write-Host "  Server failed to start!" -ForegroundColor Red
    if (Test-Path $stderrLog) { Get-Content $stderrLog | ForEach-Object { Write-Host "  $_" -ForegroundColor Red } }
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Read ports from log
$spiderPort = 0
$mgmtPort = 0
if (Test-Path $stdoutLog) {
    $logLines = Get-Content $stdoutLog -ErrorAction SilentlyContinue
    foreach ($line in $logLines) {
        if ($line -match "SPIDER_PORT:(\d+)") { $spiderPort = [int]$Matches[1] }
        if ($line -match "SERVER_PORT:(\d+)") {
            if ($mgmtPort -eq 0) { $mgmtPort = [int]$Matches[1] }
        }
    }
}

# Load source via management port
if ($mgmtPort -gt 0) {
    Write-Host "  Management port: $mgmtPort" -ForegroundColor Gray
    try {
        $loadBody = "{`"path`":`"$($tempDir.Replace('\','\\'))`"}"
        $loadResult = Invoke-RestMethod -Uri "http://127.0.0.1:$mgmtPort/source/loadPath" -Method POST -ContentType "application/json" -Body $loadBody -TimeoutSec 15
        Write-Host "  Source loaded: $($loadResult | ConvertTo-Json -Compress)" -ForegroundColor Gray
    } catch {
        Write-Host "  Source load failed: $_" -ForegroundColor Yellow
    }
}

# Wait for spider port after loading
Start-Sleep -Seconds 5
if (Test-Path $stdoutLog) {
    $logLines = Get-Content $stdoutLog -ErrorAction SilentlyContinue
    foreach ($line in $logLines) {
        if ($line -match "SPIDER_PORT:(\d+)") { $spiderPort = [int]$Matches[1] }
    }
}

if ($spiderPort -eq 0) {
    Write-Host "  Spider server not started! Check log:" -ForegroundColor Red
    if (Test-Path $stderrLog) { Get-Content $stderrLog -Tail 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red } }
    $proc.Kill()
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "  Spider server started on port: $spiderPort" -ForegroundColor Green

$baseUrl = "http://127.0.0.1:$spiderPort"

# 4. Test each site
Write-Host ""
Write-Host "[4/5] Testing sites..." -ForegroundColor Yellow
Write-Host ""

$config = $null
try {
    $config = Invoke-RestMethod -Uri "$baseUrl/config" -Method GET -TimeoutSec 10
} catch {
    Write-Host "  Failed to get config: $_" -ForegroundColor Red
    $proc.Kill()
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$sites = $config.video.sites
Write-Host "  Found $($sites.Count) sites" -ForegroundColor Green
Write-Host ""

$results = @()

foreach ($site in $sites) {
    $siteKey = $site.key
    $siteName = $site.name
    $siteType = $site.type
    $siteApi = $site.api
    $shortKey = $siteKey -replace "nodejs_", ""
    
    if ($siteApi) {
        $spiderPath = $siteApi
    } else {
        $spiderPath = "/spider/$shortKey/$siteType"
    }
    
    $rInit = "-"
    $rHome = "-"
    $rCategory = "-"
    $rSearch = "-"
    $rDetail = "-"
    $rPlay = "-"
    $rErrors = @()
    $rInfo = @()
    
    Write-Host "  -- $siteName --" -ForegroundColor White -NoNewline
    Write-Host " [$shortKey]" -ForegroundColor DarkGray
    
    # Init
    try {
        Invoke-RestMethod -Uri "$baseUrl$spiderPath/init" -Method POST -ContentType "application/json" -Body "{}" -TimeoutSec 10 | Out-Null
        $rInit = "OK"
    } catch {
        $rInit = "FAIL"
        $rErrors += "Init: $($_.Exception.Message)"
        Write-Host "    Init: FAIL" -ForegroundColor Red
        $results += New-Object PSObject -Property @{Name=$siteName; Key=$shortKey; Init=$rInit; Home=$rHome; Category=$rCategory; Search=$rSearch; Detail=$rDetail; Play=$rPlay; Errors=$rErrors; Info=$rInfo}
        continue
    }
    
    # Home
    $homeResult = $null
    try {
        $homeResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/home" -Method POST -ContentType "application/json" -Body "{}" -TimeoutSec 15
        if ($homeResult.class -and $homeResult.class.Count -gt 0) {
            $rHome = "OK"
            $catNames = ($homeResult.class | ForEach-Object { $_.type_name }) -join ", "
            $rInfo += "Categories: $catNames"
            Write-Host "    Home: OK - $($homeResult.class.Count) categories" -ForegroundColor Green
        } else {
            $rHome = "EMPTY"
            $rErrors += "Home: no categories"
            Write-Host "    Home: no categories" -ForegroundColor Yellow
        }
    } catch {
        $rHome = "FAIL"
        $rErrors += "Home: $($_.Exception.Message)"
        Write-Host "    Home: FAIL" -ForegroundColor Red
    }
    
    # Category
    if ($homeResult -and $homeResult.class -and $homeResult.class.Count -gt 0 -and -not $SkipCategory) {
        $firstCat = $homeResult.class[0]
        $catId = $firstCat.type_id
        $catName = $firstCat.type_name
        
        $filterObj = @{}
        if ($homeResult.filters) {
            $catIdStr = $catId.ToString()
            try {
                $catFilters = $homeResult.filters.PSObject.Properties | Where-Object { $_.Name -eq $catIdStr } | Select-Object -First 1
                if ($catFilters) {
                    foreach ($f in $catFilters.Value) {
                        if ($f.init -and $f.init.ToString() -ne "") {
                            $filterObj[$f.key] = $f.init
                        } elseif ($f.value -and $f.value.Count -gt 0) {
                            $filterObj[$f.key] = $f.value[0].v
                        }
                    }
                }
            } catch {}
        }
        
        $catBody = @{ id = $catId; page = 1; filters = $filterObj } | ConvertTo-Json -Compress -Depth 5
        
        try {
            $catResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/category" -Method POST -ContentType "application/json" -Body $catBody -TimeoutSec 15
            $listCount = 0
            if ($catResult.list) { $listCount = $catResult.list.Count }
            
            if ($listCount -gt 0) {
                $rCategory = "OK($listCount)"
                $rInfo += "Category[$catName]: $listCount items"
                Write-Host "    Category[$catName]: OK - $listCount items" -ForegroundColor Green
            } else {
                # Retry with empty filters
                $emptyBody = "{`"id`":`"$catId`",`"page`":1,`"filters`":{}}"
                try {
                    $retryCat = Invoke-RestMethod -Uri "$baseUrl$spiderPath/category" -Method POST -ContentType "application/json" -Body $emptyBody -TimeoutSec 15
                    $retryCount = 0
                    if ($retryCat.list) { $retryCount = $retryCat.list.Count }
                    if ($retryCount -gt 0) {
                        $rCategory = "OK*($retryCount)"
                        Write-Host "    Category[$catName]: OK (empty filters) - $retryCount items" -ForegroundColor Green
                    } else {
                        $rCategory = "EMPTY"
                        $pc = $catResult.pagecount
                        $rErrors += "Category[$catName]: empty list (pagecount=$pc)"
                        Write-Host "    Category[$catName]: EMPTY! pagecount=$pc" -ForegroundColor Red
                    }
                } catch {
                    $rCategory = "EMPTY"
                    $rErrors += "Category[$catName]: retry failed"
                    Write-Host "    Category[$catName]: retry failed" -ForegroundColor Red
                }
            }
        } catch {
            $rCategory = "FAIL"
            $rErrors += "Category: $($_.Exception.Message)"
            Write-Host "    Category: FAIL" -ForegroundColor Red
        }
    }
    
    # Search
    if (-not $SkipSearch) {
        try {
            $searchBody = "{`"wd`":`"$TestKeyword`",`"page`":1}"
            $searchResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/search" -Method POST -ContentType "application/json" -Body $searchBody -TimeoutSec 20
            $searchCount = 0
            if ($searchResult.list) { $searchCount = $searchResult.list.Count }
            if ($searchCount -gt 0) {
                $rSearch = "OK($searchCount)"
                Write-Host "    Search: OK - $searchCount results" -ForegroundColor Green
            } else {
                $rSearch = "EMPTY"
                Write-Host "    Search: no results" -ForegroundColor Yellow
            }
        } catch {
            $status = ""
            try { $status = [int]$_.Exception.Response.StatusCode } catch {}
            if ($status -eq 404) {
                $rSearch = "N/A"
                Write-Host "    Search: not supported (404)" -ForegroundColor DarkGray
            } else {
                $rSearch = "FAIL"
                $rErrors += "Search: $($_.Exception.Message)"
                Write-Host "    Search: FAIL" -ForegroundColor Red
            }
        }
    }
    
    # Detail & Play
    if (-not $SkipDetail) {
        $testVideoId = $null
        
        if ($searchResult -and $searchResult.list -and $searchResult.list.Count -gt 0) {
            $testVideoId = $searchResult.list[0].vod_id
        } elseif ($catResult -and $catResult.list -and $catResult.list.Count -gt 0) {
            $testVideoId = $catResult.list[0].vod_id
        }
        
        if ($testVideoId) {
            try {
                $detailBody = "{`"id`":`"$testVideoId`"}"
                $detailResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/detail" -Method POST -ContentType "application/json" -Body $detailBody -TimeoutSec 15
                if ($detailResult.list -and $detailResult.list.Count -gt 0) {
                    $detail = $detailResult.list[0]
                    $playFrom = 0
                    if ($detail.vod_play_from) { $playFrom = ($detail.vod_play_from -split '\$\$\$').Count }
                    $rDetail = "OK($playFrom src)"
                    Write-Host "    Detail: OK - $playFrom sources" -ForegroundColor Green
                    
                    # Play
                    if ($detail.vod_play_url) {
                        $firstEp = ($detail.vod_play_url -split '#')[0]
                        $epUrl = $firstEp
                        if ($firstEp -match '\$\$\$') { $epUrl = ($firstEp -split '\$\$\$')[-1] }
                        $playFlag = ""
                        if ($detail.vod_play_from) { $playFlag = ($detail.vod_play_from -split '\$\$\$')[0] }
                        
                        try {
                            $playBody = "{`"flag`":`"$playFlag`",`"id`":$(ConvertTo-Json $epUrl -Compress)}"
                            $playResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/play" -Method POST -ContentType "application/json" -Body $playBody -TimeoutSec 15
                            if ($playResult.url -or $playResult.parse) {
                                $rPlay = "OK"
                                $urlPreview = ""
                                if ($playResult.url) { $urlPreview = $playResult.url.Substring(0, [Math]::Min(60, $playResult.url.Length)) }
                                Write-Host "    Play: OK - $urlPreview..." -ForegroundColor Green
                            } else {
                                $rPlay = "EMPTY"
                                Write-Host "    Play: no URL" -ForegroundColor Yellow
                            }
                        } catch {
                            $rPlay = "FAIL"
                            $rErrors += "Play: $($_.Exception.Message)"
                            Write-Host "    Play: FAIL" -ForegroundColor Red
                        }
                    }
                } else {
                    $rDetail = "EMPTY"
                    Write-Host "    Detail: empty" -ForegroundColor Yellow
                }
            } catch {
                $rDetail = "FAIL"
                $rErrors += "Detail: $($_.Exception.Message)"
                Write-Host "    Detail: FAIL" -ForegroundColor Red
            }
        } else {
            Write-Host "    Detail: skipped (no test ID)" -ForegroundColor DarkGray
        }
    }
    
    $results += New-Object PSObject -Property @{Name=$siteName; Key=$shortKey; Init=$rInit; Home=$rHome; Category=$rCategory; Search=$rSearch; Detail=$rDetail; Play=$rPlay; Errors=$rErrors; Info=$rInfo}
    Write-Host ""
}

# 5. Report
Write-Host "[5/5] Diagnostic Report" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Cyan

$initOK = ($results | Where-Object { $_.Init -eq "OK" }).Count
$homeOK = ($results | Where-Object { $_.Home -eq "OK" }).Count
$catOK = ($results | Where-Object { $_.Category -like "OK*" }).Count
$searchOK = ($results | Where-Object { $_.Search -like "OK*" }).Count
$detailOK = ($results | Where-Object { $_.Detail -like "OK*" }).Count
$playOK = ($results | Where-Object { $_.Play -eq "OK" }).Count
$total = $results.Count

Write-Host ""
Write-Host "  Total sites: $total" -ForegroundColor White
Write-Host "  Init:     $initOK / $total" -ForegroundColor $(if ($initOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Home:     $homeOK / $total" -ForegroundColor $(if ($homeOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Category: $catOK / $total" -ForegroundColor $(if ($catOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Search:   $searchOK / $total" -ForegroundColor $(if ($searchOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Detail:   $detailOK / $total" -ForegroundColor $(if ($detailOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Play:     $playOK / $total" -ForegroundColor $(if ($playOK -eq $total) {"Green"} else {"Yellow"})

# Problem sites
$problemSites = $results | Where-Object { $_.Errors.Count -gt 0 }
if ($problemSites) {
    Write-Host ""
    Write-Host "  Problem sites:" -ForegroundColor Red
    foreach ($s in $problemSites) {
        Write-Host "    $($s.Name) [$($s.Key)]" -ForegroundColor Yellow
        foreach ($e in $s.Errors) {
            Write-Host "      - $e" -ForegroundColor DarkGray
        }
    }
}

# Empty category sites
$emptyCat = $results | Where-Object { $_.Category -eq "EMPTY" }
if ($emptyCat) {
    Write-Host ""
    Write-Host "  Empty category sites:" -ForegroundColor Yellow
    foreach ($s in $emptyCat) {
        Write-Host "    $($s.Name) [$($s.Key)]" -ForegroundColor DarkGray
    }
}

# Save report
$reportPath = Join-Path $scriptDir "diagnostic-report.txt"
$reportLines = @()
$reportLines += "TVBox Diagnostic Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$reportLines += "Source: $SourceUrl"
$reportLines += "=" * 80
$reportLines += ""
$reportLines += "Summary: Total=$total | Init=$initOK | Home=$homeOK | Category=$catOK | Search=$searchOK | Detail=$detailOK | Play=$playOK"
$reportLines += ""
$reportLines += "{0,-25} {1,-15} {2,-8} {3,-8} {4,-12} {5,-12} {6,-12} {7,-8}" -f "Site", "Key", "Init", "Home", "Category", "Search", "Detail", "Play"
$reportLines += "-" * 80

foreach ($r in $results) {
    $reportLines += "{0,-25} {1,-15} {2,-8} {3,-8} {4,-12} {5,-12} {6,-12} {7,-8}" -f $r.Name, $r.Key, $r.Init, $r.Home, $r.Category, $r.Search, $r.Detail, $r.Play
    if ($r.Errors.Count -gt 0) {
        foreach ($e in $r.Errors) {
            $reportLines += "  ERROR: $e"
        }
    }
    if ($r.Info.Count -gt 0) {
        foreach ($i in $r.Info) {
            $reportLines += "  INFO: $i"
        }
    }
}

$reportLines | Out-File -FilePath $reportPath -Encoding utf8
Write-Host ""
Write-Host "  Report saved: $reportPath" -ForegroundColor Cyan

# Cleanup
Write-Host ""
Write-Host "  Cleaning up..." -ForegroundColor Gray
$proc.Kill()
Start-Sleep -Milliseconds 500
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  Diagnostic complete!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Cyan
