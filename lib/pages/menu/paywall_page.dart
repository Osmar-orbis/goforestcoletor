// lib/pages/menu/paywall_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ADICIONADO: Pacote para abrir a URL de pagamento no navegador.
import 'package:url_launcher/url_launcher.dart';

// O pacote do Stripe não é mais necessário nesta página para a abordagem de Checkout.
// Se você não o usa em mais nenhum lugar, pode até removê-lo do pubspec.yaml.
// import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

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
      precoAnualId: "price_1RlrTUCHDKuxFKvWcbK7A5sW",
      precoMensalId: "price_1RlrTiCHDKuxFKvW2zxUHW1C",
      valorAnual: "R\$ 5.000",
      valorMensal: "R\$ 600",
      icone: Icons.person_outline,
      cor: Colors.blue,
      features: ["3 Smartphones", "Exportação de dados", "Suporte por e-mail"],
    ),
    PlanoAssinatura(
      nome: "Profissional",
      descricao: "Ideal para empresas em crescimento.",
      precoAnualId: "price_1RlrUbCHDKuxFKvWc2k3Fw4z",
      precoMensalId: "price_1RlrUmCHDKuxFKvWtjOZzV46",
      valorAnual: "R\$ 9.000",
      valorMensal: "R\$ 850",
      icone: Icons.business_center_outlined,
      cor: Colors.green,
      features: ["7 Smartphones", "1 Desktop ", "Módulo de Análise e Relatórios", "Suporte prioritário"],
    ),
    PlanoAssinatura(
      nome: "Premium",
      descricao: "A solução completa para grandes operações.",
      precoAnualId: "price_1RlrVRCHDKuxFKvWPlhY6IcP",
      precoMensalId: "price_1RlrVeCHDKuxFKvWkPymrqi5",
      valorAnual: "R\$ 15.000",
      valorMensal: "R\$ 1.700",
      icone: Icons.star_border_outlined,
      cor: Colors.purple,
      features: ["Dispositivos ilimitados", "3 Desktops ", "Todos os Módulos", "Acesso à API", "Gerente de conta dedicado"],
    ),
  ];

  // =========================================================================
  // MÉTODO _iniciarCheckout COMPLETAMENTE SUBSTITUÍDO PELA VERSÃO SIMPLIFICADA
  // =========================================================================
  Future<void> _iniciarCheckout(String priceId) async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não está logado.");
      }

      // 1. Chama a Cloud Function. Ela fará o trabalho pesado de criar a sessão.
      //    (Certifique-se de que sua Cloud Function está atualizada para retornar a URL).
      final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('createCheckoutSession');
      final response = await callable.call<Map<String, dynamic>>({'priceId': priceId});

      // 2. A função agora retorna apenas uma URL.
      final String? url = response.data['url'];

      if (url != null) {
        final uri = Uri.parse(url);
        // 3. Abre a página de pagamento segura do Stripe no navegador do celular.
        //    O Stripe cuida de todo o resto (cartão, validação, etc).
        if (await canLaunchUrl(uri)) {
          // Usar 'externalApplication' garante que abrirá no Chrome/Safari,
          // o que é mais robusto que uma webview dentro do app.
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Não foi possível abrir a página de pagamento.';
        }
      } else {
        // Isso acontece se a Cloud Function falhar e não retornar uma URL.
        throw 'URL de pagamento inválida recebida do servidor.';
      }

    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro de comunicação com o servidor: ${e.message}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ocorreu um erro inesperado: ${e.toString()}"), backgroundColor: Colors.red),
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
                "Aproveite o Futuro em Análises e Coletas Florestais",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 45, 114, 4)),
              ),
              const SizedBox(height: 8),
              const Text(
                "Escolha um plano para continuar usando todos os recursos do GeoForest.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              // O restante da UI não precisa de alteração.
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
// NENHUMA ALTERAÇÃO NECESSÁRIA AQUI
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