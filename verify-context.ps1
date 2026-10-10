param(
  [int]$TargetTokens = 30000,
  [int]$GenTokens = 400,
  [int]$TimeoutSec = 900,
  [int]$Port = 18098
)

# Needle-in-a-haystack test for the PrismML Bonsai 2 27B PQ2_0 server.
# Hides a unique code at ~50% depth inside a long prompt and asks for it.
# Pass = the context is genuinely usable at the size you fed it.
#
#   powershell -ExecutionPolicy Bypass -File verify-context.ps1 -TargetTokens 60000

$api = "http://127.0.0.1:$Port"

function Get-TokCount([string]$text) {
  $b = @{ content = $text } | ConvertTo-Json -Compress
  (Invoke-RestMethod -Uri "$api/tokenize" -Method Post -Body $b -ContentType "application/json" -TimeoutSec 600).tokens.Count
}

$props = Invoke-RestMethod -Uri "$api/props" -TimeoutSec 30
Write-Host "server n_ctx = $($props.default_generation_settings.n_ctx)"

$subjects = @("the harbor master","a retired engineer","the librarian","a traveling merchant","the night watchman","a young cartographer","the herbalist","a former pilot","the blacksmith","a wandering scholar")
$verbs    = @("carefully inspected","quietly repaired","often sketched","always counted","never trusted","repeatedly measured","seldom questioned","patiently catalogued","bitterly complained about","cheerfully rebuilt")
$objects  = @("a rusted compass","seven oak crates","an outdated map","a tin of buttons","a cracked lantern","three ledger books","a canvas tarp","an iron kettle","a bundle of rope","a brass sextant")
$places   = @("near the eastern pier","behind the customs house","under the old stone bridge","beside the dry dock","near the northern gate","inside the old mill","beyond the market square","along the southern road","close to the lighthouse")

$rng = [Random]::new(7)
$pool = New-Object 'System.Collections.Generic.List[string]'
for ($i = 0; $i -lt 140; $i++) {
  $parts = New-Object 'string[]' 200
  for ($j = 0; $j -lt 200; $j++) {
    $parts[$j] = "$($subjects[$rng.Next(10)]) $($verbs[$rng.Next(10)]) $($objects[$rng.Next(10)]) $($places[$rng.Next(10)]). "
  }
  $pool.Add(($parts -join ''))
}

$blockTokens = Get-TokCount $pool[0]
Write-Host "1 filler block = $blockTokens tokens"

$code = "KV7" + (Get-Random -Minimum 100000 -Maximum 999999)
$needle = " CRITICAL RECORD - the vault access code for the northern depot is $code - END OF RECORD. "

$nb = [math]::Max(1, [math]::Floor($TargetTokens / $blockTokens))
$half = [math]::Floor($nb / 2)
$pre = (@(0..($half-1))       | ForEach-Object { $pool[$_] }) -join ''
$suf = (@($half..($nb-1))     | ForEach-Object { $pool[$_] }) -join ''

$prompt = "Read the notes, then answer the question.`n`n" + $pre + $needle + $suf + "`n`nQuestion: what is the vault access code for the northern depot? Answer with the code only."

$actual = Get-TokCount $prompt
$depth  = [math]::Round(100.0 * (Get-TokCount $pre) / $actual, 1)

Write-Host ""
Write-Host "prompt tokens : $actual"
Write-Host "needle depth  : $depth%"
Write-Host "expected code : $code"
Write-Host ""

$body = @{ model="local"; messages=@(@{role="user"; content=$prompt}); max_tokens=$GenTokens; reasoning_effort="low"; temperature=0.0; cache_prompt=$false } | ConvertTo-Json -Depth 6 -Compress
$sw = [Diagnostics.Stopwatch]::StartNew()
$answer = ""
$thinking = ""
try {
  $r = Invoke-RestMethod -Uri "$api/v1/chat/completions" -Method Post -Body $body -ContentType "application/json" -TimeoutSec $TimeoutSec
  $msg = $r.choices[0].message
  $answer = "$($msg.content)"
  $thinking = "$($msg.reasoning_content)"
} catch {
  Write-Warning "request failed or timed out after ${TimeoutSec}s"
}
$sw.Stop()

# the model is a thinking model: the code may land in the reasoning block
$passed = ($answer -match [regex]::Escape($code)) -or ($thinking -match [regex]::Escape($code))
$secs = [math]::Round($sw.Elapsed.TotalSeconds, 1)
$ppRate = if ($secs -gt 0) { [math]::Round($actual / $secs, 1) } else { 0 }
Write-Host "answer        : $answer"
Write-Host "prompt rate   : $ppRate tok/s (whole request wall time)"
Write-Host "wall time     : $secs s"
if ($passed) { Write-Host "result        : PASS - needle found at $depth% depth" }
elseif ($answer -or $thinking) { Write-Host "result        : FAIL - context reached, fact lost" }
else { Write-Host "result        : FAIL - no answer, context too slow or too large" }