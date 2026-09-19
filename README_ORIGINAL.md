# Meu Navegador Híbrido (Android celular + Android TV)

Navegador em Flutter que roda no celular e na Android TV com o mesmo código.
Na TV, o celular vira teclado e controle remoto por um **PIN de 6 dígitos**
(Firebase Realtime Database).

> **Aviso honesto:** o código foi escrito sem um Flutter SDK à mão, então **não
> foi compilado nem testado em aparelho**. Se aparecer algum erro na primeira
> execução (versão de pacote, nome de opção do WebView etc.), a correção costuma
> ser de uma linha — me mande a mensagem de erro.

## O que mudou em relação ao manual original

| Ponto | Manual | Esta versão |
|---|---|---|
| Injeção de texto | `'$texto'` dentro do JS (quebra com aspas e permite injeção de código) | Texto passa por `jsonEncode`; usa o *setter nativo* do campo (funciona em React/Vue) |
| Permissão de internet | faltava | `INTERNET` + `usesCleartextTraffic` (sites http) |
| Ícone na TV | faltava o `banner` | banner 320x180 (sem ele o app pode aparecer sem imagem ou nem aparecer na tela inicial da TV) |
| `useShouldOverrideUrlLoading` | ligado, sem callback | implementado: bloqueia `javascript:`, `file:`, `intent:` etc. |
| PIN | 4 dígitos, sem regra | 6 dígitos (`Random.secure`), expira em 5 min sem a TV, **um único celular** por sessão |
| Segurança do Firebase | "configure as regras" | `database.rules.json` pronto + login anônimo |
| Comandos | só texto | texto, abrir endereço, voltar, avançar, atualizar, início, rolar e Enter |
| Controle remoto comum (setas) | não funcionava | **cursor virtual** (setas movem, OK clica) |
| Teclado na TV | "teclado numérico" | teclado completo na tela |
| Modo desktop | só User-Agent | User-Agent + `preferredContentMode`, com botão para alternar |
| Abas / `target=_blank` | ignorado | abre na mesma tela |
| Erros de carregamento | tela em branco | aviso com "Tentar de novo" |
| `uses-feature` mouse/keyboard | declarados | removidos (não são recursos oficiais; mouse e teclado funcionam sem declarar) |

## 1. Requisitos
- Flutter estável atual instalado (`flutter doctor` sem erros no item Android).
  Se o `flutter pub get` reclamar de versões, rode `flutter pub upgrade` ou me envie a mensagem.
- Uma conta Google (Firebase é gratuito para este uso).

## 2. Gerar o projeto
Esta pasta traz só o **código** (`fonte/`). O script cria o projeto Flutter e aplica o código:

```bash
./setup.sh          # Linux / macOS
.\setup.ps1         # Windows (PowerShell)
```

Ele cria a pasta `navegador_hibrido/` (pacote `com.meunavegador.navegador_hibrido`).

## 3. Configurar o Firebase (necessário só para o pareamento)
O navegador funciona sem isto; o botão de PIN é que fica indisponível.

1. https://console.firebase.google.com → **Adicionar projeto**.
2. No projeto: **Adicionar app → Android**, nome do pacote
   `com.meunavegador.navegador_hibrido`. Baixe o `google-services.json`
   (só para copiar os valores, não precisa colocá-lo no projeto).
3. **Authentication → Método de login → Anônimo → Ativar.**
4. **Realtime Database → Criar banco de dados** (modo bloqueado).
5. Aba **Regras**: cole o conteúdo de `database.rules.json` e clique em **Publicar**.
6. Abra `lib/firebase_options.dart` e preencha:

| Campo | Onde está no google-services.json |
|---|---|
| `apiKey` | `client[0].api_key[0].current_key` |
| `appId` | `client[0].client_info.mobilesdk_app_id` |
| `messagingSenderId` | `project_info.project_number` |
| `projectId` | `project_info.project_id` |
| `databaseURL` | endereço mostrado no topo da aba **Dados** do Realtime Database |

## 4. Rodar
Celular (USB ou Wi-Fi):
```bash
cd navegador_hibrido
flutter run
```

Android TV:
1. Na TV: Configurações → Sobre → toque 7x em "Build" → Opções do desenvolvedor → **Depuração USB/ADB** ligada.
2. No computador (mesma rede): `adb connect IP_DA_TV:5555`
3. `flutter run -d IP_DA_TV:5555` ou gere o APK e instale:
```bash
flutter build apk --release
adb -s IP_DA_TV:5555 install -r build/app/outputs/flutter-apk/app-release.apk
```

## 5. Como usar
**Na TV** (abre direto no navegador):
- Mouse USB/Bluetooth e teclado físico funcionam direto na página.
- Botão **Cursor**: liga o cursor virtual (setas movem, OK clica; empurrar contra a
  borda de cima/baixo rola a página; **Voltar** desliga o cursor).
- Botão **Teclado**: teclado na tela (escreve no campo selecionado da página).
- Botão **PIN 123 456**: abre a janela de pareamento (Novo PIN / Desconectar celular).
- Botão **Voltar** do controle: volta no histórico; sem histórico, fecha o app.

**No celular**:
- **Controle remoto da TV** → digite o PIN → clique num campo de texto na TV e digite no celular.
- Também abre endereços, volta, atualiza, rola e aperta Enter na TV.
- **Navegar** usa o celular como navegador comum (modo desktop ligado por padrão).
- **Abrir em modo TV (teste)** mostra a interface da TV no próprio celular.

## 6. Segurança (o que existe e o que NÃO existe)
- Regras do banco: só usuários autenticados; PIN em formato fixo; o **primeiro** celular a
  parear trava a sessão; só esse celular escreve comandos; sessão vencida não aceita comando;
  tamanho e formato dos campos validados.
- A TV apaga a sessão ao fechar (e o servidor apaga se a TV cair).
- Limite: 6 dígitos ainda podem ser adivinhados por força bruta contra uma sessão aberta.
  Para uso público, ative **Firebase App Check** e/ou limite tentativas com uma Cloud Function.
- O texto enviado (inclusive senhas digitadas no celular) passa pelos servidores do Firebase.
  Não use o pareamento para digitar senhas se isso for um problema para você.

## 7. Estrutura
```
lib/
  main.dart                    detecta TV x celular
  firebase_options.dart        SUA configuração do Firebase
  core/  url_utils, device_mode, js_scripts (JS seguro)
  services/pairing_service     SessaoTv (TV) e ControleRemoto (celular)
  screens/ home, browser (WebView), remote (controle)
  widgets/ tv_focusable, virtual_cursor, tv_keyboard, pairing_dialog
android/app/src/main/          AndroidManifest.xml + banner da TV
database.rules.json            regras de segurança do Firebase
```

## 8. Problemas comuns
- **Erro de `minSdk`**: em `android/app/build.gradle(.kts)` use `minSdk = 23` (ou maior).
- **"Firebase não configurado"**: preencha `lib/firebase_options.dart` (passo 3.6).
- **"Não foi possível conectar ao Firebase"**: confira internet e se o login *Anônimo* está ativado.
- **PIN não encontrado**: confira o número; o PIN some quando o navegador da TV é fechado.
- **Site pede versão mais nova do navegador**: atualize o número da versão em `_uaDesktop`
  (`lib/screens/browser_screen.dart`).
- **Vídeos com proteção (DRM), como Netflix, podem não tocar** no WebView; prefira os apps oficiais.
- **Sem downloads**: não implementado nesta versão.
