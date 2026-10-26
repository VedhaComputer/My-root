import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import '../models/place.dart';
import '../repositories/place_repository.dart';

class PlaceService extends ChangeNotifier {
  final PlaceRepository _repository;

  List<Place> _places = [];
  Place? _selectedPlace;
  String? _selectedPlaceUserId;
  List<Place> _children = [];
  bool _isLoading = false;
  String? _errorMessage;
  Future<Place?>? _resolveFuture;
  String? _resolvingPlaceId;
  String? _resolvingPlaceUserId;
  int _resolveGeneration = 0;

  PlaceService({required PlaceRepository repository}) : _repository = repository;

  PlaceRepository get repository => _repository;
  List<Place> get places => _places;
  Place? get selectedPlace => _selectedPlace;
  String? get selectedPlaceUserId => _selectedPlaceUserId;
  List<Place> get children => _children;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setSelectedPlace(Place? place, {String? userId}) {
    if (_selectedPlace?.id != place?.id || _selectedPlaceUserId != userId) {
      _selectedPlace = place;
      _selectedPlaceUserId = userId;
      _resolveFuture = null;
      _resolvingPlaceId = null;
      _resolvingPlaceUserId = null;
      _resolveGeneration++;
      notifyListeners();
    }
  }

  void clearSelectedPlace({bool notify = true}) {
    if (_selectedPlace != null || _selectedPlaceUserId != null || _resolvingPlaceId != null || _resolvingPlaceUserId != null) {
      _selectedPlace = null;
      _selectedPlaceUserId = null;
      _resolveFuture = null;
      _resolvingPlaceId = null;
      _resolvingPlaceUserId = null;
      _resolveGeneration++;
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<Place?> resolveSelectedPlace(String placeId, {String? userId}) {
    if (_selectedPlace?.id == placeId && _selectedPlaceUserId == userId) {
      return Future.value(_selectedPlace);
    }
    if (_resolvingPlaceId == placeId && _resolvingPlaceUserId == userId && _resolveFuture != null) {
      return _resolveFuture!;
    }
    _resolvingPlaceId = placeId;
    _resolvingPlaceUserId = userId;
    final gen = ++_resolveGeneration;
    _resolveFuture = _performResolveSelectedPlace(placeId, gen, userId: userId);
    return _resolveFuture!;
  }

  Future<Place?> _performResolveSelectedPlace(String placeId, int generation, {String? userId}) async {
    try {
      final detailResult = await _repository.getPlaceById(placeId);
      if (generation != _resolveGeneration) {
        return null;
      }
      if (detailResult.isSuccess && detailResult.data != null) {
        _selectedPlace = detailResult.data;
        _selectedPlaceUserId = userId;
        notifyListeners();
        return _selectedPlace;
      }
      return null;
    } finally {
      if (_resolvingPlaceId == placeId && _resolvingPlaceUserId == userId && generation == _resolveGeneration) {
        _resolveFuture = null;
        _resolvingPlaceId = null;
        _resolvingPlaceUserId = null;
      }
    }
  }

  Future<void> fetchPlaces({
    String? level,
    String? parentId,
    String? search,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getPlaces(
      level: level,
      parentId: parentId,
      search: search,
    );

    _isLoading = false;
    if (result.isSuccess && result.data != null) {
      _places = result.data!;
    } else {
      _errorMessage = result.failure?.message ?? 'Failed to load places';
    }
    notifyListeners();
  }

  Future<void> fetchPlaceDetail(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final detailResult = await _repository.getPlaceById(id);
    if (detailResult.isSuccess && detailResult.data != null) {
      _selectedPlace = detailResult.data;
      final childrenResult = await _repository.getChildren(id);
      if (childrenResult.isSuccess && childrenResult.data != null) {
        _children = childrenResult.data!;
      } else {
        _children = [];
      }
    } else {
      _errorMessage = detailResult.failure?.message ?? 'Failed to load place details';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<ApiResponse<Place>> createPlace({
    required String level,
    required String canonicalName,
    required List<PlaceName> names,
    String? parentId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.createPlace(
      level: level,
      canonicalName: canonicalName,
      names: names,
      parentId: parentId,
    );

    _isLoading = false;
    if (result.isSuccess && result.data != null) {
      _places = [result.data!, ..._places];
    } else {
      _errorMessage = result.failure?.message ?? 'Failed to create place';
    }
    notifyListeners();
    return result;
  }

  Future<bool> deletePlace(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.deletePlace(id);
    _isLoading = false;

    if (result.isSuccess) {
      _places = _places.where((p) => p.id != id).toList();
      if (_selectedPlace?.id == id) {
        _selectedPlace = null;
      }
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.failure?.message ?? 'Failed to delete place';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
