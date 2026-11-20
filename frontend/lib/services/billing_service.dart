import '../core/network/api_client.dart';
import '../models/invoice.dart';

/// Facturation : le médecin facture ses consultations terminées, la société d'ambulance ses transports terminés,
/// le patient paie (paiement simulé).
class BillingService {
  BillingService(this._api);

  final ApiClient _api;

  static const _base = '/api/billing';

  /// [company] : espace de la société d'ambulance (transports) au lieu de celui du médecin (consultations).
  static String _space(bool company) => company ? '$_base/company' : '$_base/doctor';

  Future<List<CareActOption>> getActs() async => (await _api.get('$_base/acts') as List)
      .map((e) => CareActOption.fromJson(e as Map<String, dynamic>))
      .toList();

  // ---------------------------------------------------------------- Médecin ou société

  Future<BillingSummary> getSummary({bool company = false}) async =>
      BillingSummary.fromJson(await _api.get('${_space(company)}/summary') as Map<String, dynamic>);

  Future<List<ToInvoice>> getToInvoice({bool company = false}) async =>
      (await _api.get('${_space(company)}/to-invoice') as List)
          .map((e) => ToInvoice.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<List<Invoice>> getIssuedInvoices({bool company = false}) async =>
      _list(await _api.get('${_space(company)}/invoices'));

  /// Consultation ([appointmentId]) ou transport ([ambulanceRequestId]).
  Future<Invoice> create({
    int? appointmentId,
    int? ambulanceRequestId,
    required String act,
    required double amount,
    required CnamCoverage coverage,
  }) async =>
      _one(await _api.post('${_space(ambulanceRequestId != null)}/invoices', body: {
        'appointmentId': appointmentId,
        'ambulanceRequestId': ambulanceRequestId,
        'act': act,
        'amount': amount,
        'coverage': coverage.apiValue,
      }));

  Future<Invoice> markPaidInCash(int id, {bool company = false}) async =>
      _one(await _api.put('${_space(company)}/invoices/$id/cash'));

  // ---------------------------------------------------------------- Patient

  Future<List<Invoice>> getMine() async => _list(await _api.get('$_base/my/invoices'));

  /// Paiement par carte (simulé) : les données de carte ne sont pas conservées.
  Future<Invoice> pay(
    int id, {
    required String holder,
    required String cardNumber,
    required String expiry,
    required String cvv,
  }) async =>
      _one(await _api.post('$_base/my/invoices/$id/pay', body: {
        'holder': holder,
        'cardNumber': cardNumber,
        'expiry': expiry,
        'cvv': cvv,
      }));

  List<Invoice> _list(dynamic json) =>
      (json as List).map((e) => Invoice.fromJson(e as Map<String, dynamic>)).toList();

  Invoice _one(dynamic json) => Invoice.fromJson(json as Map<String, dynamic>);
}
