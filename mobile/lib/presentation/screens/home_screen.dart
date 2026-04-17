import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../data/models/estimate_response.dart';
import '../../data/models/estimation_record.dart';
import '../../data/models/image_analysis.dart';
import '../../data/models/image_volume_estimate.dart';
import '../../data/models/normalized_point.dart';
import '../../data/models/option_item.dart';
import '../../data/models/waste_option.dart';
import '../../data/repositories/reference_data_repository.dart';
import '../../domain/entities/app_status.dart';
import '../../services/backend_service.dart';
import '../../services/camera_capture_service.dart';
import '../../widgets/analysis_metric_chip.dart';
import '../../widgets/result_metric_tile.dart';
import '../../widgets/ruler_point_selector.dart';
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
  final _contentDescriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _actualMassController = TextEditingController();
  final _calibrationNotesController = TextEditingController();
  final _cameraCaptureService = buildCameraCaptureService();

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
  bool _isAnalyzingImage = false;
  bool _isEstimatingVolume = false;
  bool _isSavingCalibration = false;
  String? _submissionError;
  String? _imageAnalysisError;
  String? _volumeEstimationError;
  String? _calibrationError;
  String? _calibrationSuccess;
  EstimateResponseModel? _latestEstimate;
  ImageAnalysisResponse? _latestImageAnalysis;
  ImageVolumeEstimateResponse? _latestVolumeEstimate;
  PlatformFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  double? _selectedImageAspectRatio;
  List<NormalizedPoint> _rulerPoints = const [];

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
    _contentDescriptionController.dispose();
    _notesController.dispose();
    _actualMassController.dispose();
    _calibrationNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    _setSelectedImage(file: file, bytes: file.bytes, fileName: file.name);
  }

  Future<void> _captureImage() async {
    try {
      final captured = await _cameraCaptureService.captureImage();
      if (captured == null) {
        return;
      }

      _setSelectedImage(
        file: PlatformFile(
          name: captured.fileName,
          size: captured.bytes.lengthInBytes,
          bytes: captured.bytes,
          path: captured.path,
        ),
        bytes: captured.bytes,
        fileName: captured.fileName,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageAnalysisError = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', '');
      });
    }
  }

  void _setSelectedImage({
    required PlatformFile file,
    required Uint8List? bytes,
    required String fileName,
  }) {
    setState(() {
      _selectedImageFile = file;
      _selectedImageBytes = bytes;
      _imagePathController.text = fileName;
      _imageAnalysisError = null;
      _volumeEstimationError = null;
      _latestVolumeEstimate = null;
      _rulerPoints = const [];
      _selectedImageAspectRatio = _computeAspectRatio(bytes) ?? (4 / 3);
    });
  }

  double? _computeAspectRatio(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.height == 0) {
      return null;
    }

    return decoded.width / decoded.height;
  }

  void _addRulerPoint(NormalizedPoint point) {
    setState(() {
      _volumeEstimationError = null;
      _latestVolumeEstimate = null;
      if (_rulerPoints.length >= 2) {
        _rulerPoints = [point];
      } else {
        _rulerPoints = [..._rulerPoints, point];
      }
    });
  }

  void _clearRulerPoints() {
    setState(() {
      _rulerPoints = const [];
      _latestVolumeEstimate = null;
      _volumeEstimationError = null;
    });
  }

  Future<void> _analyzeSelectedImage() async {
    final file = _selectedImageFile;
    if (file == null) {
      setState(() {
        _imageAnalysisError =
            'Selecione uma imagem antes de solicitar a analise.';
      });
      return;
    }

    setState(() {
      _isAnalyzingImage = true;
      _imageAnalysisError = null;
    });

    try {
      final analysis = await widget.backendService.analyzeImage(
        file,
        contentDescription: _contentDescriptionController.text,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _latestImageAnalysis = analysis;
        if (analysis.suggestion.suggestedWasteType != null) {
          _selectedWasteType = analysis.suggestion.suggestedWasteType!;
        }

        final currentNotes = _notesController.text.trim();
        final analysisNote =
            'Imagem analisada: ${analysis.filename}. ${analysis.suggestion.rationale}';
        _notesController.text = currentNotes.isEmpty
            ? analysisNote
            : '$currentNotes\n$analysisNote';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageAnalysisError = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingImage = false;
        });
      }
    }
  }

  Future<void> _estimateVolumeFromRuler() async {
    final file = _selectedImageFile;
    if (file == null || _rulerPoints.length != 2) {
      setState(() {
        _volumeEstimationError =
            'Selecione uma imagem e marque os 2 pontos que representam 1 metro na regua.';
      });
      return;
    }

    setState(() {
      _isEstimatingVolume = true;
      _volumeEstimationError = null;
    });

    try {
      final estimate = await widget.backendService.estimateImageVolume(
        file,
        rulerPointA: _rulerPoints[0],
        rulerPointB: _rulerPoints[1],
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _latestVolumeEstimate = estimate;
        _selectedVolumeMethod = 'estimativa_assistida_imagem';
        final currentNotes = _notesController.text.trim();
        final volumeNote =
            'Volume assistido por regua: ${estimate.estimatedVolumeM3.toStringAsFixed(3)} m3. ${estimate.rationale}';
        _notesController.text = currentNotes.isEmpty
            ? volumeNote
            : '$currentNotes\n$volumeNote';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _volumeEstimationError = error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEstimatingVolume = false;
        });
      }
    }
  }

  Future<void> _submitEstimate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVolumeMethod == 'estimativa_assistida_imagem' &&
        _latestVolumeEstimate == null) {
      setState(() {
        _submissionError =
            'A estimativa por imagem exige calibracao pela regua. Marque os 2 pontos de 1 metro e clique em estimar volume antes de calcular a massa.';
      });
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
        _actualMassController.clear();
        _calibrationNotesController.clear();
        _calibrationError = null;
        _calibrationSuccess = null;
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

  Future<void> _saveCalibration() async {
    final latestEstimate = _latestEstimate;
    if (latestEstimate == null) {
      return;
    }

    final actualMass = double.tryParse(
      _actualMassController.text.trim().replaceAll(',', '.'),
    );
    if (actualMass == null || actualMass <= 0) {
      setState(() {
        _calibrationError = 'Informe um peso real valido em kg.';
      });
      return;
    }

    setState(() {
      _isSavingCalibration = true;
      _calibrationError = null;
      _calibrationSuccess = null;
    });

    try {
      final updatedRecord = await widget.backendService.calibrateEstimate(
        recordId: latestEstimate.record.id,
        actualMassKg: actualMass,
        notes: _calibrationNotesController.text.trim().isEmpty
            ? null
            : _calibrationNotesController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _latestEstimate = EstimateResponseModel(
          result: latestEstimate.result,
          record: updatedRecord,
        );
        _historyFuture = widget.backendService.fetchHistory();
        _calibrationSuccess =
            'Peso real salvo. As proximas estimativas por imagem podem usar essa calibracao.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _calibrationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingCalibration = false;
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
      'content_description': _contentDescriptionController.text.trim().isEmpty
          ? null
          : _contentDescriptionController.text.trim(),
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
        'estimated_volume_m3': _latestVolumeEstimate?.estimatedVolumeM3,
        'estimated_length_m': _latestVolumeEstimate?.estimatedLengthM,
        'estimated_height_m': _latestVolumeEstimate?.estimatedHeightM,
        'estimated_depth_m': _latestVolumeEstimate?.estimatedDepthM,
        'confidence_score': _latestVolumeEstimate?.confidenceScore,
        'notes':
            _latestVolumeEstimate?.rationale ??
            _latestImageAnalysis?.suggestion.rationale ??
            'Entrada assistida por imagem via MVP',
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
                  'Fase 3.5: descricao textual do conteudo, analise assistida por imagem e preenchimento hibrido antes do calculo.',
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
                _buildImageAssistCard(theme),
                const SizedBox(height: 18),
                _buildFormCard(theme),
                if (_latestEstimate != null) ...[
                  const SizedBox(height: 18),
                  _buildResultCard(theme, _latestEstimate!),
                ],
                const SizedBox(height: 18),
                _buildHistoryCard(theme),
                const SizedBox(height: 10),
                Text(
                  'Aviso: a imagem apenas sugere preenchimento. O usuario continua responsavel por confirmar o tipo de residuo e o metodo de volume.',
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

  Widget _buildImageAssistCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analise assistida por imagem',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Selecione uma imagem do residuo, descreva o conteudo observado e marque os 2 pontos da regua que representam 1 metro para estimar o volume aparente.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentDescriptionController,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'O que ha no resíduo ou dentro dos sacos?',
                helperText:
                    'Ex.: folhas, galhos, restos de poda, latas, papelao, entulho de obra.',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Selecionar imagem'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _captureImage,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Usar camera'),
                ),
                OutlinedButton.icon(
                  onPressed: _isAnalyzingImage ? null : _analyzeSelectedImage,
                  icon: _isAnalyzingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.center_focus_strong_outlined),
                  label: Text(
                    _isAnalyzingImage ? 'Analisando...' : 'Analisar imagem',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _rulerPoints.isEmpty ? null : _clearRulerPoints,
                  icon: const Icon(Icons.clear_outlined),
                  label: const Text('Limpar pontos'),
                ),
              ],
            ),
            if (_selectedImageFile != null) ...[
              const SizedBox(height: 16),
              Text(
                'Arquivo selecionado: ${_selectedImageFile!.name}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toque em 2 pontos da imagem para marcar o trecho de 1 metro da regua. Se marcar errado, clique em limpar pontos.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (_selectedImageBytes != null) ...[
              const SizedBox(height: 12),
              RulerPointSelector(
                imageBytes: _selectedImageBytes!,
                aspectRatio: _selectedImageAspectRatio ?? (4 / 3),
                points: _rulerPoints,
                onTapNormalized: _addRulerPoint,
              ),
              if (_rulerPoints.length == 2) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isEstimatingVolume
                      ? null
                      : _estimateVolumeFromRuler,
                  icon: _isEstimatingVolume
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.straighten_outlined),
                  label: Text(
                    _isEstimatingVolume
                        ? 'Estimando volume...'
                        : 'Estimar volume pela regua',
                  ),
                ),
              ],
            ],
            if (_imageAnalysisError != null) ...[
              const SizedBox(height: 12),
              Text(
                _imageAnalysisError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9E2A2B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_volumeEstimationError != null) ...[
              const SizedBox(height: 12),
              Text(
                _volumeEstimationError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9E2A2B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_latestImageAnalysis != null) ...[
              const SizedBox(height: 16),
              _buildImageAnalysisSummary(theme, _latestImageAnalysis!),
            ],
            if (_latestVolumeEstimate != null) ...[
              const SizedBox(height: 16),
              _buildVolumeEstimateSummary(theme, _latestVolumeEstimate!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageAnalysisSummary(
    ThemeData theme,
    ImageAnalysisResponse analysis,
  ) {
    final suggestion = analysis.suggestion;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sugestao assistida', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            suggestion.suggestedWasteType == null
                ? 'Nenhum tipo sugerido com confianca suficiente.'
                : 'Tipo sugerido: ${_referenceRepository.labelForWasteType(suggestion.suggestedWasteType!)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Confianca: ${suggestion.confidenceLabel} (${suggestion.confidenceScore.toStringAsFixed(2)})',
            style: theme.textTheme.bodyMedium,
          ),
          if (suggestion.usedUserContext &&
              suggestion.contextSummary != null) ...[
            const SizedBox(height: 6),
            Text(
              'Contexto do usuario: ${suggestion.contextSummary}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(suggestion.rationale, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AnalysisMetricChip(
                label: 'Resolucao',
                value:
                    '${analysis.metrics.widthPx}x${analysis.metrics.heightPx}',
              ),
              AnalysisMetricChip(
                label: 'Brilho',
                value: analysis.metrics.meanBrightness.toStringAsFixed(1),
              ),
              AnalysisMetricChip(
                label: 'Saturacao',
                value: analysis.metrics.meanSaturation.toStringAsFixed(1),
              ),
              AnalysisMetricChip(
                label: 'Bordas',
                value: analysis.metrics.edgeDensity.toStringAsFixed(3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(analysis.disclaimer, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildVolumeEstimateSummary(
    ThemeData theme,
    ImageVolumeEstimateResponse estimate,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Volume assistido por regua',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Volume estimado: ${estimate.estimatedVolumeM3.toStringAsFixed(3)} m3',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Confianca: ${estimate.confidenceLabel} (${estimate.confidenceScore.toStringAsFixed(2)})',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(estimate.rationale, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AnalysisMetricChip(
                label: 'Comprimento',
                value: '${estimate.estimatedLengthM.toStringAsFixed(2)} m',
              ),
              AnalysisMetricChip(
                label: 'Altura',
                value: '${estimate.estimatedHeightM.toStringAsFixed(2)} m',
              ),
              AnalysisMetricChip(
                label: 'Profundidade',
                value: '${estimate.estimatedDepthM.toStringAsFixed(2)} m',
              ),
              AnalysisMetricChip(
                label: 'Px por metro',
                value: estimate.metrics.pixelsPerMeter.toStringAsFixed(1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(estimate.disclaimer, style: theme.textTheme.bodyMedium),
        ],
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
                'O calculo continua fisico-matematico. A imagem pode orientar a classificacao e, quando calibrada pela regua, fornecer um volume aparente semiautomatico.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              if (_contentDescriptionController.text.trim().isNotEmpty) ...[
                Text(
                  'Conteudo informado: ${_contentDescriptionController.text.trim()}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
              ],
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _imagePathController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Imagem selecionada',
                        helperText:
                            'Use a secao de analise assistida para enviar a imagem.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _latestVolumeEstimate == null
                          ? 'Marque os 2 pontos de 1 metro da regua e gere o volume assistido antes de calcular a massa por imagem.'
                          : 'Volume assistido pronto: ${_latestVolumeEstimate!.estimatedVolumeM3.toStringAsFixed(3)} m3. Voce ja pode calcular a massa usando este metodo.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7A4510),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 5,
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
            const SizedBox(height: 8),
            Text(
              'Multiplicador de calibracao historica: ${result.calibrationMultiplier.toStringAsFixed(3)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (estimate.record.contentDescription != null &&
                estimate.record.contentDescription!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Conteudo informado: ${estimate.record.contentDescription!}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            Text('Calibrar com peso real', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Informe o peso medido em balanca para refinar futuras estimativas por imagem do mesmo tipo de residuo.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _actualMassController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Peso real (kg)',
                    ),
                  ),
                ),
                SizedBox(
                  width: 340,
                  child: TextFormField(
                    controller: _calibrationNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Observacoes da calibracao',
                    ),
                  ),
                ),
              ],
            ),
            if (estimate.record.actualMassKg != null) ...[
              const SizedBox(height: 8),
              Text(
                'Peso real salvo: ${estimate.record.actualMassKg!.toStringAsFixed(2)} kg',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_calibrationError != null) ...[
              const SizedBox(height: 10),
              Text(
                _calibrationError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9E2A2B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_calibrationSuccess != null) ...[
              const SizedBox(height: 10),
              Text(
                _calibrationSuccess!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF236B3A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _isSavingCalibration ? null : _saveCalibration,
              icon: _isSavingCalibration
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.scale_outlined),
              label: Text(
                _isSavingCalibration
                    ? 'Salvando calibracao...'
                    : 'Salvar peso real',
              ),
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
                            if (record.contentDescription != null &&
                                record.contentDescription!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Conteudo informado: ${record.contentDescription!}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                            if (record.actualMassKg != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Peso real: ${record.actualMassKg!.toStringAsFixed(2)} kg',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (record.calibrationNotes != null &&
                                record.calibrationNotes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Notas da calibracao: ${record.calibrationNotes!}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
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
