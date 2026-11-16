# Master Notas

Bloco de notas para Android inspirado no Samsung Notes, feito em Flutter.

## Como compilar (GitHub Actions)

1. Crie um repositório novo no GitHub (pode ser privado).
2. Extraia o zip e suba **todo o conteúdo** para o repositório (incluindo a pasta oculta `.github` e a pasta `ci`).
   - Se o navegador não subir a pasta `.github`, crie o arquivo na mão: *Add file → Create new file*, digite o nome `.github/workflows/build.yml` e cole o conteúdo do arquivo.
3. A cada envio para a branch `main`, o GitHub compila sozinho (aba **Actions**, leva uns 5 a 8 minutos).
4. O APK fica em **Releases** (`MasterNotas-x.y.z.apk`) e também em Actions → compilação → *Artifacts*.
5. Baixe e instale no celular. As atualizações seguintes instalam por cima, sem perder as notas (a chave de assinatura é fixa, em `ci/debug.keystore`).

Para lançar uma versão nova, mude `version:` no `pubspec.yaml` (ex.: `1.1.0+1`) e suba de novo.

## O que tem na 1.0.0

- Notas com título, texto e **lista de tarefas** (Enter cria novo item; Enter em item vazio sai da lista)
- **Desenho à mão livre** (caneta, marca-texto, borracha, desfazer/refazer, modo "só caneta" para S Pen)
- Pastas, **fixar**, **cor da nota**, grade/lista, busca
- Seleção múltipla (segurar um cartão): fixar, mover, excluir
- **Lixeira** (apaga sozinha após 30 dias)
- Tema claro/escuro automático
- Backup: menu ⋮ → *Copiar backup* / *Restaurar backup* (usa a área de transferência)

Tudo é salvo só no aparelho (arquivo `master_notas.json`).

## Estrutura

- `lib/` código do app
- `.github/workflows/build.yml` compilação automática
- `ci/debug.keystore` chave fixa de assinatura
- `assets/android-icons/` ícone do app (copiado para o projeto Android na compilação)
