// lib/pages/menu/home_page.dart (VERSÃO AJUSTADA COM CONTROLE DE ACESSO)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Importações do Projeto
import 'package:geoforestcoletor/pages/analises/analise_selecao_page.dart';
import 'package:geoforestcoletor/pages/menu/configuracoes_page.dart';
import 'package:geoforestcoletor/pages/projetos/lista_projetos_page.dart';
import 'package:geoforestcoletor/pages/planejamento/selecao_atividade_mapa_page.dart';
import 'package:geoforestcoletor/pages/menu/paywall_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/providers/license_provider.dart'; // <<< IMPORT NECESSÁRIO
import 'package:geoforestcoletor/services/export_service.dart';
import 'package:geoforestcoletor/widgets/menu_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // O conteúdo de _mostrarDialogoImportacao, _abrirAnalistaDeDados,
  // e _mostrarDialogoExportacao permanece EXATAMENTE O MESMO.
  // Não é necessário alterá-los.

  void _mostrarDialogoImportacao(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text('O que você deseja importar?', style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.table_rows_outlined, color: Colors.green),
            title: const Text('Coletas de Parcela (Inventário)'),
            subtitle: const Text('Importa um arquivo CSV com dados de árvores e parcelas.'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const ListaProjetosPage(
                  title: 'Importar para o Projeto...',
                  isImporting: true,
                  importType: 'parcela',
                ),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.straighten_outlined, color: Colors.brown),
            title: const Text('Dados de Cubagem'),
            subtitle: const Text('Importa um arquivo CSV com dados de cubagem e seções.'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const ListaProjetosPage(
                  title: 'Importar Cubagem para...',
                  isImporting: true,
                  importType: 'cubagem',
                ),
              ));
            },
          ),
          ListTile(
            leading: Icon(Icons.rule_folder_outlined, color: Colors.grey.shade400),
            title: const Text('Auditoria (Em breve)'),
            subtitle: const Text('Importa dados para o módulo de auditoria.'),
            onTap: null,
          ),
        ],
      ),
    );
  }

  void _abrirAnalistaDeDados(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnaliseSelecaoPage()),
    );
  }

  void _mostrarDialogoExportacao(BuildContext context) {
    final exportService = ExportService();

    void _mostrarDialogoParcelas(BuildContext mainDialogContext) {
      showDialog(
        context: mainDialogContext,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Tipo de Exportação de Coleta'),
          content: const Text(
              'Deseja exportar apenas os dados novos ou um backup completo de todas as coletas de parcela?'),
          actions: [
            TextButton(
              child: const Text('Apenas Novas'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarDados(context);
              },
            ),
            ElevatedButton(
              child: const Text('Todas (Backup)'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarTodasAsParcelasBackup(context);
              },
            ),
          ],
        ),
      );
    }

    void _mostrarDialogoCubagem(BuildContext mainDialogContext) {
      showDialog(
        context: mainDialogContext,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Tipo de Exportação de Cubagem'),
          content: const Text(
              'Deseja exportar apenas os dados novos ou um backup completo de todas as cubagens?'),
          actions: [
            TextButton(
              child: const Text('Apenas Novas'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarNovasCubagens(context);
              },
            ),
            ElevatedButton(
              child: const Text('Todas (Backup)'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                exportService.exportarTodasCubagensBackup(context);
              },
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: Text('Escolha o que deseja exportar',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading:
                  const Icon(Icons.table_rows_outlined, color: Colors.green),
              title: const Text('Coletas de Parcela (CSV)'),
              subtitle: const Text('Exporta os dados de parcelas e árvores.'),
              onTap: () {
                Navigator.of(ctx).pop();
                _mostrarDialogoParcelas(context);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.table_chart_outlined, color: Colors.brown),
              title: const Text('Cubagens Rigorosas (CSV)'),
              subtitle: const Text('Exporta os dados de cubagens e seções.'),
              onTap: () {
                Navigator.of(ctx).pop();
                _mostrarDialogoCubagem(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: Colors.purple),
              title: const Text('Plano de Amostragem (GeoJSON)'),
              subtitle:
                  const Text('Exporta o plano de amostragem do mapa.'),
              onTap: () {
                Navigator.of(ctx).pop();
                context.read<MapProvider>().exportarPlanoDeAmostragem(context);
              },
            ),
          ],
        ),
      ),
    );
  }


  // <<<< FUNÇÃO AUXILIAR ADICIONADA >>>>
  // Mostra um diálogo para o usuário fazer upgrade do plano.
  void _mostrarAvisoDeUpgrade(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Funcionalidade indisponível"),
        content: Text("A função '$featureName' não está disponível no seu plano atual (Trial). Faça upgrade para desbloqueá-la."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Entendi"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage()));
            },
            child: const Text("Ver Planos"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // <<< AJUSTE PRINCIPAL AQUI >>>
    // 1. Ouve as mudanças do LicenseProvider
    final licenseProvider = context.watch<LicenseProvider>();

    // 2. Determina as permissões com base nos dados carregados, com um valor padrão seguro
    final bool podeExportar = licenseProvider.licenseData?.features['exportacao'] ?? false;
    final bool podeAnalisar = licenseProvider.licenseData?.features['analise'] ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 1.0,
          children: [
            MenuCard(
              icon: Icons.folder_copy_outlined,
              label: 'Projetos e Coletas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaProjetosPage(title: 'Meus Projetos'),
                ),
              ),
            ),
            MenuCard(
              icon: Icons.map_outlined,
              label: 'Planejamento de Campo',
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const SelecaoAtividadeMapaPage()));
              },
            ),

            // 3. Lógica aplicada ao card de Análise
            MenuCard(
              icon: Icons.insights_outlined,
              label: 'GeoForest Analista',
              onTap: podeAnalisar
                  ? () => _abrirAnalistaDeDados(context)
                  : () => _mostrarAvisoDeUpgrade(context, "GeoForest Analista"),
            ),

            MenuCard(
              icon: Icons.download_for_offline_outlined,
              label: 'Importar Dados (CSV)',
              onTap: () => _mostrarDialogoImportacao(context),
            ),

            // 4. Lógica aplicada ao card de Exportação
            MenuCard(
              icon: Icons.upload_file_outlined,
              label: 'Exportar Dados',
              onTap: podeExportar
                  ? () => _mostrarDialogoExportacao(context)
                  : () => _mostrarAvisoDeUpgrade(context, "Exportar Dados"),
            ),

            MenuCard(
              icon: Icons.settings_outlined,
              label: 'Configurações',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfiguracoesPage()),
              ),
            ),
            MenuCard(
              icon: Icons.credit_card,
              label: 'Assinaturas', // Nome mais claro para o usuário
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaywallPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}