param(
    [string]$TdRoot = (Split-Path (Split-Path (Get-Command td.exe -ErrorAction Stop).Source -Parent) -Parent),
    [switch]$AllowTimingViolation
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$projectName = 'hx4s20c_hdmi_player_v2'
$runRoot = Join-Path $projectRoot "${projectName}_Runs"
$synthDir = Join-Path $runRoot 'syn_1'
$phyDir = Join-Path $runRoot 'phy_1'
$tdCli = Join-Path $TdRoot 'bin/td_commands_prompt.exe'
$flow = (Join-Path $TdRoot 'doc/scripts/DefaultFlow.tcl').Replace('\', '/')

if (-not (Test-Path -LiteralPath $tdCli)) {
    throw "TD command-line tool not found: $tdCli"
}

New-Item -ItemType Directory -Path $synthDir, $phyDir -Force | Out-Null

$projectText = Get-Content -Raw -LiteralPath (Join-Path $projectRoot "$projectName.al")
[xml]$project = $projectText.Replace('UsedInP&R', 'UsedInP&amp;R')
$topName = $project.Project.TOP_MODULE.MODULE
$runtime = (Get-Date).ToString('s')
$runProjectText = [regex]::Replace(
    $projectText,
    '<Project Version="3" Minor="2" Path="[^"]*">',
    "<Project Version=`"3`" Minor=`"2`" RunTime=`"$runtime`">",
    1
)
$runProjectText = $runProjectText.Replace('<File Path="', '<File Path="../../')
foreach ($runDir in @($synthDir, $phyDir)) {
    $runProjectPath = Join-Path $runDir "$projectName.prj"
    Set-Content -LiteralPath $runProjectPath -Value $runProjectText -Encoding utf8
    $includeDir = Join-Path $runDir 'user_source/hdl_source/include'
    New-Item -ItemType Directory -Path $includeDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'user_source/hdl_source/include/global_def.v') -Destination $includeDir -Force
}
foreach ($stage in @(@('syn', $synthDir), @('phy', $phyDir))) {
    $settings = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "$($stage[0])_settings.cfg")
    $settings = $settings.Replace('set top_model_name {top}', "set top_model_name {$topName}")
    Set-Content -LiteralPath (Join-Path $stage[1] 'settings.cfg') -Value $settings -Encoding ascii
}

function Invoke-TdStage {
    param(
        [string]$StageDirectory,
        [string]$OutputName
    )

    $started = Get-Date
    Push-Location $StageDirectory
    try {
        & $tdCli $flow 2>&1 | Tee-Object -FilePath (Join-Path $StageDirectory 'console.log')
        $output = Join-Path $StageDirectory $OutputName
        if (-not (Test-Path -LiteralPath $output) -or (Get-Item -LiteralPath $output).LastWriteTime -lt $started) {
            throw "TD did not create a fresh $OutputName. See $StageDirectory/console.log"
        }
    } finally {
        Pop-Location
    }
}

Invoke-TdStage -StageDirectory $synthDir -OutputName "${projectName}_gate.db"
Invoke-TdStage -StageDirectory $phyDir -OutputName "${projectName}.bit"

$timingReport = Join-Path $phyDir "${projectName}_pr.timing"
$timingLine = Select-String -LiteralPath $timingReport -Pattern 'SWNS:\s*(-?\d+\.\d+)ns' | Select-Object -First 1
if ($null -eq $timingLine) {
    throw "Final timing status not found: $timingReport"
}
$worstSlack = [double]$timingLine.Matches[0].Groups[1].Value
Write-Output "Bitstream: $(Join-Path $phyDir "${projectName}.bit")"
Write-Output "Final setup WNS: $worstSlack ns"
if ($worstSlack -lt 0 -and -not $AllowTimingViolation) {
    throw 'BitGen completed, but final setup timing has violations.'
}
