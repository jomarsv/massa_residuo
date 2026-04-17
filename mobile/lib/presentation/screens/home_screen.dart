import 'package:flutter/material.dart';

import '../../data/models/estimate_response.dart';
import '../../data/models/estimation_record.dart';
import '../../data/models/option_item.dart';
import '../../data/models/waste_option.dart';
import '../../data/repositories/reference_data_repository.dart';
import '../../domain/entities/app_status.dart';
import '../../services/backend_service.dart';
import '../../widgets/result_metric_tile.dart';
import '../../widgets/status_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.backendService});

  final BackendService backendService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceRepository = const ReferenceDataRepository();

  final _containerCapacityController = TextEditingController(text: '1.0');
  final _fillPercentageController = TextEditingController(text: '50');
  final _lengthController = TextEditingController(text: '1.0');
  final _widthController = TextEditingController(text: '1.0');
  final _heightController = TextEditingController(text: '1.0');
  final _imagePathController = TextEditingController();
  final _notesController = TextEditingController();

  late Future<AppStatus> _statusFuture;
  late Future<List<EstimationRecord>> _historyFuture;

  late List<WasteOption> _wasteOptions;
  late List<OptionItem> _volumeMethods;
  late List<OptionItem> _moistureOptions;
  late List<OptionItem> _compactionOptions;
  late List<OptionItem> _heterogeneityOptions;

  String _selectedWasteType = 'plastico';
  String _selectedVolumeMethod = 'recipiente_conhecido';
  String _selectedMoistureCondition = 'seco';
  String _selectedCompactionCondition = 'solto';
  String _selectedHeterogeneityCondition = 'homogeneo';

  bool _isSubmitting = false;
  String? _submissionError;
  EstimateResponseModel? _latestEstimate;

  @override
  void initState() {
    super.initState();
    _wasteOptions = _referenceRepository.getDefaultWasteOptions();
    _volumeMethods = _referenceRepository.getVolumeMethods();
    _moistureOptions = _referenceRepository.getMoistureOptions();
    _compactionOptions = _referenceRepository.getCompactionOptions();
    _heterogeneityOptions = _referenceRepository.getHeterogeneityOptions();
    _statusFuture = widget.backendService.checkStatus();
    _historyFuture = widget.backendService.fetchHistory();
  }

  @override
  void dispose() {
    _containerCapacityController.dispose();
    _fillPercentageController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _imagePathController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitEstimate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final response = await widget.backendService.createEstimate(
        _buildPayload(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _latestEstimate = response;
        _historyFuture = widget.backendService.fetchHistory();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submissionError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{
      'waste_type': _selectedWasteType,
      'volume_method': _selectedVolumeMethod,
      'moisture_condition': _selectedMoistureCondition,
      'compaction_condition': _selectedCompactionCondition,
      'heterogeneity_condition': _selectedHeterogeneityCondition,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    };

    if (_selectedVolumeMethod == 'recipiente_conhecido') {
      payload['known_container'] = {
        'capacity_m3': double.parse(
          _containerCapacityController.text.replaceAll(',', '.'),
        ),
        'fill_percentage': double.parse(
          _fillPercentageController.text.replaceAll(',', '.'),
        ),
      };
    } else if (_selectedVolumeMethod == 'dimensoes_manuais') {
      payload['manual_dimensions'] = {
        'length_m': double.parse(_lengthController.text.replaceAll(',', '.')),
        'width_m': double.parse(_widthController.text.replaceAll(',', '.')),
        'height_m': double.parse(_heightController.text.replaceAll(',', '.')),
      };
    } else {
      payload['image_assisted'] = {
        'image_path': _imagePathController.text.trim().isEmpty
            ? null
            : _imagePathController.text.trim(),
        'notes': 'Entrada assistida por imagem via MVP',
      };
    }

    return payload;
  }

  String? _validateRequiredNumber(String? value, {double? min, double? max}) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatorio.';
    }

    final parsedValue = double.tryParse(value.replaceAll(',', '.'));
    if (parsedValue == null) {
      return 'Informe um numero valido.';
    }
    if (min != null && parsedValue < min) {
      return 'Valor minimo: $min';
    }
    if (max != null && parsedValue > max) {
      return 'Valor maximo: $max';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _statusFuture = widget.backendService.checkStatus();
                _historyFuture = widget.backendService.fetchHistory();
              });
              await Future.wait([_statusFuture, _historyFuture]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                Text(
                  'Estimativa de massa de residuos',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Fase 2: formulario completo, calculo via API e historico remoto com Firebase.',
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
                              : 'Backend indisponivel');

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
                _buildFormCard(theme),
                if (_latestEstimate != null) ...[
                  const SizedBox(height: 18),
                  _buildResultCard(theme, _latestEstimate!),
                ],
                const SizedBox(height: 18),
                _buildHistoryCard(theme),
                const SizedBox(height: 10),
                Text(
                  'Aviso: todo valor exibido pelo sistema deve ser tratado como estimativa, nunca como pesagem real.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A4510),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nova analise', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'O calculo usa densidade aparente, volume e fatores de correcao. A IA segue como apoio opcional.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _buildDropdown<String>(
                label: 'Tipo predominante de residuo',
                value: _selectedWasteType,
                items: _wasteOptions
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.value,
                        child: Text('${item.label} (${item.densityHint})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedWasteType = value!),
              ),
              const SizedBox(height: 14),
              _buildDropdown<String>(
                label: 'Metodo de estimativa de volume',
                value: _selectedVolumeMethod,
                items: _volumeMethods
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.value,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedVolumeMethod = value!),
              ),
              const SizedBox(height: 14),
              Wrap(
                runSpacing: 14,
                spacing: 14,
                children: [
                  SizedBox(
                    width: 260,
                    child: _buildDropdown<String>(
                      label: 'Umidade',
                      value: _selectedMoistureCondition,
                      items: _moistureOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.value,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedMoistureCondition = value!),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: _buildDropdown<String>(
                      label: 'Compactacao',
                      value: _selectedCompactionCondition,
                      items: _compactionOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.value,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCompactionCondition = value!),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: _buildDropdown<String>(
                      label: 'Heterogeneidade',
                      value: _selectedHeterogeneityCondition,
                      items: _heterogeneityOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.value,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _selectedHeterogeneityCondition = value!,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedVolumeMethod == 'recipiente_conhecido') ...[
                Wrap(
                  runSpacing: 14,
                  spacing: 14,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        controller: _containerCapacityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Capacidade do recipiente (m3)',
                        ),
                        validator: (value) =>
                            _validateRequiredNumber(value, min: 0.01),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        controller: _fillPercentageController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Percentual preenchido (%)',
                        ),
                        validator: (value) =>
                            _validateRequiredNumber(value, min: 0, max: 100),
                      ),
                    ),
                  ],
                ),
              ] else if (_selectedVolumeMethod == 'dimensoes_manuais') ...[
                Wrap(
                  runSpacing: 14,
                  spacing: 14,
                  children: [
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        controller: _lengthController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Comprimento (m)',
                        ),
                        validator: (value) =>
                            _validateRequiredNumber(value, min: 0.01),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        controller: _widthController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Largura (m)',
                        ),
                        validator: (value) =>
                            _validateRequiredNumber(value, min: 0.01),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Altura (m)',
                        ),
                        validator: (value) =>
                            _validateRequiredNumber(value, min: 0.01),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextFormField(
                  controller: _imagePathController,
                  decoration: const InputDecoration(
                    labelText: 'Caminho ou identificador da imagem',
                    helperText:
                        'Opcional no MVP. O backend ainda nao extrai volume automaticamente.',
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observacoes',
                  helperText:
                      'Ex.: material de obra, saco medio, pilha compactada.',
                ),
              ),
              if (_submissionError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _submissionError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF9E2A2B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitEstimate,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calculate_outlined),
                label: Text(
                  _isSubmitting ? 'Calculando...' : 'Calcular estimativa',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme, EstimateResponseModel estimate) {
    final result = estimate.result;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resultado da estimativa', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(result.disclaimer, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: ResultMetricTile(
                    label: 'Massa estimada',
                    value: '${result.estimatedMassKg.toStringAsFixed(2)} kg',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: ResultMetricTile(
                    label: 'Faixa de incerteza',
                    value:
                        '${result.lowerBoundKg.toStringAsFixed(2)} a ${result.upperBoundKg.toStringAsFixed(2)} kg',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: ResultMetricTile(
                    label: 'Volume considerado',
                    value: '${result.estimatedVolumeM3.toStringAsFixed(3)} m3',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: ResultMetricTile(
                    label: 'Densidade aplicada',
                    value: '${result.densityKgM3.toStringAsFixed(1)} kg/m3',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tipo: ${_referenceRepository.labelForWasteType(result.wasteType)} | Metodo: ${_referenceRepository.labelForVolumeMethod(result.volumeMethod)} | Confianca: ${_referenceRepository.labelForConfidence(result.confidenceLevel)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fatores aplicados: umidade ${result.appliedFactors.moistureFactor.toStringAsFixed(2)}, compactacao ${result.appliedFactors.compactionFactor.toStringAsFixed(2)}, mistura ${result.appliedFactors.heterogeneityFactor.toStringAsFixed(2)}.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Historico remoto',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _historyFuture = widget.backendService.fetchHistory();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<EstimationRecord>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Nao foi possivel carregar o historico remoto.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9E2A2B),
                    ),
                  );
                }

                final records = snapshot.data ?? const [];
                if (records.isEmpty) {
                  return Text(
                    'Nenhuma analise salva ainda.',
                    style: theme.textTheme.bodyMedium,
                  );
                }

                return Column(
                  children: records.map((record) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _referenceRepository.labelForWasteType(
                                record.wasteType,
                              ),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Estimativa: ${record.estimatedMassKg.toStringAsFixed(2)} kg | Volume: ${record.estimatedVolumeM3.toStringAsFixed(3)} m3',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Faixa: ${record.lowerBoundKg.toStringAsFixed(2)} a ${record.upperBoundKg.toStringAsFixed(2)} kg | Metodo: ${_referenceRepository.labelForVolumeMethod(record.volumeMethod)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Registro: ${record.createdAt.toLocal()}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                color: const Color(0xFF6A756C),
                              ),
                            ),
                            if (record.notes != null &&
                                record.notes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Observacoes: ${record.notes!}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }
}
