$lines = Get-Content 'd:\PD 2\thesis\sections\sec_metrics.tex'
Write-Host "Before: $($lines.Count) lines"

# Remove verbose Poisson-stats shot-noise derivation (lines 504-558, 0-indexed 503-557)
$before = $lines[0..502]
$transition = @(
    '',
    '\paragraph{Physical origin of shot noise.}',
    'The shot noise PSD follows from the Poissonian statistics of discrete',
    'carrier arrivals at the terminal. Each photon-induced electron-hole pair',
    'is generated independently, giving a white (frequency-independent) PSD:',
    '\begin{equation}',
    '    S_{\mathrm{shot}}(f) = 2q\!\left(I_d + I_{\mathrm{ph}}\right)',
    '    \quad [\si{\ampere\squared\per\hertz}],',
    '    \label{eq:shot}',
    '\end{equation}',
    'where the total current includes both dark and photocurrent contributions.',
    'The factor of two arises from the one-sided spectral density convention.',
    ''
)
$after = $lines[557..($lines.Count-1)]
$result = $before + $transition + $after
$result | Set-Content 'd:\PD 2\thesis\sections\sec_metrics.tex'
Write-Host "After: $($result.Count) lines"
