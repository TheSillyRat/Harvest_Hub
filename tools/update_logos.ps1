Add-Type -AssemblyName System.Drawing

function Resize-And-Save {
    param(
        [string]$sourcePath,
        [string]$destPath,
        [int]$width,
        [int]$height,
        [string]$format = "Png"
    )

    $dir = Split-Path -Parent $destPath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $src = [System.Drawing.Image]::FromFile($sourcePath)
    $dest = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $dest.SetResolution(72, 72)

    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($src, 0, 0, $width, $height)

    if ($format -eq "Jpeg") {
        $dest.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    } else {
        $dest.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }

    $g.Dispose()
    $dest.Dispose()
    $src.Dispose()
    Write-Host "Created: $destPath ($width x $height)"
}

$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
$repoRoot = (Resolve-Path "$root\..").Path

Write-Host "Repo Root: $repoRoot"

$sizes = @(
    @{ Dir = "mipmap-mdpi"; W = 48; H = 48 },
    @{ Dir = "mipmap-hdpi"; W = 72; H = 72 },
    @{ Dir = "mipmap-xhdpi"; W = 96; H = 96 },
    @{ Dir = "mipmap-xxhdpi"; W = 144; H = 144 },
    @{ Dir = "mipmap-xxxhdpi"; W = 192; H = 192 }
)

# 1. Admin App Icon
$adminSrc = Join-Path $repoRoot "Logo_Admin_App.png"
Write-Host "`n=== 1. Generating Admin App Launcher Icons ==="
foreach ($s in $sizes) {
    $out = Join-Path $repoRoot "apps\admin_app\android\app\src\main\res\$($s.Dir)\ic_launcher.png"
    Resize-And-Save -sourcePath $adminSrc -destPath $out -width $s.W -height $s.H
}

# 2. Customer App Icon
$customerSrc = Join-Path $repoRoot "Logo_Customer_App.png"
Write-Host "`n=== 2. Generating Customer App Launcher Icons ==="
foreach ($s in $sizes) {
    $out = Join-Path $repoRoot "apps\customer_app\android\app\src\main\res\$($s.Dir)\ic_launcher.png"
    Resize-And-Save -sourcePath $customerSrc -destPath $out -width $s.W -height $s.H
}

# 3. Farmer App Icon
$farmerSrc = Join-Path $repoRoot "Logo_Farmer_App.png"
Write-Host "`n=== 3. Generating Farmer App Launcher Icons ==="
foreach ($s in $sizes) {
    $out = Join-Path $repoRoot "apps\farmer_app\android\app\src\main\res\$($s.Dir)\ic_launcher.png"
    Resize-And-Save -sourcePath $farmerSrc -destPath $out -width $s.W -height $s.H
}

# 4. Internal Logo (Logo_HarvestHub.png)
$harvestHubSrc = Join-Path $repoRoot "Logo_HarvestHub.png"
Write-Host "`n=== 4. Updating Internal Logos in packages/harvesthub_core ==="
$coreImagesDir = Join-Path $repoRoot "packages\harvesthub_core\assets\images"

# Copy Logo_HarvestHub.png directly
Copy-Item -Path $harvestHubSrc -Destination (Join-Path $coreImagesDir "Logo_HarvestHub.png") -Force
Write-Host "Copied Logo_HarvestHub.png to $coreImagesDir\Logo_HarvestHub.png"

# Also update CustomerLogo.jpg and Admin_Logo.jpg for full compatibility
Resize-And-Save -sourcePath $harvestHubSrc -destPath (Join-Path $coreImagesDir "CustomerLogo.jpg") -width 512 -height 512 -format "Jpeg"
Resize-And-Save -sourcePath $harvestHubSrc -destPath (Join-Path $coreImagesDir "Admin_Logo.jpg") -width 512 -height 512 -format "Jpeg"

Write-Host "`n=== All Logos Successfully Generated! ==="
