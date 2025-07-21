// lib/pages/gerente/gerente_main_page.dart (VERSÃO CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/controller/login_controller.dart';
import 'package:geoforestcoletor/pages/gerente/gerente_dashboard_page.dart';
import 'package:geoforestcoletor/pages/menu/home_page.dart';
import 'package:provider/provider.dart';

class GerenteMainPage extends StatefulWidget {
  const GerenteMainPage({super.key});

  @override
  State<GerenteMainPage> createState() => _GerenteMainPageState();
}

class _GerenteMainPageState extends State<GerenteMainPage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    GerenteDashboardPage(),
    // <<< CORREÇÃO AQUI: Diga para a HomePage não mostrar sua própria AppBar >>>
    HomePage(title: 'Modo Coleta de Campo', showAppBar: false),
  ];

  static const List<String> _pageTitles = <String>[
    'Dashboard do Gestor',
    'Modo Coleta de Campo',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles.elementAt(_selectedIndex)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair da Conta',
            onPressed: () {
              context.read<LoginController>().signOut();
            },
          )
        ],
        automaticallyImplyLeading: false, 
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.park_outlined),
            label: 'Coleta',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}