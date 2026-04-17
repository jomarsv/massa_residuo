import 'package:flutter/material.dart';

import '../../data/repositories/reference_data_repository.dart';
import '../../domain/entities/app_status.dart';
import '../../services/backend_service.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/status_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.backendService});

  final BackendService backendService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _referenceRepository = const ReferenceDataRepository();
  late Future<AppStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = widget.backendService.checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    final wasteOptions = _referenceRepository.getDefaultWasteOptions();
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE9F0E2), Color(0xFFF5EADB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Text(
                'Estimativa de massa de residuos',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'MVP hibrido para calculo tecnico com apoio de imagem, volume aparente e fatores configuraveis.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FutureBuilder<AppStatus>(
                future: _statusFuture,
                builder: (context, snapshot) {
                  final status = snapshot.data;
                  final isPositive = status?.isBackendReachable ?? false;
                  final label =
                      snapshot.connectionState == ConnectionState.waiting
                      ? 'Verificando backend'
                      : (isPositive
                            ? 'Backend conectado'
                            : 'Modo local estrutural');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(label: label, isPositive: isPositive),
                      const SizedBox(height: 8),
                      Text(
                        status?.message ??
                            'Aguardando validacao de conectividade com a API.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const AppSectionCard(
                title: 'Fluxo previsto do MVP',
                description:
                    'Captura ou upload de imagem, confirmacao do tipo de residuo, escolha do metodo de volume, calculo da estimativa e historico local.',
                icon: Icons.route_outlined,
              ),
              const SizedBox(height: 16),
              const AppSectionCard(
                title: 'Visao computacional como apoio',
                description:
                    'A IA sera opcional no MVP: classificacao e segmentacao futuras nao substituem o calculo fisico-matematico.',
                icon: Icons.center_focus_strong_outlined,
              ),
              const SizedBox(height: 16),
              const AppSectionCard(
                title: 'Proxima entrega',
                description:
                    'Formularios para tipo de residuo, condicoes do material e metodos de volume, integrados ao endpoint de estimativa.',
                icon: Icons.construction_outlined,
              ),
              const SizedBox(height: 24),
              Text('Materiais previstos', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ...wasteOptions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      title: Text(item.label),
                      subtitle: Text(
                        'Densidade aparente inicial: ${item.densityHint}',
                      ),
                      leading: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Aviso: todo valor exibido pelo sistema deve ser tratado como estimativa, nunca como pesagem real.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7A4510),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
