# Genera el icono de FitApp: mancuerna lima inclinada sobre fondo oscuro.
# Salidas: assets/icon/icon.png (completo) y assets/icon/icon_fg.png (capa adaptativa).
Add-Type -AssemblyName System.Drawing

$size = 1024
$lime = [System.Drawing.Color]::FromArgb(255, 200, 241, 53)
$limeDark = [System.Drawing.Color]::FromArgb(255, 154, 190, 30)
$bgTop = [System.Drawing.Color]::FromArgb(255, 22, 27, 38)
$bgBottom = [System.Drawing.Color]::FromArgb(255, 9, 12, 18)

function New-Canvas {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    return @($bmp, $g)
}

function Draw-RoundedRect($g, $brush, [double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
    $path.Dispose()
}

function Draw-Dumbbell($g, $scale) {
    $g.TranslateTransform($size / 2, $size / 2)
    $g.RotateTransform(-28)
    $g.ScaleTransform($scale, $scale)

    $limeBrush = New-Object System.Drawing.SolidBrush($lime)
    $darkBrush = New-Object System.Drawing.SolidBrush($limeDark)

    # Barra
    Draw-RoundedRect $g $darkBrush -330 -32 660 64 30
    # Discos exteriores (altos)
    Draw-RoundedRect $g $limeBrush -390 -170 90 340 40
    Draw-RoundedRect $g $limeBrush 300 -170 90 340 40
    # Discos interiores (mas bajos)
    Draw-RoundedRect $g $limeBrush -280 -130 70 260 32
    Draw-RoundedRect $g $limeBrush 210 -130 70 260 32
    # Agarre central
    Draw-RoundedRect $g $limeBrush -70 -46 140 92 42

    $limeBrush.Dispose(); $darkBrush.Dispose()
    $g.ResetTransform()
}

# --- icon.png: fondo + mancuerna ---
$bmp, $g = New-Canvas
$rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $bgTop, $bgBottom, 90.0)
$g.FillRectangle($bgBrush, $rect)
# Resplandor sutil detras de la mancuerna
$glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$glowPath.AddEllipse(112, 112, 800, 800)
$glow = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath)
$glow.CenterColor = [System.Drawing.Color]::FromArgb(46, 200, 241, 53)
$glow.SurroundColors = [System.Drawing.Color]::FromArgb(0, 200, 241, 53)
$g.FillEllipse($glow, 112, 112, 800, 800)
Draw-Dumbbell $g 1.0
New-Item -ItemType Directory -Force "$PSScriptRoot\..\assets\icon" | Out-Null
$bmp.Save("$PSScriptRoot\..\assets\icon\icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $bgBrush.Dispose(); $glow.Dispose()

# --- icon_fg.png: solo mancuerna, transparente, en zona segura (66%) ---
$bmp2, $g2 = New-Canvas
Draw-Dumbbell $g2 0.62
$bmp2.Save("$PSScriptRoot\..\assets\icon\icon_fg.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g2.Dispose(); $bmp2.Dispose()

Write-Output "Iconos generados en assets/icon/"
