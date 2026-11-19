# Sincronizar com o Google Drive

O app guarda as notas numa **pasta privada do app** no seu Drive (`appDataFolder`).
Só o Master Notas enxerga essa pasta: ela não aparece em "Meu Drive" e não mistura com seus arquivos.
O login é feito com um código (o app mostra um código, você digita em google.com/device).

Você precisa criar **um projeto no Google Cloud (grátis)** uma única vez, para ter o *ID do cliente* e a *chave secreta*.
Os nomes dos menus do Google mudam de vez em quando; se algum estiver diferente, procure o parecido.

## Passo a passo (uma vez só)

1. Abra **console.cloud.google.com** e entre com a conta Google que vai guardar as notas.
2. Crie um projeto: seletor de projetos no topo → **Novo projeto** → nome `Master Notas` → **Criar**.
3. Ative a API do Drive: menu **APIs e serviços → Biblioteca** → procure **Google Drive API** → **Ativar**.
4. Configure o app: menu **Google Auth Platform** (antiga "Tela de permissão OAuth") → **Começar**.
   - Nome do app: `Master Notas`
   - E-mail para suporte: o seu
   - Público: **Externo**
   - E-mail de contato: o seu
5. Escopo: em **Acesso a dados** → **Adicionar ou remover escopos** → marque
   `.../auth/drive.appdata` ("Ver e gerenciar seus próprios dados de configuração no Google Drive") → Salvar.
6. **Publique o app**: em **Público** → **Publicar app** → confirme (status **Em produção**).
   - Se deixar em **Teste**, o login **vence a cada 7 dias** e você precisa adicionar seu e-mail em **Usuários de teste**.
   - Como o escopo `drive.appdata` não é sensível, não precisa de verificação do Google.
7. Crie o cliente: **Clientes → Criar cliente** → tipo de aplicativo **TVs e dispositivos de entrada limitada** → nome `Master Notas` → **Criar**.
8. Copie o **ID do cliente** e a **chave secreta do cliente**. (A chave só aparece inteira agora; se perder, use *Adicionar chave* na página do cliente.)

## No app

1. Menu ⋮ → **Google Drive**.
2. Cole o **ID do cliente** e a **chave secreta** → **Salvar**.
3. Toque em **Entrar**. O app mostra um endereço (google.com/device) e um código.
4. Abra o endereço no navegador do celular, digite o código, escolha sua conta e toque em **Permitir**.
   - Pode aparecer o aviso "O Google não verificou este app": toque em **Avançado → Acessar Master Notas**.
5. Pronto. O app volta sozinho e sincroniza. Em outro aparelho, repita (mesmo ID e chave, mesma conta).

A sincronização é automática: ao abrir o app e alguns segundos depois de cada alteração.
O botão **Sincronizar agora** força na hora.

## Como as alterações se juntam

- Cada nota tem a hora da última alteração. Se você editar a mesma nota em dois aparelhos, **vale a mais recente** (a outra é substituída).
- Nota **apagada de vez** num aparelho some dos outros também (o app guarda um registro disso por 6 meses).
- Uma nota aberta no editor não é trocada pela sincronização enquanto você edita.
- Desenhos fazem parte da nota e também sincronizam.

## Problemas comuns

| Mensagem | O que fazer |
|---|---|
| "A API do Google Drive não está ativada" | Passo 3: ative a Google Drive API no mesmo projeto do cliente. |
| "ID do cliente ou chave secreta incorretos" | Confira se copiou inteiro, sem espaço; o tipo do cliente tem que ser *TVs e dispositivos de entrada limitada*. |
| "Acesso negado pelo Google" | Se o app está em **Teste**, adicione seu e-mail em *Usuários de teste* (ou publique, passo 6). |
| "O login do Google venceu" | Entre de novo. Acontece a cada 7 dias se o app ficou em **Teste**. |
| "Sem internet, ou o Google não respondeu" | O aparelho está sem conexão. Tente de novo. |

## Apagar os dados da nuvem

No Google Drive (navegador) → **Configurações → Gerenciar apps → Master Notas → Opções → Excluir dados ocultos do app**.
Isso apaga só a cópia da nuvem. As notas continuam no aparelho.

## Privacidade

O ID e a chave secreta e o login ficam guardados **só no seu aparelho**, na pasta privada do app.
Sair da conta (botão **Sair**) revoga o acesso e apaga o login do aparelho.
