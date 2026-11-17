param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$VivadoBin = 'E:\software\vivado\Vivado\2020.2\bin',
    [string]$SupervisorFile,
    [string]$TbRoot,
    [string]$OutputDir,
    [string[]]$Tests = @('tb_DTTL_PD_Saturation', 'tb_DTTL_Supervisor', 'tb_DTTL_Restart', 'tb_DTTL_HalfCycle')
)
$ErrorActionPreference = 'Stop'
if (-not $SupervisorFile) { $SupervisorFile = Join-Path $ProjectRoot 'rtl/rx/dttl/DTTL_Supervisor.v' }
if (-not $TbRoot) { $TbRoot = Join-Path $ProjectRoot 'sim' }
if (-not $OutputDir) { $OutputDir = Join-Path $ProjectRoot 'temp/dttl_supervisor_sim' }
$divider = Join-Path $ProjectRoot 'build/ip_generated/div_gen_0/div_gen_0_sim_netlist.v'
if (-not (Test-Path -LiteralPath $divider)) { throw "Run scripts/run_batch.bat create_project (fresh clone only), then scripts/run_batch.bat prepare_dttl_sim to generate: $divider" }
[System.IO.Directory]::CreateDirectory($OutputDir) | Out-Null
Push-Location $OutputDir
try {
    $sources = @($SupervisorFile)
    foreach ($name in @('DTTL_Top','DTTL_NCO','DTTL_Integrator','DTTL_PD','DTTL_Loop_Filter')) {
        $sources += Join-Path $ProjectRoot "rtl/rx/dttl/$name.v"
    }
    $sources += $divider
    $sources += Join-Path $TbRoot 'tb_DTTL_Supervisor.v'
    $sources += Join-Path $TbRoot 'tb_DTTL_Restart.v'
    $sources += Join-Path $TbRoot 'tb_DTTL_HalfCycle.v'
    $sources += Join-Path $TbRoot 'tb_DTTL_MixedStream.v'
    $sources += Join-Path $TbRoot 'tb_DTTL_PD_Saturation.v'
    $sources += Join-Path (Split-Path -Parent $VivadoBin) 'data/verilog/src/glbl.v'
    & (Join-Path $VivadoBin 'xvlog.bat') --sv --work xil_defaultlib @sources --log compile.log
    if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }
    foreach ($top in $Tests) {
        $snapshot = "${top}_snapshot"
        & (Join-Path $VivadoBin 'xelab.bat') "xil_defaultlib.$top" xil_defaultlib.glbl -L unisims_ver -L unimacro_ver --mt 4 --debug typical --snapshot $snapshot --log "$top.elaborate.log"
        if ($LASTEXITCODE -ne 0) { throw "xelab failed: $top" }
        if ($top -eq 'tb_DTTL_HalfCycle' -or $top -eq 'tb_DTTL_MixedStream') {
            $waveBase = if ($top -eq 'tb_DTTL_HalfCycle') { 'halfcycle' } else { 'mixed_stream' }
            $waveScript = (Join-Path $PSScriptRoot "dttl_${waveBase}_wave.tcl").Replace('\', '/')
            & (Join-Path $VivadoBin 'xsim.bat') $snapshot --tclbatch $waveScript --wdb "$waveBase.wdb" --log "$top.log"
        } else {
            & (Join-Path $VivadoBin 'xsim.bat') $snapshot --runall --log "$top.log"
        }
        if ($LASTEXITCODE -ne 0) { throw "xsim failed: $top" }
        $marker = switch ($top) {
            'tb_DTTL_PD_Saturation' { 'DTTL_PD_SATURATION_TEST_PASS' }
            'tb_DTTL_Supervisor' { 'DTTL_SUPERVISOR_TEST_PASS' }
            'tb_DTTL_Restart' { 'DTTL_RESTART_TEST_PASS' }
            'tb_DTTL_HalfCycle' { 'DTTL_HALFCYCLE_TEST_PASS' }
            'tb_DTTL_MixedStream' { 'DTTL_MIXED_STREAM_TEST_PASS' }
        }
        if (-not (Select-String -LiteralPath "$top.log" -SimpleMatch $marker -Quiet)) {
            throw "Simulation did not reach its PASS marker: $top"
        }
    }
    Write-Output 'DTTL_SELECTED_TESTS_PASS'
}
finally {
    Pop-Location
}
