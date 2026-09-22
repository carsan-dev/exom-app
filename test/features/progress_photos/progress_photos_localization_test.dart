import 'package:exom_app/l10n/app_localizations_en.dart';
import 'package:exom_app/l10n/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress photos labels are localized for English and Spanish', () {
    final en = AppLocalizationsEn();
    final es = AppLocalizationsEs();

    expect(en.progressPhotosTitle, 'Progress photos');
    expect(en.progressPhotosLoadMore, 'Load more');
    expect(en.progressPhotosRecoveryError, 'We could not recover the selected photo. Try selecting it again.');
    expect(es.progressPhotosTitle, 'Fotos de progreso');
    expect(es.progressPhotosFront, 'Frontal');
    expect(es.progressPhotosIncomplete, 'Sesión incompleta');
    expect(es.progressPhotosRecoveryError, 'No se pudo recuperar la foto seleccionada. Selecciónala de nuevo.');
  });
}
