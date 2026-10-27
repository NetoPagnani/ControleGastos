# Controle de Gastos

App de gastos pessoais em Flutter (Android e Web), offline-first, com Firebase (Authentication para o login e Cloud Firestore para os dados, que já guarda uma cópia no aparelho e sincroniza sozinho). Spec e plano em `docs/superpowers/`.

## Rodar

1. Instale as ferramentas do Firebase (no PowerShell, use `npm.cmd` e `firebase.cmd`):

   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```

2. Entre na conta Google do projeto: `firebase login`.
3. Gere a configuração: `flutterfire configure --platforms=android,web`. Ele cria `lib/firebase_options.dart` e `android/app/google-services.json`, que ficam fora do git.
4. `flutter run` (na Web, use sempre a mesma porta: `flutter run -d chrome --web-port 5000`).

## Publicar no Google Play

### Uma vez só

1. **Chave de assinatura.** Gere e guarde num lugar seguro (sem ela não dá para atualizar o app):

   ```bash
   keytool -genkey -v -keystore ~/controle-gastos-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Copie `android/key.properties.exemplo` para `android/key.properties` e preencha. Esse arquivo fica fora do git.

2. **Firebase.** No console do projeto:
   - Authentication > Sign-in method: ative **E-mail/senha** e **Google**.
   - Authentication > Settings > Authorized domains: adicione o endereço onde a versão Web estiver publicada.
   - Firestore Database criado em `southamerica-east1` (São Paulo).
   - Publique as regras de segurança (`firestore.rules`): `firebase deploy --only firestore:rules`.

3. **Login com Google no Android.** Em Configurações do projeto > Seus apps > Android, adicione o SHA-1 de três chaves e depois rode `flutterfire configure` de novo:
   - debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`
   - upload: `keytool -list -v -keystore ~/controle-gastos-upload.jks -alias upload`
   - assinatura do Google Play: Play Console > Teste e lançamento > Integridade do app

4. **Política de privacidade.** A loja pede um endereço público. O texto está em `web/privacidade.html` (e dentro do app, em Configurações). Publicando a versão Web, ela fica em `<endereço>/privacidade.html`.

### A cada versão

1. Suba a versão em `pubspec.yaml` (`version: 1.0.1+2`; o número depois do `+` sempre aumenta).
2. `flutter build appbundle --release`
3. Envie `build/app/outputs/bundle/release/app-release.aab` no Play Console.

### Ficha da loja (Play Console)

- **Segurança dos dados:** coleta e-mail (gerenciamento de conta) e dados financeiros digitados pelo usuário (funcionalidade do app); criptografado em trânsito; não compartilhado; o usuário pode pedir exclusão (no app e pelo e-mail de contato).
- **Exclusão de conta:** dentro do app, em Configurações > Apagar conta. Como link externo, use a política de privacidade (seção "Exportar e apagar").
- **Anúncios:** não. **Público-alvo:** maiores de 18.

## Ícone

`dart run flutter_launcher_icons` gera os ícones a partir de `assets/icone/`.
