import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../models/place.dart';
import '../../../services/place_service.dart';
import '../../card/place_card.dart';
import 'place_detail_page.dart';

class PlacesPage extends StatefulWidget {
  final PlaceService placeService;
  final bool isSelectionMode;
  final ValueChanged<Place>? onPlaceSelected;

  const PlacesPage({
    super.key,
    required this.placeService,
    this.isSelectionMode = false,
    this.onPlaceSelected,
  });

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  final _searchController = TextEditingController();
  String? _selectedLevel;

  final List<String> _levels = [
    PlaceLevel.country,
    PlaceLevel.state,
    PlaceLevel.district,
    PlaceLevel.tehsil,
    PlaceLevel.cityTown,
    PlaceLevel.village,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPlaces();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    await widget.placeService.fetchPlaces(
      level: _selectedLevel,
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
    );
  }

  void _onLevelSelected(String? level) {
    setState(() {
      _selectedLevel = level;
    });
    _loadPlaces();
  }

  void _onSearchSubmitted(String query) {
    _loadPlaces();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Select a Place' : l10n.placesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retryButton,
            onPressed: _loadPlaces,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePlaceDialog,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.addPlaceButton),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchSubmitted,
                decoration: InputDecoration(
                  hintText: l10n.searchPlaces,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadPlaces();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            // Level Filter Chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _selectedLevel == null,
                      label: Text(l10n.allLevels),
                      onSelected: (_) => _onLevelSelected(null),
                    ),
                  ),
                  ..._levels.map((lvl) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _selectedLevel == lvl,
                        label: Text(_formatLevelLabel(lvl, l10n)),
                        onSelected: (selected) {
                          _onLevelSelected(selected ? lvl : null);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 16),
            // Places List or State Views
            Expanded(
              child: AnimatedBuilder(
                animation: widget.placeService,
                builder: (context, _) {
                  if (widget.placeService.isLoading) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(l10n.loadingLabel),
                        ],
                      ),
                    );
                  }

                  if (widget.placeService.errorMessage != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                            const SizedBox(height: 12),
                            Text(
                              widget.placeService.errorMessage!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _loadPlaces,
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.retryButton),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final places = widget.placeService.places;
                  if (places.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off_outlined,
                                size: 56, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noPlacesFound,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: places.length,
                    padding: const EdgeInsets.only(bottom: 80, top: 4),
                    itemBuilder: (context, index) {
                      final place = places[index];
                      return PlaceCard(
                        place: place,
                        onTap: () {
                          if (widget.isSelectionMode || widget.onPlaceSelected != null) {
                            widget.onPlaceSelected?.call(place);
                            Navigator.of(context).pop(place);
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaceDetailPage(
                                placeId: place.id,
                                initialPlace: place,
                                placeService: widget.placeService,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaceDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final localNameController = TextEditingController();
    String selectedLevel = PlaceLevel.country;
    String? parentId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.addPlaceButton),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedLevel,
                        decoration: InputDecoration(labelText: l10n.levelLabel),
                        items: _levels.map((lvl) {
                          return DropdownMenuItem(
                            value: lvl,
                            child: Text(_formatLevelLabel(lvl, l10n)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedLevel = val;
                              if (val == PlaceLevel.country) {
                                parentId = null;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: l10n.canonicalNameLabel),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return l10n.enterCanonicalName;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: localNameController,
                        decoration: InputDecoration(
                          labelText: '${l10n.localizedNamesLabel} (Hindi / Local)',
                        ),
                      ),
                      if (selectedLevel != PlaceLevel.country) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: parentId,
                          decoration: InputDecoration(labelText: l10n.parentPlaceLabel),
                          items: widget.placeService.places.map((p) {
                            return DropdownMenuItem(
                              value: p.id,
                              child: Text('${p.canonicalName} (${p.level})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              parentId = val;
                            });
                          },
                          validator: (val) {
                            if (selectedLevel != PlaceLevel.country && (val == null || val.isEmpty)) {
                              return l10n.enterCanonicalName;
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(l10n.cancelButton),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final names = <PlaceName>[
                      PlaceName(language: 'en', name: nameController.text.trim()),
                    ];
                    if (localNameController.text.trim().isNotEmpty) {
                      names.add(
                        PlaceName(language: 'hi', name: localNameController.text.trim()),
                      );
                    }

                    final res = await widget.placeService.createPlace(
                      level: selectedLevel,
                      canonicalName: nameController.text.trim(),
                      names: names,
                      parentId: parentId,
                    );

                    if (!context.mounted) return;
                    Navigator.of(dialogCtx).pop();

                    if (res.isSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.createPlaceSuccess)),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.failure?.message ?? 'Failed to create place'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  },
                  child: Text(l10n.submitButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatLevelLabel(String level, AppLocalizations l10n) {
    return switch (level) {
      'COUNTRY' => l10n.locationCountry,
      'STATE' => l10n.locationState,
      'DISTRICT' => l10n.locationDistrict,
      'CITY_TOWN' => l10n.locationCityTown,
      'VILLAGE' => l10n.locationVillage,
      _ => level,
    };
  }
}
