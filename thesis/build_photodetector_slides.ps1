$ErrorActionPreference = "Stop"

$miktexBins = @(
    (Join-Path $env:LOCALAPPDATA "Programs\MiKTeX\miktex\bin\x64"),
    "C:\Program Files\MiKTeX\miktex\bin\x64"
)

foreach ($bin in $miktexBins) {
    if ((Test-Path -LiteralPath $bin) -and (-not ($env:PATH -split ';' | Where-Object { $_ -eq $bin }))) {
        $env:PATH = "$bin;$env:PATH"
    }
}

$pdflatex = Get-Command pdflatex -ErrorAction SilentlyContinue

if (-not $pdflatex) {
    throw "pdflatex was not found. Install MiKTeX or add it to PATH."
}

$target = "chapter_photodetector_slides"

Push-Location $PSScriptRoot
try {
    & $pdflatex.Source -interaction=nonstopmode "$target.tex"
    & $pdflatex.Source -interaction=nonstopmode "$target.tex"

    if (Test-Path "$target.pdf") {
        Move-Item -LiteralPath "$target.pdf" -Destination "photodetector_slides.pdf" -Force
    }

    # Clean up all auxiliary files, leaving only the PDF and source files
    $extsToRemove = @(
        ".aux", ".bbl", ".bcf", ".blg", ".fdb_latexmk", ".fls", ".log", 
        ".out", ".run.xml", ".synctex.gz", ".toc", ".lof", ".lot", ".nav", ".snm", ".vrb"
    )
    
    Get-ChildItem -Path $PSScriptRoot -File | Where-Object { $_.Extension -in $extsToRemove } | Remove-Item -Force
}
finally {
    Pop-Location
}
