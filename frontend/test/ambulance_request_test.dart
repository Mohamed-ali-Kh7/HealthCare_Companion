import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_companion/models/ambulance_request.dart';

/// Demande telle que renvoyée par l'API (champs minimaux), avec une mission facultative.
AmbulanceRequest _request({String type = 'SCHEDULED', String status = 'APPROVED', String? mission}) =>
    AmbulanceRequest.fromJson({
      'id': 1,
      'type': type,
      'status': status,
      'createdAt': '2026-11-20T08:00:00Z',
      'scheduledAt': '2099-01-01T09:00:00',
      'patient': {'id': 1, 'firstName': 'Youssef', 'lastName': 'Hammami'},
      'mission': mission == null
          ? null
          : {
              'status': mission,
              'company': {'id': 1, 'name': 'Ambulances Ennour', 'phone': '+216 71 000 000'},
            },
    });

void main() {
  group('AmbulanceRequest.canBeClosed (même règle que le backend)', () {
    test('urgence en cours ou transport validé sans société : clôture possible', () {
      expect(_request(type: 'EMERGENCY', status: 'DISPATCHED').canBeClosed, isTrue);
      expect(_request().canBeClosed, isTrue);
    });

    test('société sollicitée sans réponse, ou qui a refusé : clôture possible', () {
      expect(_request(mission: 'REQUESTED').canBeClosed, isTrue);
      expect(_request(mission: 'REFUSED').canBeClosed, isTrue);
    });

    test('véhicule affecté ou trajet en cours : seule la société clôture, à l\'arrivée', () {
      for (final m in ['ACCEPTED', 'EN_ROUTE', 'ON_SITE', 'IN_TRANSIT']) {
        expect(_request(mission: m).canBeClosed, isFalse, reason: m);
      }
    });

    test('demande annulée ou déjà clôturée : rien à clôturer', () {
      expect(_request(status: 'CANCELLED', mission: 'ACCEPTED').canBeClosed, isFalse);
      expect(_request(status: 'CLOSED', mission: 'ARRIVED').canBeClosed, isFalse);
    });
  });
}
