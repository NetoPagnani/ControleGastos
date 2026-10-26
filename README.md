# Controle de Gastos

App de gastos pessoais em Flutter (Android e Web), offline-first, com Supabase (login e banco) e PowerSync (sincronização). Spec e plano em `docs/superpowers/`.

## Rodar

1. Copie `config/app_config.exemplo.dart` para `lib/core/app_config.dart` e preencha.
2. `flutter run`

## Publicar no Google Play

### Uma vez só

1. **Chave de assinatura.** Gere e guarde num lugar seguro (sem ela não dá para atualizar o app):

   ```bash
   keytool -genkey -v -keystore ~/controle-gastos-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Copie `android/key.properties.exemplo` para `android/key.properties` e preencha. Esse arquivo fica fora do git.

2. **Exclusão de conta no Supabase.** Rode `supabase/migrations/20261025000000_apagar_minha_conta.sql` no SQL Editor do projeto. Sem isso, o botão "Apagar conta" mostra erro.

3. **Links de retorno do login.** Em Supabase > Authentication > URL Configuration > Redirect URLs, adicione:
   - `controlegastos://login-callback` (Android: login com Google, confirmação de e-mail e "esqueci minha senha")
   - o endereço onde a versão Web estiver publicada

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
