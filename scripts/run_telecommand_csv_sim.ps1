param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$InputCsv,
    [string]$OutputDir,
    [string]$VivadoBin = 'E:\software\vivado\Vivado\2020.2\bin'
)
$ErrorActionPreference = 'Stop'
if (-not $InputCsv) { $InputCsv = Join-Path $ProjectRoot 'sim/data/telecommand_tx_frames.csv' }
if (-not $OutputDir) { $OutputDir = Join-Path $ProjectRoot 'temp/telecommand_csv_sim' }
$InputCsv = (Resolve-Path -LiteralPath $InputCsv).Path
[IO.Directory]::CreateDirectory($OutputDir) | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
$frames = @(Import-Csv -LiteralPath $InputCsv)
if ($frames.Count -eq 0) { throw 'Input CSV is empty' }
$statusCodes = @{ OK=0; ERR1=1; ERR2=2; ERR3=3; NO_FRAME=4 }
$formatLengths = @{ '39'=9; '5A'=32; '69'=64; '96'=128; 'A5'=256; 'C9'=512 }
$stimulus = [System.Collections.Generic.List[string]]::new()
$seenIds = @{}
foreach ($frame in $frames) {
    if ($frame.frame_id -notmatch '^\d+$' -or $seenIds.ContainsKey($frame.frame_id)) { throw 'Frame IDs must be unique nonnegative integers' }
    $seenIds[$frame.frame_id] = $true
    $frame.expected_status = $frame.expected_status.Trim().ToUpperInvariant()
    if (-not $statusCodes.ContainsKey($frame.expected_status)) { throw "Invalid expected_status: $($frame.expected_status)" }
    $frame.frame_hex = ($frame.frame_hex -replace '\s','').ToUpperInvariant()
    $guide = if ($frame.PSObject.Properties['preamble_hex']) { ($frame.preamble_hex -replace '\s','').ToUpperInvariant() } else { '' }
    if ($guide -ne '' -and $guide -cne ('55'*48)) { throw "Need exactly 48 guide bytes in period $($frame.frame_id)" }
    if ($frame.frame_hex -notmatch '^(?:[0-9A-F]{2})+$') { throw "Invalid hex byte string in frame $($frame.frame_id)" }
    $bytes = @([regex]::Matches($frame.frame_hex,'..') | ForEach-Object { $_.Value })
    if ($bytes.Count -gt 525) { throw "Frame too long: $($frame.frame_id)" }
    if ($frame.expected_status -eq 'OK') {
        if ($bytes.Count -lt 13) { throw 'OK frame too short' }
        $fmt = $bytes[4]
        if (-not $formatLengths.ContainsKey($fmt) -or $bytes.Count -ne 13+$formatLengths[$fmt]) { throw "Invalid OK frame length $($frame.frame_id)" }
        if ($frame.frame_hex.Substring(0,4) -notin @('EB90','146F') -or $frame.frame_hex.Substring(4,4) -ne 'B42E' -or -not $frame.frame_hex.EndsWith('C5C5C5C5C5C5C579')) { throw "Invalid OK frame header/tail $($frame.frame_id)" }
    }
    $wireHex = $guide+$frame.frame_hex
    if ($frame.PSObject.Properties['wire_hex'] -and $frame.wire_hex -ine $wireHex) { throw 'wire_hex must equal preamble_hex + frame_hex' }
    $wireBytes = @([regex]::Matches($wireHex,'..') | ForEach-Object { $_.Value })
    $stimulus.Add("$($frame.frame_id) $($wireBytes.Count) $($statusCodes[$frame.expected_status])")
    $stimulus.Add(($wireBytes -join ' '))
}
$stimulusFile = Join-Path $OutputDir 'telecommand_stimulus.txt'
[IO.File]::WriteAllLines($stimulusFile,$stimulus,[Text.Encoding]::ASCII)
Push-Location $OutputDir
try {
    $sources = @('rtl/rx/telecommand_deframer.v','sim/tb_telecommand_deframer.v','sim/tb_telecommand_deframer_csv.v') | ForEach-Object { Join-Path $ProjectRoot $_ }
    & (Join-Path $VivadoBin 'xvlog.bat') --sv --work xil_defaultlib @sources --log compile.log
    if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }
    foreach ($top in @('tb_telecommand_deframer','tb_telecommand_deframer_csv')) {
        $snapshot = "${top}_snapshot"
        & (Join-Path $VivadoBin 'xelab.bat') "xil_defaultlib.$top" --debug typical --snapshot $snapshot --log "$top.elaborate.log"
        if ($LASTEXITCODE -ne 0) { throw "xelab failed: $top" }
        if ($top -eq 'tb_telecommand_deframer_csv') {
            $waveScript=(Join-Path $PSScriptRoot 'run_telecommand_csv_wave.tcl').Replace('\','/')
            & (Join-Path $VivadoBin 'xsim.bat') $snapshot --tclbatch $waveScript --log "$top.log"
            $marker = 'TB_TELECOMMAND_CSV_PASS'
        } else {
            & (Join-Path $VivadoBin 'xsim.bat') $snapshot --runall --log "$top.log"
            $marker = 'TB_TELECOMMAND_DEFRAMER_PASS'
        }
        if ($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath "$top.log" -SimpleMatch $marker -Quiet)) { throw "Simulation failed: $top" }
    }
} finally { Pop-Location }

