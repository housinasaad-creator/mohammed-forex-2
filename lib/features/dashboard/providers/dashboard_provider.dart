import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/asset_model.dart';
import '../models/analysis_result.dart';
import '../../../services/analysis_service.dart';
import '../../../core/services/forex_service.dart';

enum AnalysisState { idle, loading, done, error }

class DashboardProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────

  Asset _selectedAsset = AssetCatalogue.forexMajor.first;
  final Timeframe _selectedTimeframe = Timeframe.m30;
  AnalysisState _state = AnalysisState.idle;
  AnalysisResult? _result;
  String _errorMessage = '';
  bool _mt5Connected = true; // simulated

  DashboardProvider() {
    _pingBridge();
  }

  // Fire-and-forget ping to wake Render.com free-tier bridge before user clicks Analyze
  Future<void> _pingBridge() async {
    try {
      await http.get(Uri.parse('https://forex-bridge.onrender.com/health'))
          .timeout(const Duration(seconds: 30));
    } catch (_) {}
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  Asset get selectedAsset     => _selectedAsset;
  Timeframe get selectedTimeframe => _selectedTimeframe;
  AnalysisState get state     => _state;
  AnalysisResult? get result  => _result;
  String get errorMessage     => _errorMessage;
  bool get mt5Connected       => _mt5Connected;
  bool get isLoading          => _state == AnalysisState.loading;

  // ── Actions ────────────────────────────────────────────────────────────────

  void selectAsset(Asset asset) {
    if (_selectedAsset.symbol == asset.symbol) return;
    _selectedAsset = asset;
    _result = null;
    _state = AnalysisState.idle;
    notifyListeners();
  }

  Future<void> runAnalysis({String lang = 'en'}) async {
    if (_state == AnalysisState.loading) return;

    _state = AnalysisState.loading;
    _result = null;
    _errorMessage = '';
    notifyListeners();

    try {
      // Fetch live price before analysis so entry point is real, not hardcoded
      final prices = await ForexService.fetchPrices();
      final livePrice = prices[_selectedAsset.symbol];

      final result = await AnalysisService.analyze(
        asset: _selectedAsset,
        timeframe: _selectedTimeframe,
        lang: lang,
        livePrice: livePrice,
      );
      _result = result;
      _state = AnalysisState.done;
    } catch (e, st) {
      debugPrint('[DashboardProvider] runAnalysis exception: $e\n$st');
      _errorMessage = 'Analysis failed: ${e.toString()}';
      _state = AnalysisState.error;
    }
    notifyListeners();
  }

  void clearResult() {
    _result = null;
    _state = AnalysisState.idle;
    notifyListeners();
  }

  void toggleMt5Connection() {
    _mt5Connected = !_mt5Connected;
    notifyListeners();
  }
}
