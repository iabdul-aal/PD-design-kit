$ErrorActionPreference = "Stop"

$miktexBins = @(
    (Join-Path $env:LOCALAPPDATA "Programs\MiKTeX\miktex\bin\x64"),
    (Join-Path $env:LOCALAPPDATA "Programs\MiKTeX\executables\windows-x64\biber"),
    "C:\Program Files\MiKTeX\miktex\bin\x64"
)

foreach ($bin in $miktexBins) {
    if ((Test-Path -LiteralPath $bin) -and (-not ($env:PATH -split ';' | Where-Object { $_ -eq $bin }))) {
        $env:PATH = "$bin;$env:PATH"
    }
}

$pdflatex = Get-Command pdflatex -ErrorAction SilentlyContinue
$biber = Get-Command biber -ErrorAction SilentlyContinue

if (-not $pdflatex) {
    throw "pdflatex was not found. Install MiKTeX or add it to PATH."
}
if (-not $biber) {
    throw "biber was not found. Install MiKTeX biber or add it to PATH."
}

$artifacts = @(
    "_chapter_photodetector_check.aux",
    "_chapter_photodetector_check.bbl",
    "_chapter_photodetector_check.bcf",
    "_chapter_photodetector_check.blg",
    "_chapter_photodetector_check.fdb_latexmk",
    "_chapter_photodetector_check.fls",
    "_chapter_photodetector_check.log",
    "_chapter_photodetector_check.out",
    "_chapter_photodetector_check.run.xml",
    "_chapter_photodetector_check.synctex.gz",
    "_chapter_photodetector_check.bbl-SAVE-ERROR",
    "_chapter_photodetector_check.bcf-SAVE-ERROR",
    "chapter_photodetector.aux"
)

Push-Location $PSScriptRoot
try {
    & $pdflatex.Source -interaction=nonstopmode "_chapter_photodetector_check.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "pdflatex pass 1 failed with exit code $LASTEXITCODE."
    }

    & $biber.Source "_chapter_photodetector_check"
    if ($LASTEXITCODE -ne 0) {
        throw "biber failed with exit code $LASTEXITCODE."
    }

    & $pdflatex.Source -interaction=nonstopmode "_chapter_photodetector_check.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "pdflatex pass 2 failed with exit code $LASTEXITCODE."
    }

    & $pdflatex.Source -interaction=nonstopmode "_chapter_photodetector_check.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "pdflatex pass 3 failed with exit code $LASTEXITCODE."
    }

    foreach ($artifact in $artifacts) {
        if (Test-Path -LiteralPath $artifact) {
            Remove-Item -LiteralPath $artifact -Force
        }
    }
}
finally {
    Pop-Location
}
