import 'package:flutter/material.dart';

class ProviderDetailScreen extends StatelessWidget {
  const ProviderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Details'),
      ),
      body: const Center(
        child: Text('Provider Detail Screen'),
      ),
    );
  }
}