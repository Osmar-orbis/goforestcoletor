// lib/pages/menu/paywall_page.dart

// Importamos o material.dart normalmente
import 'package:flutter/material.dart'; 
// E importamos o flutter_stripe com um "apelido" para evitar o conflito
import 'package:flutter_stripe/flutter_stripe.dart' as stripe; 

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';


// Sua chave publicável do Stripe.
const String stripePublishableKey = "pk_live_51RkZWtCHDKuxFKvWkctCa29ioADWA8XaBx1cown7ePUCYyzCuSrlH8bW9kjDe2WcxbPUE6jQtnu6Vnyk1jNza6od006AkUPbgv";


// Modelo simples para representar um plano
class PlanoAssinatura {
  final String nome;
  final String descricao;
  final String precoAnualId;
  final String precoMensalId;
  final String valorAnual;
  final String valorMensal;
  final IconData icone;
  final Color cor;
  final List<String> features;

  PlanoAssinatura({
    required this.nome,
    required this.descricao,
    required this.precoAnualId,
    required this.precoMensalId,
    required this.valorAnual,
    required this.valorMensal,
    required this.icone,
    required this.cor,
    required this.features,
  });
}

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  bool _isLoading = false;

  final List<PlanoAssinatura> planos = [
    PlanoAssinatura(
      nome: "Básico",
      descricao: "Para equipes pequenas e projetos iniciais.",
      precoAnualId: "price_1RkZkfCDD1ZXEMnaxwnKUztS",
      precoMensalId: "price_1RkZpNCDD1ZXEMnaHSNKhOt8",
      valorAnual: "R\$ 5.000",
      valorMensal: "R\$ 600",
      icone: Icons.person_outline,
      cor: Colors.blue,
      features: ["3 Smartphones", "Exportação de dados", "Suporte por e-mail"],
    ),
    PlanoAssinatura(
      nome: "Profissional",
      descricao: "Ideal para empresas em crescimento.",
      precoAnualId: "price_1RkZsdCDD1ZXEMnaSDcWqJj7",
      precoMensalId: "price_1RkZt2CDD1ZXEMnaNtZkAniK",
      valorAnual: "R\$ 9.000",
      valorMensal: "R\$ 850",
      icone: Icons.business_center_outlined,
      cor: Colors.green,
      features: ["7 Smartphones", "1 Desktop ", "Módulo de Análise e Relatórios", "Suporte prioritário"],
    ),
    PlanoAssinatura(
      nome: "Premium",
      descricao: "A solução completa para grandes operações.",
      precoAnualId: "price_1RkZv1CDD1ZXEMnaOO4Re7lF",
      precoMensalId: "price_1RkZwWCDD1ZXEMnaHCY7sn5M",
      valorAnual: "R\$ 15.000",
      valorMensal: "R\$ 1.500",
      icone: Icons.star_border_outlined,
      cor: Colors.purple,
      features: ["Dispositivos ilimitados", "3 Desktops ", "Todos os Módulos", "Acesso à API", "Gerente de conta dedicado"],
    ),
  ];

 Future<void> _iniciarCheckout(String priceId) async {
  // A inicialização da chave agora é feita no main.dart, 
  // mas podemos garantir que ela está aqui também.
  stripe.Stripe.publishableKey = stripePublishableKey;
  await stripe.Stripe.instance.applySettings();

  setState(() => _isLoading = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Usuário não está logado.");
    }

    // 1. Chama a Cloud Function para criar a Sessão de Pagamento
    //    Esta parte continua igual.
    final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");
    final callable = functions.httpsCallable('createCheckoutSession');
    final response = await callable.call<Map<String, dynamic>>({'priceId': priceId});

    // 2. Extrai os dados necessários retornados pela função.
    //    O Stripe agora nos dá várias chaves para configurar a tela de pagamento.
    final paymentIntentClientSecret = response.data['paymentIntent'];
    final ephemeralKey = response.data['ephemeralKey'];
    final customerId = response.data['customer'];

    if (paymentIntentClientSecret == null || ephemeralKey == null || customerId == null) {
      throw Exception("Dados de pagamento inválidos retornados pelo servidor.");
    }

    // 3. Inicializa o "Payment Sheet" (a tela de pagamento nativa)
    await stripe.Stripe.instance.initPaymentSheet(
      paymentSheetParameters: stripe.SetupPaymentSheetParameters(
        // ID do cliente no Stripe
        customerId: customerId,
        // Chave temporária para autorizar o app a agir em nome do cliente
        customerEphemeralKeySecret: ephemeralKey,
        // "Intenção de pagamento", a chave principal da transação
        paymentIntentClientSecret: paymentIntentClientSecret,
        // Nome do seu negócio
        merchantDisplayName: 'GeoForest Analytics',
      ),
    );

    // 4. Apresenta a tela de pagamento para o usuário
    await stripe.Stripe.instance.presentPaymentSheet();
    
    // Se chegar aqui, o pagamento foi bem-sucedido!
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pagamento concluído com sucesso! Atualizando sua licença..."),
          backgroundColor: Colors.green,
        ),
      );
      // Você pode redirecionar o usuário ou apenas esperar o webhook atualizar o status.
    }

  } on stripe.StripeException catch (e) {
    // Lida com erros específicos do Stripe (ex: cartão recusado)
    if(mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro no pagamento: ${e.error.localizedMessage}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  } on FirebaseFunctionsException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro do Firebase: ${e.message}"), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro inesperado: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escolha seu Plano"), centerTitle: true),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text(
                "Sua licença de teste expirou!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              const Text(
                "Escolha um plano para continuar usando todos os recursos do GeoForest.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ...planos.map((plano) => PlanoCard(
                    plano: plano,
                    onSelecionar: (priceId) => _iniciarCheckout(priceId),
                  )).toList(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Iniciando pagamento seguro...", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Widget auxiliar para criar os cards de cada plano
class PlanoCard extends StatelessWidget {
  final PlanoAssinatura plano;
  final Function(String priceId) onSelecionar;

  const PlanoCard({
    super.key,
    required this.plano,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    // <<< CORREÇÃO 3: O widget Card agora é explicitamente do material.dart >>>
    // e o código interno permanece o mesmo
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: plano.cor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(plano.icone, size: 40, color: plano.cor),
            const SizedBox(height: 12),
            Text(
              plano.nome,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: plano.cor),
            ),
            const SizedBox(height: 8),
            Text(
              plano.descricao,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const Divider(height: 32),
            ...plano.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 20, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(child: Text(feature, style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onSelecionar(plano.precoMensalId),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: plano.cor),
                    ),
                    child: Text("${plano.valorMensal}/mês"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onSelecionar(plano.precoAnualId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plano.cor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text("${plano.valorAnual}/ano"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}