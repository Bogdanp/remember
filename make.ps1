if (Test-Path -Path .\build) { Remove-Item -Recurse -Path .\build }
New-Item -ItemType Directory -Force -Path .\build

if (Test-Path -Path .\temp) { Remove-Item -Recurse -Path .\temp }
New-Item -ItemType Directory -Force -Path .\temp

raco exe -o .\temp\remember-core.exe .\core\main.rkt
raco distribute .\build .\temp\remember-core.exe