# Independently compare actual DUT output with the payload in the source CSV.
$results = @(Import-Csv -LiteralPath (Join-Path $OutputDir 'telecommand_rx_commands.csv'))
$receivedBytes = @(Import-Csv -LiteralPath (Join-Path $OutputDir 'telecommand_rx_bytes.csv'))
$serialBits = @(Import-Csv -LiteralPath (Join-Path $OutputDir 'telecommand_tx_bits.csv'))
$ocTable=@(Import-Csv (Join-Path $ProjectRoot 'sim/data/telecommand_oc_codes.csv'))
$ocByCode=@{}
foreach ($oc in $ocTable) { $ocByCode[$oc.code36_hex.ToUpperInvariant()]=$oc.oc_no }
if ($results.Count -ne $frames.Count) { throw 'Result row count mismatch' }
$byteCursor=0; $bitCursor=0
$comparison = @(for ($i=0; $i -lt $frames.Count; $i++) {
    $sent=$frames[$i]; $got=$results[$i]
    $actualStatus = if ($got.status -eq 'ERROR') { 'ERR'+$got.error_code } else { $got.status }
    $ok = $sent.frame_id -eq $got.frame_id -and $sent.expected_status -eq $actualStatus
    $expectedCommand=''
    if ($sent.expected_status -eq 'OK') {
        $fmt=$sent.frame_hex.Substring(8,2)
        $expectedCommand=$sent.frame_hex.Substring(10,2*$formatLengths[$fmt])
        $ok = $ok -and $got.address_hex -ieq $sent.frame_hex.Substring(4,4) -and $got.format_hex -ieq $fmt -and [int]$got.payload_length -eq $formatLengths[$fmt] -and $got.command_hex -ieq $expectedCommand -and [int]$got.sync_inverted -eq [int]($sent.frame_hex.StartsWith('146F')) -and [int]$got.error_code -eq 0
        $ok = $ok -and $got.sync_hex -ieq $sent.frame_hex.Substring(0,4) -and $got.tail_hex -ieq $sent.frame_hex.Substring($sent.frame_hex.Length-16) -and $got.decoded_frame_id -eq $sent.frame_id
        if ($fmt -eq '39') { $ok=$ok -and $got.direct_command_hex -ieq $expectedCommand }
    } else {
        $ok = $ok -and [string]::IsNullOrEmpty($got.command_hex)
    }
    $guide=if ($sent.PSObject.Properties['preamble_hex']) { ($sent.preamble_hex -replace '\s','').ToUpperInvariant() } else { '' }
    $wireHex=$guide+$sent.frame_hex
    $expectedGuide=if ($wireHex.StartsWith('55'*48)) { '55'*48 } else { '' }
    $guideOk = $got.preamble_hex -ieq $expectedGuide -and [int]$got.preamble_bytes -eq ($expectedGuide.Length/2) -and [int]$got.preamble_detected -eq [int]($expectedGuide.Length -gt 0)
    $ok=$ok -and $guideOk -and $got.received_wire_hex -ieq $wireHex
    $decodedOc=''; $repeatOk=''
    if ($got.status -eq 'OK' -and $got.format_hex -ieq '39') {
        $command=([string]$got.command_hex).ToUpperInvariant()
        $repeatOk=$command.Length -eq 18 -and $command.Substring(0,9) -ceq $command.Substring(9,9)
        if ($repeatOk -and $ocByCode.ContainsKey($command.Substring(0,9))) { $decodedOc=$ocByCode[$command.Substring(0,9)] }
        if ($sent.PSObject.Properties['oc_no'] -and $sent.oc_no -ne '') { $ok=$ok -and $repeatOk -and $decodedOc -eq $sent.oc_no }
    }
    $got | Add-Member -NotePropertyName decoded_oc_no -NotePropertyValue $decodedOc
    $got | Add-Member -NotePropertyName repeat36_match -NotePropertyValue $repeatOk
    $got | Add-Member -NotePropertyName preamble_bits -NotePropertyValue ([int]$got.preamble_bytes*8)
    $hexBytes=@([regex]::Matches($wireHex,'..') | ForEach-Object { $_.Value })
    for ($j=0; $j -lt $hexBytes.Count; $j++) {
        $binary=[Convert]::ToString([Convert]::ToInt32($hexBytes[$j],16),2).PadLeft(8,'0')
        if ($byteCursor -ge $receivedBytes.Count) { throw 'Missing DUT input bytes' }
        $actualByte=$receivedBytes[$byteCursor++]
        if ($actualByte.frame_id -ne $sent.frame_id -or [int]$actualByte.byte_index -ne $j -or $actualByte.hex -ine $hexBytes[$j] -or $actualByte.binary -cne $binary) { throw "Hex/binary byte conversion mismatch frame=$($sent.frame_id) byte=$j" }
        for ($k=0; $k -lt 8; $k++) {
            if ($bitCursor -ge $serialBits.Count) { throw 'Missing serial bits' }
            $actualBit=$serialBits[$bitCursor++]
            if ($actualBit.frame_id -ne $sent.frame_id -or [int]$actualBit.byte_index -ne $j -or [int]$actualBit.bit_index -ne 7-$k -or $actualBit.bit -cne [string]$binary[$k]) { throw "Bit order mismatch frame=$($sent.frame_id) byte=$j" }
        }
    }
    [pscustomobject]@{frame_id=$sent.frame_id;case_name=$sent.case_name;expected_status=$sent.expected_status;actual_status=$actualStatus;expected_oc_no=$sent.oc_no;decoded_oc_no=$decodedOc;preamble_bytes=$got.preamble_bytes;preamble_match=$guideOk;expected_preamble_hex=$expectedGuide;received_preamble_hex=([string]$got.preamble_hex).ToUpperInvariant();expected_wire_hex=$wireHex;received_wire_hex=([string]$got.received_wire_hex).ToUpperInvariant();expected_command_hex=$expectedCommand;decoded_command_hex=([string]$got.command_hex).ToUpperInvariant();match=$ok}
})
if ($byteCursor -ne $receivedBytes.Count -or $bitCursor -ne $serialBits.Count) { throw 'Extra bytes/bits observed' }
$comparison | Export-Csv -LiteralPath (Join-Path $OutputDir 'telecommand_comparison.csv') -NoTypeInformation -Encoding utf8
$results | Export-Csv -LiteralPath (Join-Path $OutputDir 'telecommand_rx_commands.csv') -NoTypeInformation -Encoding utf8
$summary = @(for ($i=0;$i -lt $frames.Count;$i++) {
    $sent=$frames[$i]; $got=$results[$i]; $cmp=$comparison[$i]
    [pscustomobject]@{
        work_period=$sent.frame_id; case_name=$sent.case_name;
        expected_oc_no=$sent.oc_no; decoded_oc_no=$got.decoded_oc_no;
        format_hex=$got.format_hex; payload_bytes=$got.payload_length;
        preamble_detected=$got.preamble_detected; preamble_bytes=$got.preamble_bytes;
        preamble_bits=$got.preamble_bits; preamble_match=$cmp.preamble_match;
        repeat36_match=$got.repeat36_match; status=$cmp.actual_status; all_match=$cmp.match
    }
})
$summary | Export-Csv -LiteralPath (Join-Path $OutputDir 'telecommand_summary.csv') -NoTypeInformation -Encoding utf8
if (@($comparison | Where-Object { -not $_.match }).Count) { throw 'Frame comparison failed; inspect telecommand_comparison.csv' }
Write-Output "TELECOMMAND_CSV_ALL_PASS rows=$($results.Count) bytes=$byteCursor bits=$bitCursor"
Write-Output "Input: $InputCsv"
Write-Output "Results: $OutputDir"
