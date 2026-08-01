import 'package:flutter/material.dart';

import '../../core/widgets/app_bottom_nav.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des analyses')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "L'historique sera alimenté après la mise en place "
            "de l'analyse des documents.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
