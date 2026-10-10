param(
  [int[]]$CtxList = @(4096,8192,16384,32768,65536,131072,262144),
  [int]$Threads = 6,
  [int]$ProbeTokens = 8192,
  [int]$GenTokens = 48
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe  = Join-Path $root "prism-llama\llama-server.exe"
$model = Join-Path $root "Ternary-Bonsai-2-27B-Uncensored-Heretic-PQ2_0.gguf"
$tmp  = Join-Path $env:TEMP "bonsai-bench2"
if (-not (Test-Path -LiteralPath $tmp)) { New-Item -ItemType Directory -Path $tmp | Out-Null }
$csv = Join-Path $tmp "result.csv"

function Kill-Srv { Get-Process -Name "llama-server" -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep -Seconds 4 }
function Get-Vram {
  $p = Get-Process -Name "llama-server" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $p) { return 0 }
  try {
    $s = Get-Counter '\GPU Process Memory(*)\Dedicated Usage' -ErrorAction Stop | Select-Object -ExpandProperty CounterSamples |
         Where-Object { $_.InstanceName -like "*pid_$($p.Id)*" }
    if ($s) { return [math]::Round((($s | Measure-Object CookedValue -Sum).Sum)/1GB,2) }
  } catch {}
  return 0
}
function Get-Field($err, $pattern) {
  $m = Select-String -LiteralPath $err -Pattern $pattern | Select-Object -Last 1
  if ($m -and $m.Line -match '([\d\.]+)\s+tokens per second') { return [double]$Matches[1] }
  return 0
}

Kill-Srv
"ctx,gpu_layers,kv_mib,vram_gb,ram_gb,load_s,pp_tok_s,pp_tokens,tg_tok_s,gen_tokens,note" | Set-Content -LiteralPath $csv

$unit = "The quick brown fox jumps over the lazy dog near the river bank. "

foreach ($ctx in $CtxList) {
  Write-Host "=== ctx=$ctx ==="
  Kill-Srv
  $err = Join-Path $tmp "b$ctx.err"
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process -FilePath $exe -WorkingDirectory (Join-Path $root "prism-llama") `
        -ArgumentList @("-m","`"$model`"","-fa","on","-c","$ctx","-np","1","-t","$Threads","--port","18098","--no-webui") `
        -RedirectStandardError $err -RedirectStandardOutput (Join-Path $tmp "b$ctx.out") -PassThru -NoNewWindow
  $ready = $false
  foreach ($i in 1..200) {
    Start-Sleep -Seconds 2
    try { $null = Invoke-RestMethod -Uri "http://127.0.0.1:18098/health" -TimeoutSec 3; $ready = $true; break } catch {}
    if ($p.HasExited) { break }
  }
  $sw.Stop(); $loadS = [math]::Round($sw.Elapsed.TotalSeconds,1)

  if (-not $ready) {
    $note = (Select-String -LiteralPath $err -Pattern "error loading|bad allocation|failed to|out of memory" | Select-Object -First 1).Line
    if (-not $note) { $note = "no response" }
    $note = ($note -replace '\s+',' ')
    "$ctx,0,0,0,0,$loadS,0,0,0,0,FAIL: $note" | Add-Content -LiteralPath $csv
    Write-Host "  FAIL: $note"
    continue
  }

  $gpuLayers = 0
  $gl = Select-String -LiteralPath $err -Pattern "offloaded (\d+)/(\d+) layers to GPU" | Select-Object -Last 1
  if ($gl -and $gl.Line -match 'offloaded (\d+)/') { $gpuLayers = [int]$Matches[1] }
  $kvMib = 0
  $kv = Select-String -LiteralPath $err -Pattern "KV buffer size =\s+([\d\.]+) MiB|size =\s+([\d\.]+) MiB \(\s+\d+ cells" | Select-Object -Last 1
  if ($kv) {
    $ms = [regex]::Matches($kv.Line, '([\d\.]+) MiB') | ForEach-Object { [double]$_.Groups[1].Value }
    if ($ms.Count -ge 2) { $kvMib = [math]::Round($ms[1]) }
  }
  $vram = Get-Vram
  $proc = Get-Process -Id $p.Id
  $ram = [math]::Round($proc.WorkingSet64/1GB,2)

  $reps = [math]::Max(4, [math]::Floor($ProbeTokens/14))
  $body = @{ model="local"; messages=@(@{role="user"; content=("Reply with the single word: ack`n`n" + ($unit*$reps))}); max_tokens=$GenTokens; reasoning_effort="low"; temperature=0.7; top_p=0.8; top_k=20 } | ConvertTo-Json -Depth 6
  try { $null = Invoke-RestMethod -Uri "http://127.0.0.1:18098/v1/chat/completions" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 2400 }
  catch { Write-Host "  REQ ERROR: $($_.Exception.Message)" }

  $ppTok = 0
  $pp = Select-String -LiteralPath $err -Pattern "prompt eval time" | Select-Object -Last 1
  if ($pp -and $pp.Line -match 'ms /\s+(\d+) tokens') { $ppTok = [int]$Matches[1] }
  $ppTs = Get-Field $err "prompt eval time"
  $tgTs = Get-Field $err "^\S+ I slot print_timing: id\s+\d+ \| task \d+ \|\s+eval time"
  $genN = 0
  $gg = Select-String -LiteralPath $err -Pattern "eval time" | Select-Object -Last 1
  if ($gg -and $gg.Line -match 'ms /\s+(\d+) tokens') { $genN = [int]$Matches[1] }

  $vram = Get-Vram
  $proc.Refresh(); $ram = [math]::Round($proc.WorkingSet64/1GB,2)

  "$ctx,$gpuLayers,$kvMib,$vram,$ram,$loadS,$([math]::Round($ppTs,1)),$ppTok,$([math]::Round($tgTs,2)),$genN,ok" | Add-Content -LiteralPath $csv
  Write-Host "  gpu=$gpuLayers kv=${kvMib}MiB vram=$vram ram=$ram load=${loadS}s pp=$([math]::Round($ppTs,1)) ($ppTok tok) tg=$([math]::Round($tgTs,2)) ($genN tok)"
}

Kill-Srv
Write-Host "done -> $csv"
