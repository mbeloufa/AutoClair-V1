import 'package:flutter/material.dart';

import '../../core/widgets/app_bottom_nav.dart';

class VehiclesPage extends StatelessWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes véhicules')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Le module de gestion des véhicules sera le prochain '
            'bloc fonctionnel.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}
