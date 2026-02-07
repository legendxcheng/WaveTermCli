param(
    [switch]$Build,
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"

function Assert-CleanRepo {
    param(
        [string]$Path,
        [string]$Label
    )
    Push-Location $Path
    try {
        $status = git status --porcelain
        if ($status) {
            throw "$Label has uncommitted changes:`n$status"
        }
    } finally {
        Pop-Location
    }
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$submodulePath = Join-Path $root "waveterm"

if (-not (Test-Path $submodulePath)) {
    throw "waveterm submodule path not found: $submodulePath"
}

Assert-CleanRepo -Path $root -Label "Root repo"
Assert-CleanRepo -Path $submodulePath -Label "waveterm submodule"

Push-Location $submodulePath
try {
    $upstreamUrl = git remote get-url upstream 2>$null
    if (-not $upstreamUrl) {
        throw "Missing 'upstream' remote in waveterm submodule."
    }
    git fetch upstream
    git checkout custom
    git rebase upstream/main
    if (-not $SkipPush) {
        git push
    }
} finally {
    Pop-Location
}

Push-Location $root
try {
    git add waveterm
    $hasChanges = git diff --cached --quiet
    if (-not $hasChanges) {
        git commit -m "Update waveterm submodule"
        if (-not $SkipPush) {
            git push
        }
    } else {
        Write-Host "No submodule pointer changes to commit."
    }
} finally {
    Pop-Location
}

if ($Build) {
    Push-Location $submodulePath
    try {
        task package
    } finally {
        Pop-Location
    }
}
