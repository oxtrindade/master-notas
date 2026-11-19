import sys

manifest_path, snippet_path = sys.argv[1], sys.argv[2]

with open(manifest_path, encoding="utf-8") as f:
    manifest = f.read()
with open(snippet_path, encoding="utf-8") as f:
    snippet = f.read()

changed = False

# permissão de internet (o build release do Flutter não inclui por padrão)
if "android.permission.INTERNET" not in manifest:
    if "<application" not in manifest:
        print("ERRO: <application nao encontrado no AndroidManifest.xml")
        sys.exit(1)
    manifest = manifest.replace(
        "<application",
        '<uses-permission android:name="android.permission.INTERNET" />\n    <application',
        1,
    )
    changed = True

# widget de lista de tarefas
if "ChecklistWidgetProvider" not in manifest:
    if "</application>" not in manifest:
        print("ERRO: </application> nao encontrado no AndroidManifest.xml")
        sys.exit(1)
    manifest = manifest.replace(
        "</application>", snippet.rstrip("\n") + "\n    </application>", 1
    )
    changed = True

if changed:
    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(manifest)
    print("Manifest atualizado.")
else:
    print("Manifest ja estava atualizado.")
