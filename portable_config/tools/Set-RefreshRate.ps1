# Set-RefreshRate.ps1 - set resolution/refresh via Win32 ChangeDisplaySettingsEx. No external tools.
# Usage: Set-RefreshRate.ps1 -Width 1920 -Height 1080 -Rate 24 -DeviceName '\\.\DISPLAY1'

param(
    [Parameter(Mandatory=$true)][int]$Width,
    [Parameter(Mandatory=$true)][int]$Height,
    [Parameter(Mandatory=$true)][int]$Rate,
    [Parameter(Mandatory=$true)][string]$DeviceName,
    [int]$BitDepth = 32
)

$signature = @'
using System;
using System.Runtime.InteropServices;

public class DisplayHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        // No padding here: offset 104 is already 4-aligned, so dmBitsPerPel starts immediately.
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
    public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [DllImport("user32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
    public static extern int ChangeDisplaySettingsEx(string deviceName, ref DEVMODE devMode, IntPtr hwnd, int flags, IntPtr param);
}
'@

Add-Type -TypeDefinition $signature -ErrorAction Stop

$ENUM_CURRENT_SETTINGS = -1
$CDS_UPDATEREGISTRY = 0x01
$DM_BITSPERPEL = 0x00040000
$DM_PELSWIDTH = 0x00080000
$DM_PELSHEIGHT = 0x00100000
$DM_DISPLAYFREQUENCY = 0x00400000

# DEVMODE must be exactly 156 bytes - else the mode request corrupts to BADMODE.
$structSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type]"DisplayHelper+DEVMODE")
if ($structSize -ne 156) {
    Write-Error "DEVMODE struct is $structSize bytes, expected exactly 156."
    exit 1
}

$dm = New-Object DisplayHelper+DEVMODE
$dm.dmSize = $structSize

try {
    $readOk = [DisplayHelper]::EnumDisplaySettings($DeviceName, $ENUM_CURRENT_SETTINGS, [ref]$dm)
} catch {
    Write-Error "EnumDisplaySettings threw an exception: $($_.Exception.Message)"
    exit 1
}

if ($readOk -eq 0) {
    $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Write-Error "Could not read current settings for '$DeviceName' (Win32 error: $err)."
    exit 1
}

Write-Output "Current mode before change: $($dm.dmPelsWidth)x$($dm.dmPelsHeight) @ $($dm.dmDisplayFrequency)Hz, $($dm.dmBitsPerPel)bpp"

$dm.dmPelsWidth = $Width
$dm.dmPelsHeight = $Height
$dm.dmDisplayFrequency = $Rate
$dm.dmBitsPerPel = $BitDepth
$dm.dmFields = $DM_PELSWIDTH -bor $DM_PELSHEIGHT -bor $DM_DISPLAYFREQUENCY -bor $DM_BITSPERPEL

try {
    $result = [DisplayHelper]::ChangeDisplaySettingsEx($DeviceName, [ref]$dm, [IntPtr]::Zero, $CDS_UPDATEREGISTRY, [IntPtr]::Zero)
} catch {
    Write-Error "ChangeDisplaySettingsEx threw an exception: $($_.Exception.Message)"
    exit 1
}

switch ($result) {
    0       { Write-Output "SUCCESS: $DeviceName -> ${Width}x${Height} @ ${Rate}Hz"; exit 0 }
    1       { Write-Output "RESTART_REQUIRED: $DeviceName"; exit 0 }
    -1      { Write-Error "FAILED (DISP_CHANGE_FAILED): the display driver refused this mode for $DeviceName"; exit 1 }
    -2      { Write-Error "FAILED (DISP_CHANGE_BADMODE): $DeviceName does not support ${Width}x${Height} @ ${Rate}Hz @ ${BitDepth}bpp as a combination"; exit 1 }
    default { Write-Error "FAILED: ChangeDisplaySettingsEx returned $result for $DeviceName"; exit 1 }
}
