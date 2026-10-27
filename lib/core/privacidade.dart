/// Contato do responsavel pelo app. Aparece na politica de privacidade e
/// precisa ser o mesmo e-mail de contato informado no Google Play Console.
const emailContato = 'netopagnani@gmail.com';

/// Texto da politica de privacidade. A mesma versao fica em
/// web/privacidade.html, que e o endereco publico pedido pela loja.
const politicaDePrivacidade = '''
Última atualização: 25 de outubro de 2026

O Controle de Gastos guarda apenas o que você digita nele, para que você veja para onde vai o seu dinheiro.

O que é coletado
• E-mail e identificador da sua conta, usados para login (e-mail e senha ou Google).
• Os dados que você cadastra: gastos (valor, data, categoria, conta, descrição), contas e cartões (apelido, limite, dias de fechamento e vencimento), categorias e a renda mensal de referência.

O app não acessa sua conta bancária, não lê SMS, notificações, contatos ou localização, e não exibe anúncios.

Como os dados são usados
Somente para mostrar seus gastos, gráficos e alertas e para sincronizar entre os seus aparelhos. Nada é vendido nem compartilhado para publicidade.

Onde ficam
No seu aparelho e, para sincronizar, no Firebase, serviço do Google (banco de dados e login, servidores em São Paulo). A comunicação é criptografada (HTTPS). Cada conta só tem acesso aos próprios dados.

Exportar e apagar
Em Configurações você pode exportar todos os seus gastos em CSV e apagar a sua conta. Apagar a conta remove de forma definitiva todos os seus dados dos servidores e do aparelho. Se não conseguir acessar o app, peça a exclusão pelo e-mail abaixo.

Contato
$emailContato
''';
