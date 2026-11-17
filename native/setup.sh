#!/usr/bin/env bash
# Instala o codigo nativo (widget) no projeto Android gerado pelo "flutter create".
# Roda na raiz do repositorio, depois do passo que gera a pasta android/.
set -euo pipefail

SRC=native/android
DST=android/app/src/main

mkdir -p "$DST/java/com/rodrigo/master_notas"
cp -r "$SRC/res/." "$DST/res/"
cp "$SRC"/java/*.java "$DST/java/com/rodrigo/master_notas/"

# a MainActivity do widget (Java) substitui a padrao (Kotlin)
find "$DST" -name 'MainActivity.kt' -delete

python3 native/patch_manifest.py "$DST/AndroidManifest.xml" "$SRC/manifest_snippet.xml"
echo "Codigo nativo instalado."
