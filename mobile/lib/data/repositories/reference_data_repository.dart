import '../models/option_item.dart';
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

  List<OptionItem> getVolumeMethods() {
    return const [
      OptionItem(
        value: 'recipiente_conhecido',
        label: 'Recipiente conhecido',
        hint: 'Capacidade fixa e percentual preenchido',
      ),
      OptionItem(
        value: 'dimensoes_manuais',
        label: 'Dimensoes manuais',
        hint: 'Comprimento, largura e altura em metros',
      ),
      OptionItem(
        value: 'estimativa_assistida_imagem',
        label: 'Estimativa assistida por imagem',
        hint: 'Estrutura preparada; volume automatico ainda nao implementado',
      ),
    ];
  }

  List<OptionItem> getMoistureOptions() {
    return const [
      OptionItem(value: 'seco', label: 'Seco'),
      OptionItem(value: 'umido', label: 'Umido'),
    ];
  }

  List<OptionItem> getCompactionOptions() {
    return const [
      OptionItem(value: 'solto', label: 'Solto'),
      OptionItem(value: 'compactado', label: 'Compactado'),
    ];
  }

  List<OptionItem> getHeterogeneityOptions() {
    return const [
      OptionItem(value: 'homogeneo', label: 'Homogeneo'),
      OptionItem(value: 'misto', label: 'Misto'),
    ];
  }

  String labelForWasteType(String value) {
    return {
          'plastico': 'Plastico',
          'papel_papelao': 'Papel/Papelao',
          'organico': 'Organico',
          'entulho': 'Entulho',
          'metal': 'Metal',
        }[value] ??
        value;
  }

  String labelForVolumeMethod(String value) {
    return {
          'recipiente_conhecido': 'Recipiente conhecido',
          'dimensoes_manuais': 'Dimensoes manuais',
          'estimativa_assistida_imagem': 'Estimativa assistida por imagem',
        }[value] ??
        value;
  }

  String labelForConfidence(String value) {
    return {
          'media-alta': 'Media-alta',
          'media': 'Media',
          'baixa-media': 'Baixa-media',
        }[value] ??
        value;
  }
}
