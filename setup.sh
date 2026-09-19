#!/usr/bin/env bash
# Gera o projeto Flutter completo (com as pastas nativas do Android) e aplica
# o código do navegador por cima.
set -e
cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter não encontrado no PATH. Instale em https://docs.flutter.dev/get-started/install"
  exit 1
fi

DESTINO="navegador_hibrido"
if [ -d "$DESTINO" ]; then
  echo "A pasta '$DESTINO' já existe. Apague ou renomeie e rode de novo."
  exit 1
fi

flutter create --org com.meunavegador --project-name navegador_hibrido --platforms=android "$DESTINO"

# Copia o código do navegador por cima do projeto gerado
cp -R fonte/. "$DESTINO"/
rm -f "$DESTINO/test/widget_test.dart"

# Firebase exige minSdk 23 ou maior (mantém o valor do Flutter se já for maior)
if [ -f "$DESTINO/android/app/build.gradle.kts" ]; then
  sed -i.bak 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(23, flutter.minSdkVersion)/' \
    "$DESTINO/android/app/build.gradle.kts"
  rm -f "$DESTINO/android/app/build.gradle.kts.bak"
fi
if [ -f "$DESTINO/android/app/build.gradle" ]; then
  sed -i.bak \
    -e 's/minSdkVersion flutter\.minSdkVersion/minSdkVersion Math.max(23, flutter.minSdkVersion)/' \
    -e 's/minSdk = flutter\.minSdkVersion/minSdk = Math.max(23, flutter.minSdkVersion)/' \
    "$DESTINO/android/app/build.gradle"
  rm -f "$DESTINO/android/app/build.gradle.bak"
fi

cd "$DESTINO"
flutter pub get

echo
echo "Pronto! Projeto em: $(pwd)"
echo "Próximos passos: leia o README.md (configurar Firebase e rodar)."
