import '../models/waste_option.dart';

class ReferenceDataRepository {
  const ReferenceDataRepository();

  List<WasteOption> getDefaultWasteOptions() {
    return const [
      WasteOption(
        value: 'plastico',
        label: 'Plastico',
        densityHint: '45 kg/m3',
      ),
      WasteOption(
        value: 'papel_papelao',
        label: 'Papel/Papelao',
        densityHint: '85 kg/m3',
      ),
      WasteOption(
        value: 'organico',
        label: 'Organico',
        densityHint: '420 kg/m3',
      ),
      WasteOption(
        value: 'entulho',
        label: 'Entulho',
        densityHint: '1350 kg/m3',
      ),
      WasteOption(value: 'metal', label: 'Metal', densityHint: '280 kg/m3'),
    ];
  }
}
