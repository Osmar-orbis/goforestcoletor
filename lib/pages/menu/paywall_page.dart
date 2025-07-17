// ARQUIVO: lib/pages/menu/paywall_page.dart (VERSÃO COMPLETA E CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// Modelo para representar um plano. Não precisa de alteração.
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
  // A lista de planos permanece a mesma, para exibir o catálogo.
  // Os IDs de preço do Stripe não são mais usados, mas podemos mantê-los por enquanto.
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

  /// Esta função gera a mensagem e abre o WhatsApp.
  Future<void> iniciarContatoWhatsApp(PlanoAssinatura plano, String tipoCobranca) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro: Usuário não encontrado. Por favor, faça login novamente."))
        );
      }
      return;
    }

    // !! IMPORTANTE !! TROQUE ESTE NÚMERO PELO SEU NÚMERO COMERCIAL !!
    final String seuNumeroWhatsApp = "5515981409153"; 
    
    final String nomePlano = plano.nome;
    final String emailUsuario = user.email ?? "Email não disponível";

    final String mensagem = "Olá! Tenho interesse em contratar o *$nomePlano ($tipoCobranca)* para o GeoForest Analytics. Meu email de cadastro é: $emailUsuario";
    
    final String urlWhatsApp = "https://wa.me/$seuNumeroWhatsApp?text=${Uri.encodeComponent(mensagem)}";
    final Uri uri = Uri.parse(urlWhatsApp);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Não foi possível abrir o WhatsApp. Certifique-se de que ele está instalado."))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escolha seu Plano"), centerTitle: true),
      body: ListView( // Simplificado, removido o Stack pois _isLoading não é mais necessário
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "Aproveite o Futuro em Análises e Coletas Florestais",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 45, 114, 4)),
          ),
          const SizedBox(height: 8),
          const Text(
            "Escolha um plano para destravar todos os recursos e continuar crescendo.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          // Mapeia os planos para o widget PlanoCard, passando a nova função
          ...planos.map((plano) => PlanoCard(
                plano: plano,
                onSelecionar: (planoSelecionado, tipoCobranca) => 
                    iniciarContatoWhatsApp(planoSelecionado, tipoCobranca),
              )).toList(),
        ],
      ),
    );
  }
}

// O Widget do Card agora recebe a função com os parâmetros corretos.
class PlanoCard extends StatelessWidget {
  final PlanoAssinatura plano;
  final Function(PlanoAssinatura plano, String tipoCobranca) onSelecionar;

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
                    // Chama a função onSelecionar passando o plano e a string "Mensal"
                    onPressed: () => onSelecionar(plano, "Mensal"),
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
                    // Chama a função onSelecionar passando o plano e a string "Anual"
                    onPressed: () => onSelecionar(plano, "Anual"),
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