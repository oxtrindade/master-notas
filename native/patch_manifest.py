import sys

manifest_path, snippet_path = sys.argv[1], sys.argv[2]

with open(manifest_path, encoding="utf-8") as f:
    manifest = f.read()
with open(snippet_path, encoding="utf-8") as f:
    snippet = f.read()

if "ChecklistWidgetProvider" in manifest:
    print("Manifest ja tem o widget.")
    sys.exit(0)

if "</application>" not in manifest:
    print("ERRO: </application> nao encontrado no AndroidManifest.xml")
    sys.exit(1)

manifest = manifest.replace("</application>", snippet.rstrip("\n") + "\n    </application>", 1)

with open(manifest_path, "w", encoding="utf-8") as f:
    f.write(manifest)
print("Manifest atualizado com o widget.")
