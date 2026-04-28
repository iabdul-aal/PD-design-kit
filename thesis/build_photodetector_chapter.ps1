$ErrorActionPreference = "Stop"

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
    & latexmk -pdf -interaction=nonstopmode -synctex=1 "_chapter_photodetector_check.tex"
    if ($LASTEXITCODE -ne 0) {
        throw "latexmk failed with exit code $LASTEXITCODE."
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
