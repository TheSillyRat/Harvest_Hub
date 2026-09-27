Add-Type -AssemblyName System.Drawing

function Crop-Resize-Save {
    param(
        [string]$sourcePath,
        [string]$destPath,
        [int]$width,
        [int]$height,
        [int]$cropX,
        [int]$cropY,
        [int]$cropW,
        [int]$cropH,
        [string]$format = "Png"
    )

    $dir = Split-Path -Parent $destPath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $src = [System.Drawing.Bitmap]::FromFile($sourcePath)
    $dest = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $dest.SetResolution(72, 72)

    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $g.Clear([System.Drawing.Color]::Transparent)
    
    $srcRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
    $destRect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
    $g.DrawImage($src, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)

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

# 1. Customer App Icon (Logo_Customer_App.png)
# Square crop tightly around squircle: X=256, Y=151, W=758, H=758
$customerSrc = Join-Path $repoRoot "Logo_Customer_App.png"
Write-Host "`n=== 1. Generating Customer App Launcher Icons ==="
foreach ($s in $sizes) {
    $out = Join-Path $repoRoot "apps\customer_app\android\app\src\main\res\$($s.Dir)\ic_launcher.png"
    Crop-Resize-Save -sourcePath $customerSrc -destPath $out -width $s.W -height $s.H -cropX 256 -cropY 151 -cropW 758 -cropH 758
}

# 2. Admin App Icon (Logo_Admin_App.png)
# Square crop tightly around squircle: X=116, Y=88, W=1032, H=1032
$adminSrc = Join-Path $repoRoot "Logo_Admin_App.png"
Write-Host "`n=== 2. Generating Admin App Launcher Icons ==="
foreach ($s in $sizes) {
    $out = Join-Path $repoRoot "apps\admin_app\android\app\src\main\res\$($s.Dir)\ic_launcher.png"
    Crop-Resize-Save -sourcePath $adminSrc -destPath $out -width $s.W -height $s.H -cropX 116 -cropY 88 -cropW 1032 -cropH 1032
}

# 3. Farmer App Icon (Logo_Farmer_App.png)
# Square crop tightly around squircle: X=164, Y=152, W=926, H=926
$farmerSrc = Join-Path $repoRoot "Logo_Farmer_App.png"
Write-Host "`n=== 3. Generating Farmer App Launcher Icons ==="
foreach ($s in $sizes) {
    $out = Join-Path $repoRoot "apps\farmer_app\android\app\src\main\res\$($s.Dir)\ic_launcher.png"
    Crop-Resize-Save -sourcePath $farmerSrc -destPath $out -width $s.W -height $s.H -cropX 164 -cropY 152 -cropW 926 -cropH 926
}

# 4. Internal Logo (Logo_HarvestHub.png)
# Square crop tightly around lotus+wheat: X=148, Y=0, W=1132, H=1132
$harvestHubSrc = Join-Path $repoRoot "Logo_HarvestHub.png"
Write-Host "`n=== 4. Updating Internal Logos in packages/harvesthub_core ==="
$coreImagesDir = Join-Path $repoRoot "packages\harvesthub_core\assets\images"

Crop-Resize-Save -sourcePath $harvestHubSrc -destPath (Join-Path $coreImagesDir "Logo_HarvestHub.png") -width 512 -height 512 -cropX 148 -cropY 0 -cropW 1132 -cropH 1132
Crop-Resize-Save -sourcePath $harvestHubSrc -destPath (Join-Path $coreImagesDir "CustomerLogo.jpg") -width 512 -height 512 -cropX 148 -cropY 0 -cropW 1132 -cropH 1132 -format "Jpeg"
Crop-Resize-Save -sourcePath $harvestHubSrc -destPath (Join-Path $coreImagesDir "Admin_Logo.jpg") -width 512 -height 512 -cropX 148 -cropY 0 -cropW 1132 -cropH 1132 -format "Jpeg"

Write-Host "`n=== All Logos Successfully Updated with Tight Crop (Full-Image)! ==="
