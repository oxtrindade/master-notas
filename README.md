# Master Notas

Bloco de notas para Android inspirado no Samsung Notes, feito em Flutter.

## Como atualizar (só subir o zip)

1. Receba o zip com o nome `VERSAO-x.y.z.zip` (ex.: `VERSAO-1.1.0.zip`).
2. No repositório: **Add file → Upload files**, suba o zip **sem extrair** (na raiz, junto do `pubspec.yaml`) e dê *Commit changes*.
3. O GitHub extrai o zip por cima dos arquivos, apaga o zip e compila sozinho (aba **Actions**, uns 5 minutos).
4. O APK fica em **Releases** (`MasterNotas-x.y.z.apk`) e também em Actions → compilação → *Artifacts*.
5. Baixe e instale no celular. Instala por cima, sem perder as notas (a chave de assinatura é fixa, em `ci/debug.keystore`).

Obs.: só zips com nome `VERSAO-*.zip` são aplicados. A pasta `.github` e a pasta `ci` nunca são alteradas pelo zip; se o `build.yml` mudar, edite-o à mão no GitHub.
O número da versão vem do `pubspec.yaml` (linha `version:`).

## O que tem na 1.1.0

- Notas com título, texto e **lista de tarefas** (Enter cria novo item; Enter em item vazio sai da lista)
- **Desenho à mão livre** (caneta, marca-texto, borracha, desfazer/refazer)
- Pastas, **fixar**, **cor da nota**, grade/lista, busca
- Seleção múltipla (segurar um cartão): fixar, mover, excluir
- **Lixeira** (apaga sozinha após 30 dias)
- Tema claro/escuro automático
- Backup: menu ⋮ → *Salvar backup* (abre o compartilhar do Android: Google Drive, OneDrive, WhatsApp, e-mail...) e *Restaurar backup* (escolhe o arquivo .json)

Tudo é salvo só no aparelho (arquivo `master_notas.json`).

## Estrutura

- `lib/` código do app
- `.github/workflows/build.yml` compilação automática
- `ci/debug.keystore` chave fixa de assinatura
- `assets/android-icons/` ícone do app (copiado para o projeto Android na compilação)
