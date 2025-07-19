// lib/pages/gerente/gerente_home_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/controller/login_controller.dart';
import 'package:provider/provider.dart';

class GerenteHomePage extends StatelessWidget {
  const GerenteHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Gestor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Permite que o gestor também faça logout
              context.read<LoginController>().signOut();
            },
          )
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize_outlined, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'Bem-vindo, Gestor!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Esta tela irá exibir os dashboards e o progresso em tempo real de todas as equipes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}