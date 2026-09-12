<#
Generates tiny synthetic clips for the tests/*.ps1 verification suite.
All output stays under tests/clips/ (gitignored, regenerable). Requires ffmpeg.
#>
$ErrorActionPreference = 'Stop'
$clips = Join-Path $PSScriptRoot 'clips'
New-Item -ItemType Directory -Force -Path $clips | Out-Null
function Clip($name, $vf, $extra) {
    $out = Join-Path $clips $name
    ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=size=640x480:rate=30:duration=5 -t 5 -vf $vf -c:v libx264 -preset ultrafast -crf 23 @extra -movflags +faststart $out
    ffprobe -hide_banner -v error -show_entries stream=width,height,color_primaries,color_transfer,color_space,pix_fmt -of default=noprint_wrappers=1 $out | ForEach-Object { Write-Output "  $_" }
}
Write-Output '--- sdr709.mp4 (BT.709 SDR baseline)'
Clip 'sdr709.mp4' 'scale=256:256,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1')
Write-Output '--- hdrpq.mp4 (BT.2020 + PQ)'
Clip 'hdrpq.mp4' 'scale=256:256,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=9:transfer_characteristics=16:matrix_coefficients=9')
Write-Output '--- hlghlg.mp4 (BT.2020 + HLG)'
Clip 'hlghlg.mp4' 'scale=256:256,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=9:transfer_characteristics=18:matrix_coefficients=9')
Write-Output '--- Resolution ladder (BT.709 flagged, height is what the Res-* conds read)'
Clip 'res480.mp4' 'scale=640:480,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1')
Clip 'res720.mp4' 'scale=960:720,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1')
Clip 'res1000.mp4' 'scale=960:1000,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1')
Clip 'res1400.mp4' 'scale=960:1400,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1')
Clip 'res2160.mp4' 'scale=640:2160,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1')
Write-Output '--- ntsc.mp4 (SMPTE 170M -> bt.601-525) / pal.mp4 (BT.470BG -> bt.601-625)'
Clip 'ntsc.mp4' 'scale=256:256,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=6:transfer_characteristics=6:matrix_coefficients=6')
Clip 'pal.mp4' 'scale=256:256,format=yuv420p' @('-bsf:v', 'h264_metadata=colour_primaries=5:transfer_characteristics=5:matrix_coefficients=5')
Write-Output '--- gray.mkv (grayscale; FFV1 — H.264 decodes back to yuvj420p/nv12 in FFmpeg/mpv, so H.264 cannot test the gray profile)'
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=size=256x256:rate=30:duration=5 -t 5 -vf format=gray -c:v ffv1 (Join-Path $clips 'gray.mkv')
ffprobe -hide_banner -v error -show_entries stream=width,height,pix_fmt -of default=noprint_wrappers=1 (Join-Path $clips 'gray.mkv') | ForEach-Object { Write-Output "  $_" }
Write-Output '--- sdr20.mp4 (20s session clip) / sdr70.mp4 (70s, for [ending] out-of-window side)'
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=size=256x256:rate=30:duration=20 -t 20 -vf format=yuv420p -c:v libx264 -preset ultrafast -crf 23 -bsf:v h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1 -movflags +faststart (Join-Path $clips 'sdr20.mp4')
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=size=256x256:rate=30:duration=70 -t 70 -vf format=yuv420p -c:v libx264 -preset ultrafast -crf 23 -bsf:v h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1 -movflags +faststart (Join-Path $clips 'sdr70.mp4')
Write-Output '--- duaudio.mkv (video + eng sine + jpn sine; alang prefers jpn)'
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=size=256x256:rate=30:duration=5 -f lavfi -i sine=frequency=440:duration=5 -f lavfi -i sine=frequency=880:duration=5 -t 5 -map 0:v -map 1:a -map 2:a -metadata:s:a:0 language=eng -metadata:s:a:1 language=jpn -vf format=yuv420p -c:v libx264 -preset ultrafast -crf 23 -c:a aac (Join-Path $clips 'duaudio.mkv')
Write-Output '--- fps240.mp4 (640x480 HFR for above-refresh drop checks)'
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=size=640x480:rate=240:duration=6 -t 6 -vf format=yuv420p -c:v libx264 -preset ultrafast -crf 23 -bsf:v h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1 -movflags +faststart (Join-Path $clips 'fps240.mp4')
Write-Output '--- fps24.mp4 (film-rate judder/VRR checks)'
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=size=640x480:rate=24:duration=8 -t 8 -vf format=yuv420p -c:v libx264 -preset ultrafast -crf 23 -bsf:v h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1 -movflags +faststart (Join-Path $clips 'fps24.mp4')
Write-Output '--- fps23976 clips (23.976 broadcast rate + audio variant)'
ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=size=640x480:rate=24000/1001:duration=10 -t 10 -vf format=yuv420p -c:v libx264 -preset ultrafast -crf 23 -bsf:v h264_metadata=colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1 -movflags +faststart (Join-Path $clips 'fps23976.mp4')
ffmpeg -hide_banner -loglevel error -y -i (Join-Path $clips 'fps23976.mp4') -f lavfi -i sine=frequency=440:duration=10 -t 10 -map 0:v -map 1:a -c:v copy -c:a aac -shortest (Join-Path $clips 'fps23976a.mkv')
ffprobe -hide_banner -v error -show_entries stream=index,codec_type:stream_tags=language -of default=noprint_wrappers=1 (Join-Path $clips 'duaudio.mkv') | ForEach-Object { Write-Output "  $_" }
Write-Output '--- real clips (clips/real/, NOT regenerable without sources) ---'
Write-Output 'Provenance + recipes; cuts made with the ffmpeg-skill scripts/cut.py'
Write-Output '(lossless copy preferred, hybrid re-encode when keyframe snap > tolerance).'
$realDir = Join-Path $clips 'real'
New-Item -ItemType Directory -Force -Path $realDir | Out-Null
$ffmpegScripts = Join-Path $env:LOCALAPPDATA 'hermes/skills/media/ffmpeg-skill/scripts'
$realSources = @{
    # [output in clips/real] = @{ Source = 'full source path'; Start = s; End = s }
    # Completed Sep 2026 (cut with -map 0 -c copy to keep all tracks):
    'real1080-dual.mkv' = @{ Source = '[moved] Assassination Classroom movie 1080p DUAL'; Start = 600; End = 616 }
    'real70.mkv'        = @{ Source = '[moved] same AssClass source'; Start = 600; End = 670 }
    'real2160-pq.mkv'   = @{ Source = 'C:/Users/Anxo/Downloads/Torrent/Demon Slayer - The Movie - Mugen Train [2020] 2160p UHD BDRip HDR10 x265 TrueHD Atmos 7.1 Kira [SEV].mkv'; Start = 600; End = 616 }
    'real480-ntsc.mkv'  = @{ Source = 'C:/Users/Anxo/Downloads/Torrent/Dragon Ball - 002 - The Emperor''s Quest.mkv'; Start = 120; End = 136 }
    'real720-av1.mkv'   = @{ Source = 'C:/Users/Anxo/Downloads/Torrent/Jujutsu.Kaisen.S01.720p.BluRay.Opus2.0.AV1-AnimEssential/Jujutsu.Kaisen.S01E01.720p.BluRay.Opus2.0.AV1-AnimEssential.mkv'; Start = 120; End = 136 }
    'real720-nier.mkv'  = @{ Source = 'C:/Users/Anxo/Downloads/Torrent/[Erai-raws] NieR-Automata Ver1_1a Part 2 - 12 [720p][Multiple Subtitle][3DBCF00F].mkv'; Start = 120; End = 136 }
}
foreach ($name in $realSources.Keys) {
    $spec = $realSources[$name]
    $out = Join-Path $realDir $name
    if (Test-Path $out) { Write-Output "  keep $name (exists)"; continue }
    if (-not $spec.Source -or -not (Test-Path $spec.Source)) { Write-Output "  SKIP $name (no source; set Source above)"; continue }
    python (Join-Path $ffmpegScripts 'cut.py') $spec.Source --start $spec.Start --end $spec.End -o $out
}
Write-Output 'done.'
