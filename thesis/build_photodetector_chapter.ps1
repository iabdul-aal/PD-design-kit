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

$target = "chapter_photodetector_combine"

Push-Location $PSScriptRoot
try {
    & $pdflatex.Source -interaction=nonstopmode "$target.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "pdflatex pass 1 failed with exit code $LASTEXITCODE."
    }

    & $biber.Source $target
    if ($LASTEXITCODE -ne 0) {
        throw "biber failed with exit code $LASTEXITCODE."
    }

    & $pdflatex.Source -interaction=nonstopmode "$target.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "pdflatex pass 2 failed with exit code $LASTEXITCODE."
    }

    & $pdflatex.Source -interaction=nonstopmode "$target.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "pdflatex pass 3 failed with exit code $LASTEXITCODE."
    }

    if (Test-Path "$target.pdf") {
        Move-Item -LiteralPath "$target.pdf" -Destination "photodetector_chapter.pdf" -Force
    }

    # Clean up all auxiliary files, leaving only the PDF and source files
    $extsToRemove = @(
        ".aux", ".bbl", ".bcf", ".blg", ".fdb_latexmk", ".fls", ".log", 
        ".out", ".run.xml", ".synctex.gz", ".toc", ".lof", ".lot", ".nav", ".snm", ".vrb"
    )
    
    Get-ChildItem -Path $PSScriptRoot -File | Where-Object { $_.Extension -in $extsToRemove } | Remove-Item -Force
    
    if (Test-Path -LiteralPath "$PSScriptRoot\sections") {
        Get-ChildItem -Path "$PSScriptRoot\sections" -File | Where-Object { $_.Extension -in $extsToRemove } | Remove-Item -Force
    }
}
finally {
    Pop-Location
}
