# TVBox 源诊断工具 (Windows PowerShell)
# 用法: pwsh ./diagnose.ps1 [-SourceUrl URL] [-TestKeyword 关键词] [-Verbose]
# 示例: pwsh ./diagnose.ps1 -TestKeyword "庆余年" -Verbose

param(
    [string]$SourceUrl = "https://9280.kstore.vip/cat/index.js",
    [string]$TestKeyword = "庆余年",
    [switch]$SkipSearch,
    [switch]$SkipCategory,
    [switch]$SkipDetail,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  TVBox 源诊断工具 v1.0" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  源: $SourceUrl" -ForegroundColor Gray
Write-Host "  搜索关键词: $TestKeyword" -ForegroundColor Gray
Write-Host ""

function Invoke-SpiderApi {
    param([string]$Method, [string]$Url, [string]$Body = "{}", [int]$Timeout = 15)
    try {
        $headers = @{ "Content-Type" = "application/json" }
        if ($Method -eq "GET") {
            return Invoke-RestMethod -Uri $Url -Method GET -TimeoutSec $Timeout
        } else {
            return Invoke-RestMethod -Uri $Url -Method POST -Headers $headers -Body $Body -TimeoutSec $Timeout
        }
    } catch {
        throw $_
    }
}

# ============================================================
# 1. 检查环境
# ============================================================
Write-Host "[1/5] 检查环境..." -ForegroundColor Yellow

try {
    $nodeVer = node --version 2>$null
    if ($LASTEXITCODE -ne 0) { throw "not found" }
    Write-Host "  Node.js: $nodeVer" -ForegroundColor Green
} catch {
    Write-Host "  Node.js 未安装! 请从 https://nodejs.org 安装" -ForegroundColor Red
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$nodejsDir = Join-Path $scriptDir "ios\Runner\nodejs-project"
$nodeModulesDir = Join-Path $nodejsDir "node_modules"

if (-not (Test-Path $nodeModulesDir)) {
    Write-Host "  安装 Node.js 依赖..." -ForegroundColor Yellow
    Push-Location $nodejsDir
    npm install --legacy-peer-deps 2>$null
    Pop-Location
    Write-Host "  依赖安装完成" -ForegroundColor Green
} else {
    Write-Host "  依赖已安装" -ForegroundColor Green
}

# ============================================================
# 2. 下载源文件
# ============================================================
Write-Host ""
Write-Host "[2/5] 下载源文件..." -ForegroundColor Yellow

$tempDir = Join-Path $env:TEMP "tvbox-diag-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$indexJsPath = Join-Path $tempDir "index.js"
try {
    Invoke-WebRequest -Uri $SourceUrl -OutFile $indexJsPath -TimeoutSec 30
    $fileSize = (Get-Item $indexJsPath).Length
    Write-Host "  下载完成: $([math]::Round($fileSize/1KB, 1)) KB" -ForegroundColor Green
} catch {
    Write-Host "  下载失败: $_" -ForegroundColor Red
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$configJsPath = Join-Path $tempDir "index.config.js"
"const config = { video: { sites: [] } };`nexport default config;" | Out-File -FilePath $configJsPath -Encoding utf8

# ============================================================
# 3. 启动 Spider 服务器
# ============================================================
Write-Host ""
Write-Host "[3/5] 启动 Spider 服务器..." -ForegroundColor Yellow

$mainJsPath = Join-Path $nodejsDir "src\main.js"
$stdoutLog = Join-Path $tempDir "server-stdout.log"
$stderrLog = Join-Path $tempDir "server-stderr.log"

$env:NODE_PATH = $nodeModulesDir

$proc = Start-Process -FilePath "node" -ArgumentList $mainJsPath -WorkingDirectory $nodejsDir -PassThru -NoNewWindow -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

Start-Sleep -Seconds 2

if ($proc.HasExited) {
    Write-Host "  服务器启动失败!" -ForegroundColor Red
    if (Test-Path $stderrLog) { Get-Content $stderrLog | ForEach-Object { Write-Host "  $_" -ForegroundColor Red } }
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# 读取管理端口
$mgmtPort = 0
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 300
    if (Test-Path $stdoutLog) {
        $logContent = Get-Content $stdoutLog -ErrorAction SilentlyContinue
        # 查找管理服务器端口 - 它监听在随机端口
        break
    }
}

# 管理服务器端口需要从日志或进程信息获取
# 由于 main.js 的管理服务器输出到 stdout，我们读取它
Start-Sleep -Seconds 1

# 直接尝试通过 /source/loadPath 加载源
# 管理端口在 stdout 中，但我们可以通过扫描端口找到它
Write-Host "  查找管理服务器端口..." -ForegroundColor Gray

for ($port = 50000; $port -lt 60000; $port++) {
    # 不现实，改用日志
    break
}

# 从日志读取管理端口
$mgmtPort = 0
if (Test-Path $stdoutLog) {
    $logLines = Get-Content $stdoutLog -ErrorAction SilentlyContinue
    foreach ($line in $logLines) {
        if ($line -match "management server on (\d+)" -or $line -match "listening.*:(\d{4,5})") {
            $mgmtPort = [int]$Matches[1]
        }
    }
}

# 如果找不到管理端口，尝试通过 /check 端点扫描
if ($mgmtPort -eq 0) {
    Write-Host "  从日志未找到端口，尝试扫描..." -ForegroundColor Gray
    # main.js 管理服务器在启动时输出到 sendMessageToNative
    # 但在独立模式下，我们无法获取端口
    # 改用另一种方式：直接修改 main.js 输出端口
}

# 更好的方式：创建一个包装脚本，输出管理端口
$wrapperJs = Join-Path $tempDir "wrapper.js"
@"
const path = require('path');
const http = require('http');

// Monkey-patch server.listen to capture ports
const origListen = http.Server.prototype.listen;
http.Server.prototype.listen = function(...args) {
    const callback = typeof args[args.length - 1] === 'function' ? args[args.length - 1] : null;
    const newCallback = function() {
        const addr = this.address();
        if (addr) {
            const type = addr.family === 'IPv4' ? 'unknown' : 'unknown';
            console.log('SERVER_PORT:' + addr.port);
        }
        if (callback) callback.call(this);
    };
    if (callback) {
        args[args.length - 1] = newCallback;
    } else {
        args.push(newCallback);
    }
    return origListen.apply(this, args);
};

// Override sendMessageToNative
globalThis.catServerFactory = (handle) => {
    let port = 0;
    const server = require('http').createServer((req, res) => {
        handle(req, res);
    });
    server.on('listening', () => {
        port = server.address().port;
        console.log('SPIDER_PORT:' + port);
    });
    return server;
};

globalThis.catDartServerPort = () => 0;

// Load main.js
require('$($mainJsPath.Replace('\', '\\'))');
"@
 | Out-File -FilePath $wrapperJs -Encoding utf8

# 杀掉旧进程
$proc.Kill()
Start-Sleep -Seconds 1

# 用包装脚本重新启动
$proc = Start-Process -FilePath "node" -ArgumentList $wrapperJs -WorkingDirectory $nodejsDir -PassThru -NoNewWindow -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

Start-Sleep -Seconds 3

if ($proc.HasExited) {
    Write-Host "  服务器启动失败!" -ForegroundColor Red
    if (Test-Path $stderrLog) { Get-Content $stderrLog | ForEach-Object { Write-Host "  $_" -ForegroundColor Red } }
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# 从日志读取端口
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

if ($spiderPort -eq 0) {
    Write-Host "  未找到 Spider 端口，尝试加载源..." -ForegroundColor Yellow
}

# 通过管理端口加载源
if ($mgmtPort -gt 0) {
    Write-Host "  管理端口: $mgmtPort" -ForegroundColor Gray
    try {
        $loadBody = @{ path = $tempDir } | ConvertTo-Json
        $loadResult = Invoke-RestMethod -Uri "http://127.0.0.1:$mgmtPort/source/loadPath" -Method POST -ContentType "application/json" -Body $loadBody -TimeoutSec 15
        Write-Host "  源加载结果: $($loadResult | ConvertTo-Json -Compress)" -ForegroundColor Gray
    } catch {
        Write-Host "  源加载失败: $_" -ForegroundColor Yellow
    }
}

# 等待 spider 端口
Start-Sleep -Seconds 3
if (Test-Path $stdoutLog) {
    $logLines = Get-Content $stdoutLog -ErrorAction SilentlyContinue
    foreach ($line in $logLines) {
        if ($line -match "SPIDER_PORT:(\d+)") { $spiderPort = [int]$Matches[1] }
    }
}

if ($spiderPort -eq 0) {
    Write-Host "  Spider 服务器未启动! 检查日志:" -ForegroundColor Red
    if (Test-Path $stderrLog) { Get-Content $stderrLog -Tail 20 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red } }
    $proc.Kill()
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "  Spider 服务器启动成功, 端口: $spiderPort" -ForegroundColor Green

$baseUrl = "http://127.0.0.1:$spiderPort"

# ============================================================
# 4. 获取配置并测试线路
# ============================================================
Write-Host ""
Write-Host "[4/5] 测试线路..." -ForegroundColor Yellow
Write-Host ""

$config = $null
try {
    $config = Invoke-RestMethod -Uri "$baseUrl/config" -Method GET -TimeoutSec 10
} catch {
    Write-Host "  获取配置失败: $_" -ForegroundColor Red
    $proc.Kill()
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$sites = $config.video.sites
Write-Host "  获取到 $($sites.Count) 个线路" -ForegroundColor Green
Write-Host ""

$results = @()
$catResultRef = $null
$searchResultRef = $null

foreach ($site in $sites) {
    $siteKey = $site.key
    $siteName = $site.name
    $siteType = $site.type
    $siteApi = $site.api
    $shortKey = $siteKey -replace "nodejs_", ""
    $spiderPath = if ($siteApi) { $siteApi } else { "/spider/$shortKey/$siteType" }
    
    $result = [ordered]@{
        Name = $siteName
        Key = $shortKey
        Type = $siteType
        Init = "-"
        Home = "-"
        Category = "-"
        Search = "-"
        Detail = "-"
        Play = "-"
        Errors = @()
        Info = @()
    }
    
    Write-Host "  ── $siteName ──" -ForegroundColor White -NoNewline
    Write-Host " [$shortKey]" -ForegroundColor DarkGray
    
    # Init
    try {
        Invoke-RestMethod -Uri "$baseUrl$spiderPath/init" -Method POST -ContentType "application/json" -Body "{}" -TimeoutSec 10 | Out-Null
        $result.Init = "OK"
    } catch {
        $result.Init = "FAIL"
        $result.Errors += "Init: $($_.Exception.Message)"
        Write-Host "    Init: FAIL" -ForegroundColor Red
        $results += [PSCustomObject]$result
        continue
    }
    
    # Home
    $homeResult = $null
    try {
        $homeResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/home" -Method POST -ContentType "application/json" -Body "{}" -TimeoutSec 15
        if ($homeResult.class -and $homeResult.class.Count -gt 0) {
            $result.Home = "OK"
            $catNames = ($homeResult.class | ForEach-Object { $_.type_name }) -join ", "
            $result.Info += "分类: $catNames"
            Write-Host "    Home: OK - $($homeResult.class.Count) 分类" -ForegroundColor Green
            
            if ($Verbose -and $homeResult.filters) {
                foreach ($prop in $homeResult.filters.PSObject.Properties) {
                    $filterNames = ($prop.Value | ForEach-Object { $_.name }) -join ", "
                    Write-Host "      filters[$($prop.Name)]: $filterNames" -ForegroundColor DarkGray
                }
            }
        } else {
            $result.Home = "EMPTY"
            $result.Errors += "Home: 无分类"
            Write-Host "    Home: 无分类" -ForegroundColor Yellow
        }
    } catch {
        $result.Home = "FAIL"
        $result.Errors += "Home: $($_.Exception.Message)"
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
        }
        
        $catBody = @{ id = $catId; page = 1; filters = $filterObj } | ConvertTo-Json -Compress -Depth 5
        
        try {
            $catResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/category" -Method POST -ContentType "application/json" -Body $catBody -TimeoutSec 15
            $listCount = if ($catResult.list) { $catResult.list.Count } else { 0 }
            
            if ($listCount -gt 0) {
                $result.Category = "OK($listCount)"
                $result.Info += "首分类[$catName]: $listCount 条"
                Write-Host "    Category[$catName]: OK - $listCount 条" -ForegroundColor Green
            } else {
                # 尝试空 filters
                $emptyBody = @{ id = $catId; page = 1; filters = @{} } | ConvertTo-Json -Compress
                try {
                    $retryCat = Invoke-RestMethod -Uri "$baseUrl$spiderPath/category" -Method POST -ContentType "application/json" -Body $emptyBody -TimeoutSec 15
                    $retryCount = if ($retryCat.list) { $retryCat.list.Count } else { 0 }
                    if ($retryCount -gt 0) {
                        $result.Category = "OK*($retryCount)"
                        $result.Info += "首分类[$catName](空filters): $retryCount 条"
                        Write-Host "    Category[$catName]: OK (空filters) - $retryCount 条" -ForegroundColor Green
                    } else {
                        $result.Category = "EMPTY"
                        $result.Errors += "Category[$catName]: list为空 (pagecount=$($catResult.pagecount))"
                        Write-Host "    Category[$catName]: list为空! pagecount=$($catResult.pagecount)" -ForegroundColor Red
                    }
                } catch {
                    $result.Category = "EMPTY"
                    $result.Errors += "Category[$catName]: 重试失败"
                    Write-Host "    Category[$catName]: 重试也失败" -ForegroundColor Red
                }
            }
        } catch {
            $result.Category = "FAIL"
            $result.Errors += "Category: $($_.Exception.Message)"
            Write-Host "    Category: FAIL" -ForegroundColor Red
        }
    }
    
    # Search
    if (-not $SkipSearch) {
        try {
            $searchBody = @{ wd = $TestKeyword; page = 1 } | ConvertTo-Json -Compress
            $searchResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/search" -Method POST -ContentType "application/json" -Body $searchBody -TimeoutSec 20
            $searchCount = if ($searchResult.list) { $searchResult.list.Count } else { 0 }
            if ($searchCount -gt 0) {
                $result.Search = "OK($searchCount)"
                Write-Host "    Search: OK - $searchCount 条" -ForegroundColor Green
            } else {
                $result.Search = "EMPTY"
                Write-Host "    Search: 无结果" -ForegroundColor Yellow
            }
        } catch {
            $status = ""
            if ($_.Exception.Response) {
                $status = [int]$_.Exception.Response.StatusCode
            }
            if ($status -eq 404) {
                $result.Search = "N/A"
                Write-Host "    Search: 不支持(404)" -ForegroundColor DarkGray
            } else {
                $result.Search = "FAIL"
                $result.Errors += "Search: $($_.Exception.Message)"
                Write-Host "    Search: FAIL" -ForegroundColor Red
            }
        }
    }
    
    # Detail & Play
    if (-not $SkipDetail) {
        $testVideoId = $null
        $testVideoName = $null
        $detailRef = $null
        
        # 从搜索结果获取
        if ($searchResult -and $searchResult.list -and $searchResult.list.Count -gt 0) {
            $testVideoId = $searchResult.list[0].vod_id
            $testVideoName = $searchResult.list[0].vod_name
        }
        # 从分类结果获取
        elseif ($catResult -and $catResult.list -and $catResult.list.Count -gt 0) {
            $testVideoId = $catResult.list[0].vod_id
            $testVideoName = $catResult.list[0].vod_name
        }
        
        if ($testVideoId) {
            try {
                $detailBody = @{ id = $testVideoId.ToString() } | ConvertTo-Json -Compress
                $detailResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/detail" -Method POST -ContentType "application/json" -Body $detailBody -TimeoutSec 15
                if ($detailResult.list -and $detailResult.list.Count -gt 0) {
                    $detail = $detailResult.list[0]
                    $playFrom = if ($detail.vod_play_from) { ($detail.vod_play_from -split '\$\$\$').Count } else { 0 }
                    $result.Detail = "OK($playFrom src)"
                    Write-Host "    Detail: OK - $playFrom 个播放源" -ForegroundColor Green
                    
                    # Play
                    if ($detail.vod_play_url) {
                        $firstEp = ($detail.vod_play_url -split '#')[0]
                        $epUrl = if ($firstEp -match '\$\$\$') { ($firstEp -split '\$\$\$')[-1] } else { $firstEp }
                        $epName = if ($firstEp -match '\$\$\$') { ($firstEp -split '\$\$\$')[0] } else { "" }
                        $playFlag = if ($detail.vod_play_from) { ($detail.vod_play_from -split '\$\$\$')[0] } else { "" }
                        
                        try {
                            $playBody = @{ flag = $playFlag; id = $epUrl } | ConvertTo-Json -Compress
                            $playResult = Invoke-RestMethod -Uri "$baseUrl$spiderPath/play" -Method POST -ContentType "application/json" -Body $playBody -TimeoutSec 15
                            if ($playResult.url -or $playResult.parse) {
                                $result.Play = "OK"
                                $urlPreview = if ($playResult.url) { $playResult.url.Substring(0, [Math]::Min(60, $playResult.url.Length)) } else { "parse" }
                                Write-Host "    Play: OK - $urlPreview..." -ForegroundColor Green
                            } else {
                                $result.Play = "EMPTY"
                                Write-Host "    Play: 无播放URL" -ForegroundColor Yellow
                            }
                        } catch {
                            $result.Play = "FAIL"
                            $result.Errors += "Play: $($_.Exception.Message)"
                            Write-Host "    Play: FAIL" -ForegroundColor Red
                        }
                    }
                } else {
                    $result.Detail = "EMPTY"
                    Write-Host "    Detail: 无详情" -ForegroundColor Yellow
                }
            } catch {
                $result.Detail = "FAIL"
                $result.Errors += "Detail: $($_.Exception.Message)"
                Write-Host "    Detail: FAIL" -ForegroundColor Red
            }
        } else {
            Write-Host "    Detail: 跳过(无测试ID)" -ForegroundColor DarkGray
        }
    }
    
    $results += [PSCustomObject]$result
    Write-Host ""
}

# ============================================================
# 5. 生成报告
# ============================================================
Write-Host "[5/5] 诊断报告" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Cyan

$initOK = ($results | Where-Object { $_.Init -eq "OK" }).Count
$homeOK = ($results | Where-Object { $_.Home -eq "OK" }).Count
$catOK = ($results | Where-Object { $_.Category -like "OK*" }).Count
$searchOK = ($results | Where-Object { $_.Search -like "OK*" }).Count
$detailOK = ($results | Where-Object { $_.Detail -like "OK*" }).Count
$playOK = ($results | Where-Object { $_.Play -eq "OK" }).Count
$total = $results.Count

Write-Host ""
Write-Host "  总线路: $total" -ForegroundColor White
Write-Host "  Init:     $initOK / $total" -ForegroundColor $(if ($initOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Home:     $homeOK / $total" -ForegroundColor $(if ($homeOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Category: $catOK / $total" -ForegroundColor $(if ($catOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Search:   $searchOK / $total" -ForegroundColor $(if ($searchOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Detail:   $detailOK / $total" -ForegroundColor $(if ($detailOK -eq $total) {"Green"} else {"Yellow"})
Write-Host "  Play:     $playOK / $total" -ForegroundColor $(if ($playOK -eq $total) {"Green"} else {"Yellow"})

# 问题线路
$problemSites = $results | Where-Object { $_.Errors.Count -gt 0 }
if ($problemSites) {
    Write-Host ""
    Write-Host "  ⚠️ 问题线路:" -ForegroundColor Red
    foreach ($s in $problemSites) {
        Write-Host "    $($s.Name) [$($s.Key)]" -ForegroundColor Yellow
        foreach ($e in $s.Errors) {
            Write-Host "      - $e" -ForegroundColor DarkGray
        }
    }
}

# Category 为空的线路
$emptyCat = $results | Where-Object { $_.Category -eq "EMPTY" }
if ($emptyCat) {
    Write-Host ""
    Write-Host "  📋 分类内容为空的线路:" -ForegroundColor Yellow
    foreach ($s in $emptyCat) {
        Write-Host "    $($s.Name) [$($s.Key)]" -ForegroundColor DarkGray
    }
}

# 保存报告
$reportPath = Join-Path $scriptDir "diagnostic-report.txt"
$reportLines = @()
$reportLines += "TVBox 源诊断报告 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$reportLines += "源: $SourceUrl"
$reportLines += "=" * 80
$reportLines += ""
$reportLines += "统计: 总=$total | Init=$initOK | Home=$homeOK | Category=$catOK | Search=$searchOK | Detail=$detailOK | Play=$playOK"
$reportLines += ""
$reportLines += "{0,-20} {1,-12} {2,-6} {3,-8} {4,-10} {5,-10} {6,-10} {7,-8}" -f "线路", "Key", "Type", "Init", "Home", "Category", "Search", "Detail", "Play"
$reportLines += "-" * 80

foreach ($r in $results) {
    $reportLines += "{0,-20} {1,-12} {2,-6} {3,-8} {4,-10} {5,-10} {6,-10} {7,-8}" -f $r.Name, $r.Key, $r.Type, $r.Init, $r.Home, $r.Category, $r.Search, $r.Detail
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
Write-Host "  报告已保存: $reportPath" -ForegroundColor Cyan

# 清理
Write-Host ""
Write-Host "  清理..." -ForegroundColor Gray
$proc.Kill()
Start-Sleep -Milliseconds 500
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  诊断完成!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
