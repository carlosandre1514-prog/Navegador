# Como gerar o APK — Meu Navegador Híbrido

## Já configurado neste zip
- Projeto Flutter completo (Android)
- Código do navegador híbrido (celular + TV)
- Firebase (`navegador-f06a8`) com `google-services.json` e `firebase_options.dart`
- Plugin Google Services no Gradle
- minSdk 23

## Ainda precisa fazer no Firebase Console
1. **Authentication** → Sign-in method → ative **Anônimo**
2. **Realtime Database** → criar o banco (se ainda não criou)
   - Região: escolha a mais próxima (ex.: us-central1 ou southamerica-east1)
   - Depois de criar, confira a URL em Dados → deve ser algo como:
     `https://navegador-f06a8-default-rtdb.firebaseio.com`
     ou `https://navegador-f06a8-default-rtdb.firebaseio.com/` (região diferente)
   - Se a URL for diferente da que está em `lib/firebase_options.dart`, edite o campo `databaseURL`
3. Em **Realtime Database → Regras**, cole o conteúdo de `database.rules.json` e publique

## Gerar o APK

Pré-requisito: Flutter + Android SDK instalados (`flutter doctor` ok no Android).

```bash
cd navegador_hibrido
flutter pub get
flutter build apk --release
```

APK gerado em:
`build/app/outputs/flutter-apk/app-release.apk`

Instale no celular e na Android TV (mesmo APK).

### Teste rápido (debug)
```bash
flutter build apk --debug
# ou com aparelho conectado:
flutter run
```

## Package name
`com.meunavegador.navegador_hibrido`

## Problemas comuns
- "Firebase não configurado" → já está preenchido neste zip
- "Não foi possível conectar ao Firebase" → confira internet + login Anônimo ativado + Realtime Database criado
- PIN não encontrado → a TV precisa estar com o navegador aberto gerando o PIN
- Netflix/DRM pode não tocar no WebView
