param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class SchnitzelIconCrop {
    public static Rectangle Bounds(Bitmap image, Rectangle region) {
        int left = region.Right, top = region.Bottom, right = -1, bottom = -1;
        for (int y = region.Top; y < region.Bottom; y++)
            for (int x = region.Left; x < region.Right; x++)
                if (image.GetPixel(x, y).A > 0) {
                    left = Math.Min(left, x); top = Math.Min(top, y);
                    right = Math.Max(right, x); bottom = Math.Max(bottom, y);
                }
        if (right < left) throw new Exception("Empty icon region");
        if (left == region.Left || top == region.Top || right == region.Right - 1 || bottom == region.Bottom - 1)
            throw new Exception("Icon touches crop boundary: " + region + " / " + Rectangle.FromLTRB(left, top, right + 1, bottom + 1));
        return Rectangle.FromLTRB(left, top, right + 1, bottom + 1);
    }
    public static void Export(Bitmap source, Rectangle bounds, string path) {
        using (var cropped = source.Clone(bounds, PixelFormat.Format32bppArgb))
        using (var output = new Bitmap(384, 384, PixelFormat.Format32bppArgb))
        using (var graphics = Graphics.FromImage(output)) {
            graphics.Clear(Color.Transparent);
            graphics.CompositingMode = CompositingMode.SourceCopy;
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            float scale = 352f / Math.Max(bounds.Width, bounds.Height);
            float width = bounds.Width * scale, height = bounds.Height * scale;
            graphics.DrawImage(cropped, new RectangleF((384 - width) / 2, (384 - height) / 2, width, height), new RectangleF(0, 0, cropped.Width, cropped.Height), GraphicsUnit.Pixel);
            output.Save(path, ImageFormat.Png);
        }
    }
}
'@

# Individually inspected gutters; these are deliberately not equal grid cells.
$regions = @(
    @('Rebirth', 'rebirth', 0, 0, 325, 330),
    @('Index', 'index', 325, 0, 325, 330),
    @('Pets', 'pets', 650, 0, 326, 330),
    @('Crystal', 'auras', 976, 0, 334, 330),
    @('Home', 'my-plot', 1310, 0, 309, 330),
    @('Egg', 'eggs', 0, 330, 325, 325),
    @('Coin', 'money', 325, 330, 313, 325),
    @('Schnitzel', 'schnitzel', 638, 330, 335, 325),
    @('Clock', 'event-timer', 973, 330, 337, 325),
    @('Energy', 'energy', 1310, 330, 309, 325),
    @('Star', 'token-rarities', 0, 655, 325, 316),
    @('Upgrade', 'upgrade', 325, 655, 313, 316),
    @('RebirthCash', 'money-multiplier', 638, 655, 322, 316),
    @('Ticket', 'aura-ticket', 960, 655, 350, 316),
    @('Close', 'close', 1310, 655, 309, 316)
)
$uiPath = Join-Path $ProjectRoot 'assets/ui'
$outputPath = Join-Path $uiPath 'icons'
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
$source = [System.Drawing.Bitmap]::FromFile((Join-Path $uiPath 'schnitzel-ui-icons.png'))
$entries = @()
try {
    foreach ($entry in $regions) {
        $region = [System.Drawing.Rectangle]::new($entry[2], $entry[3], $entry[4], $entry[5])
        $bounds = [SchnitzelIconCrop]::Bounds($source, $region)
        $filename = 'schnitzel-ui-' + $entry[1] + '.png'
        [SchnitzelIconCrop]::Export($source, $bounds, (Join-Path $outputPath $filename))
        $entries += [ordered]@{
            key = $entry[0]; file = "icons/$filename"
            sourceBounds = @($bounds.X, $bounds.Y, $bounds.Width, $bounds.Height)
            size = @(384, 384)
        }
        Write-Output ("{0}: {1}" -f $entry[0], $bounds)
    }
} finally { $source.Dispose() }
$manifest = [ordered]@{ source = 'schnitzel-ui-icons.png'; icons = $entries }
[IO.File]::WriteAllText((Join-Path $uiPath 'icons-manifest.json'), ($manifest | ConvertTo-Json -Depth 6) + "`n", [Text.UTF8Encoding]::new($false))
