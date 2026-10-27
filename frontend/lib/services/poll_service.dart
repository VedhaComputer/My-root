import 'package:flutter/foundation.dart';
import '../models/poll.dart';
import '../repositories/poll_repository.dart';

class PollService extends ChangeNotifier {
  final PollRepository _repository;

  List<Poll> _polls = [];
  Poll? _currentPoll;
  bool _isLoading = false;
  String? _errorMessage;

  PollService({required PollRepository repository}) : _repository = repository;

  PollRepository get repository => _repository;
  List<Poll> get polls => _polls;
  Poll? get currentPoll => _currentPoll;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPolls({
    String? personName,
    String? placeId,
    String? targetEntityId,
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.getPolls(
      personName: personName,
      placeId: placeId,
      targetEntityId: targetEntityId,
      status: status,
      search: search,
      page: page,
      limit: limit,
    );

    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _polls = res.data!;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to load polls';
    }
    notifyListeners();
  }

  Future<Poll?> fetchPollById(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.getPollById(id);
    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _currentPoll = res.data!;
      final idx = _polls.indexWhere((p) => p.id == id);
      if (idx != -1) {
        _polls[idx] = res.data!;
      }
      notifyListeners();
      return _currentPoll;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to load poll';
      notifyListeners();
      return null;
    }
  }

  Future<Poll?> createPoll({
    String? personName,
    String? personRole,
    String? placeId,
    String? placeName,
    String? targetEntityId,
    String? question,
    String? description,
    String? photoUrl,
    String? purpose,
    String? category,
    List<Map<String, dynamic>>? people,
    List<Map<String, dynamic>>? questions,
    DateTime? startTime,
    DateTime? endTime,
    int? durationDays,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.createPoll(
      personName: personName,
      personRole: personRole,
      placeId: placeId,
      placeName: placeName,
      targetEntityId: targetEntityId,
      question: question,
      description: description,
      photoUrl: photoUrl,
      purpose: purpose,
      category: category,
      people: people,
      questions: questions,
      startTime: startTime,
      endTime: endTime,
      durationDays: durationDays,
    );

    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _polls.insert(0, res.data!);
      _currentPoll = res.data!;
      notifyListeners();
      return res.data;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to create poll';
      notifyListeners();
      return null;
    }
  }

  Future<Poll?> castVote({
    required String pollId,
    required String choice,
    required String reasonKey,
    String? explanation,
    String? questionId,
    String? personId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.vote(
      pollId: pollId,
      choice: choice,
      reasonKey: reasonKey,
      explanation: explanation,
      questionId: questionId,
      personId: personId,
    );

    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _currentPoll = res.data!;
      final idx = _polls.indexWhere((p) => p.id == pollId);
      if (idx != -1) {
        _polls[idx] = res.data!;
      }
      notifyListeners();
      return _currentPoll;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to cast vote';
      notifyListeners();
      return null;
    }
  }

  Future<Poll?> closePoll(String pollId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.closePoll(pollId);
    _isLoading = false;
    if (res.isSuccess && res.data != null) {
      _currentPoll = res.data!;
      final idx = _polls.indexWhere((p) => p.id == pollId);
      if (idx != -1) {
        _polls[idx] = res.data!;
      }
      notifyListeners();
      return _currentPoll;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to close poll';
      notifyListeners();
      return null;
    }
  }

  Future<bool> reportPoll({
    required String pollId,
    required String reason,
    String? details,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _repository.reportPoll(
      pollId: pollId,
      reason: reason,
      details: details,
    );

    _isLoading = false;
    if (res.isSuccess) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to report poll';
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadPersonPhoto({
    required List<int> fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    _errorMessage = null;
    final res = await _repository.uploadPersonPhoto(
      fileBytes: fileBytes,
      filename: filename,
      mimeType: mimeType,
    );
    if (res.isSuccess && res.data != null) {
      final photoUrl = res.data!['photoUrl'] as String?;
      return photoUrl;
    } else {
      _errorMessage = res.failure?.message ?? 'Failed to upload photo';
      notifyListeners();
      return null;
    }
  }
}
