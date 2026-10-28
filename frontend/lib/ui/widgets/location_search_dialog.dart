import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/place.dart';
import '../../services/place_service.dart';

class LocationSearchDialog extends StatefulWidget {
  final PlaceService placeService;
  final String? currentPlaceId;
  final String? currentPlaceName;

  const LocationSearchDialog({
    super.key,
    required this.placeService,
    this.currentPlaceId,
    this.currentPlaceName,
  });

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  final _searchController = TextEditingController();
  List<Place> _filteredPlaces = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedLevel;

  /// Debounce timer: fires the search 350 ms after the last keystroke.
  Timer? _debounce;

  /// Monotonically increasing counter used to detect and discard stale responses.
  int _searchSequence = 0;

  final List<String> _levels = [
    PlaceLevel.village,
    PlaceLevel.cityTown,
    PlaceLevel.district,
    PlaceLevel.state,
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _debounce?.cancel();
      _searchSequence++;
      if (mounted) {
        setState(() {
          _filteredPlaces = [];
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    // Cancel the previous pending debounce timer.
    _debounce?.cancel();
    // Show loading indicator immediately so the UI feels responsive.
    if (mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    // Capture the sequence number for this particular request.
    _searchSequence++;
    final mySequence = _searchSequence;

    if (mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await widget.placeService.fetchPlaces(
        search: query,
        level: _selectedLevel,
      );

      // Discard response if a newer request has been issued since this one started.
      if (!mounted || mySequence != _searchSequence) return;

      if (widget.placeService.errorMessage != null && widget.placeService.places.isEmpty) {
        setState(() {
          _errorMessage = widget.placeService.errorMessage;
          _isLoading = false;
        });
        return;
      }

      final rawPlaces = widget.placeService.places;
      final q = query.toLowerCase();

      // Case-insensitive substring matching on canonicalName and localized names
      final matched = rawPlaces.where((place) {
        if (place.canonicalName.toLowerCase().contains(q)) return true;
        for (final nameObj in place.names) {
          if (nameObj.name.toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();

      setState(() {
        _filteredPlaces = matched.isNotEmpty ? matched : rawPlaces;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || mySequence != _searchSequence) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onLevelSelected(String? level) {
    setState(() {
      _selectedLevel = level;
    });
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _debounce?.cancel();
      _performSearch(query);
    }
  }

  String _formatLevel(String level) {
    return switch (level) {
      'COUNTRY' => 'Country',
      'STATE' => 'State',
      'DISTRICT' => 'District',
      'TEHSIL' => 'Tehsil',
      'CITY_TOWN' => 'City / Town',
      'VILLAGE' => 'Village',
      _ => level,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      key: const Key('location_search_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.location_on, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Select Location',
                          key: const Key('location_dialog_title'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.currentPlaceName != null && widget.currentPlaceName!.isNotEmpty)
                          Text(
                            'Current: ${widget.currentPlaceName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('location_search_dialog_close'),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search TextField
              TextField(
                key: const Key('location_search_input'),
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search city, town, or village...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          key: const Key('location_search_clear'),
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: _selectedLevel == null,
                        label: const Text('All Levels', style: TextStyle(fontSize: 12)),
                        onSelected: (_) => _onLevelSelected(null),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    ..._levels.map((lvl) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: _selectedLevel == lvl,
                          label: Text(_formatLevel(lvl), style: const TextStyle(fontSize: 12)),
                          onSelected: (selected) => _onLevelSelected(selected ? lvl : null),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              // Content / Results area
              Expanded(
                child: _buildContent(context, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    // 1. Empty query state: Do not dump unnecessary full location list
    if (_searchController.text.trim().isEmpty) {
      return Center(
        key: const Key('location_search_prompt'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 48, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'Type to search locations',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter a city, town, or village name',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 2. Loading state
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 3. Error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 36),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => _performSearch(_searchController.text.trim()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // 4. No matching results
    if (_filteredPlaces.isEmpty) {
      return Center(
        key: const Key('location_search_no_results'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, size: 48, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'No locations found matching "${_searchController.text.trim()}"',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Check spelling or try a different place name',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 5. Matching results list
    return ListView.separated(
      key: const Key('location_search_results_list'),
      itemCount: _filteredPlaces.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final place = _filteredPlaces[index];
        final isSelected = widget.currentPlaceId == place.id;
        return ListTile(
          key: Key('location_item_${place.id}'),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.place,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          title: Text(
            place.canonicalName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? theme.colorScheme.primary : null,
            ),
          ),
          subtitle: Text(
            _formatLevel(place.level),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check_circle, size: 20, color: theme.colorScheme.primary)
              : null,
          onTap: () {
            Navigator.of(context).pop(place);
          },
        );
      },
    );
  }
}
