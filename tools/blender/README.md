# Sketchfab enemy pipeline

Blender 5.2.3 imports the extracted glTF as data; do not execute anything from the download. In PowerShell, from the repository root:

```powershell
$env:BLENDER_USER_CONFIG='D:/DevCache/blender/config'
$env:BLENDER_USER_SCRIPTS='D:/DevCache/blender/scripts'
$env:TEMP='D:/DevCache/blender/temp'
$env:TMP='D:/DevCache/blender/temp'
& 'D:/DevCache/blender/blender-5.2.3-windows-x64/blender.exe' --background --python tools/blender/process_enemy.py
```

Optionally pass `-- <extracted-directory> <output-directory>` after the script path. The script checks the 2,500-triangle budget, evaluates the original walk at 32 samples, recolors the 512-pixel source texture, and writes the GLB, the color image and the lossless VAT PNG. The mesh's second UV layer identifies each vertex's VAT texel. VAT rows store deltas in Godot coordinates; the shader uses nearest sampling and a per-instance phase. The small metadata file records the range, rows, image height and clip duration; update shader constants if a different source changes them. The VAT is data and must remain losslessly imported without mipmaps or sRGB conversion. Only the processed output is committed, never the source download.
