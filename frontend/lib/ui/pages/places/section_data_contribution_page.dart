import 'package:flutter/material.dart';
import '../../../services/community_service.dart';

enum SectionContributionType {
  demographics,
  religionCaste,
  occupationEconomy,
  voterElectoral,
  publicFacilities,
}

class SectionDataContributionPage extends StatefulWidget {
  final String placeId;
  final String placeName;
  final SectionContributionType sectionType;
  final CommunityService communityService;
  final VoidCallback? onBackToHome;

  const SectionDataContributionPage({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.sectionType,
    required this.communityService,
    this.onBackToHome,
  });

  @override
  State<SectionDataContributionPage> createState() => _SectionDataContributionPageState();
}

class _SectionDataContributionPageState extends State<SectionDataContributionPage> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedPresetKey;
  final TextEditingController _customKeyController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();

  String _uncertainty = 'Official Government Record';
  bool _isUnknownChecked = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedPresetKey = _presetKeys.first;
  }

  @override
  void dispose() {
    _customKeyController.dispose();
    _valueController.dispose();
    _sourceController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  String get _sectionTitle => switch (widget.sectionType) {
        SectionContributionType.demographics => 'Demographic & Population Statistics',
        SectionContributionType.religionCaste => 'Religion & Caste Demographics',
        SectionContributionType.occupationEconomy => 'Occupations, Agriculture & Employment',
        SectionContributionType.voterElectoral => 'Voter & Electoral Information',
        SectionContributionType.publicFacilities => 'Public Facilities & Development Records',
      };

  String get _sectionCategory => switch (widget.sectionType) {
        SectionContributionType.demographics => 'population',
        SectionContributionType.religionCaste => 'population',
        SectionContributionType.occupationEconomy => 'development',
        SectionContributionType.voterElectoral => 'leadership',
        SectionContributionType.publicFacilities => 'facility',
      };

  List<String> get _presetKeys => switch (widget.sectionType) {
        SectionContributionType.demographics => const [
            'Total Population',
            'Male Population',
            'Female Population',
            'Household Count',
            'Literacy Rate',
            'Children (0-6 years)',
            'Sex Ratio',
            'Other Demographic Metric',
          ],
        SectionContributionType.religionCaste => const [
            'Religion Distribution (Aggregate)',
            'Major Community Groups (Aggregate)',
            'Scheduled Caste (SC) Population (Aggregate)',
            'Scheduled Tribe (ST) Population (Aggregate)',
            'Other Backward Classes (OBC) (Aggregate)',
            'General Category Population (Aggregate)',
            'Other Community Statistic (Aggregate)',
          ],
        SectionContributionType.occupationEconomy => const [
            'Primary Occupation & Livelihood',
            'Agricultural Crops & Produce',
            'Irrigation & Water Sources for Agriculture',
            'Local Business & Trade Profile',
            'Handicrafts & Village Industry',
            'Employment Profile & Labor',
            'Other Economic Activity',
          ],
        SectionContributionType.voterElectoral => const [
            'Total Registered Voters',
            'Male Registered Voters',
            'Female Registered Voters',
            'Legislative Assembly (MLA) Constituency',
            'Parliamentary (MP) Constituency',
            'Number of Polling Stations / Booths',
            'Gram Panchayat Ward Count',
            'Other Electoral Record',
          ],
        SectionContributionType.publicFacilities => const [
            'Primary & Secondary Schools',
            'Healthcare Facilities (PHC / Sub-Centre)',
            'Drinking Water Supply & Sources',
            'Electricity & Power Grid Status',
            'Road & Transport Connectivity',
            'Sanitation & Drainage System',
            'Major Public Development Project',
            'Other Public Infrastructure',
          ],
      };

  String get _valueFieldHint => switch (widget.sectionType) {
        SectionContributionType.demographics => 'e.g. 4,850 or 74.2%',
        SectionContributionType.religionCaste => 'e.g. Hindu 78%, Muslim 18%, Others 4% or Aggregate SC 19%',
        SectionContributionType.occupationEconomy => 'e.g. Farming (Wheat, Mustard, Bajra), Dairy Cooperative',
        SectionContributionType.voterElectoral => 'e.g. 3,240 registered voters or Mandore Assembly #128',
        SectionContributionType.publicFacilities => 'e.g. 1 PHC (4 beds), 2 Primary Schools, Piped tap water',
      };

  String get _sourceFieldHint => switch (widget.sectionType) {
        SectionContributionType.demographics => 'e.g. Census of India 2011, District Census Handbook',
        SectionContributionType.religionCaste => 'e.g. Official Government Gazette, Census Aggregate Publication',
        SectionContributionType.occupationEconomy => 'e.g. District Economic Survey, Agriculture Department Records',
        SectionContributionType.voterElectoral => 'e.g. Election Commission of India, Electoral Roll Summary',
        SectionContributionType.publicFacilities => 'e.g. Public Works Department (PWD), Panchayat Development Plan',
      };

  String get _citationRequirementText => switch (widget.sectionType) {
        SectionContributionType.demographics =>
          'Official demographic profile and population totals must cite official census publications (e.g. Census of India) or verified administrative records.',
        SectionContributionType.religionCaste =>
          'Privacy Safeguard: Only credible aggregate community/religion proportions from official published government surveys are permitted. Identifiable individual personal information, names, or private beliefs are strictly prohibited.',
        SectionContributionType.occupationEconomy =>
          'Economic and agricultural profiles must reflect community-wide patterns cited from district surveys or agricultural cooperatives.',
        SectionContributionType.voterElectoral =>
          'Electoral Transparency: Only official aggregate voter statistics, constituency boundaries, and polling station counts are recorded. Individual ballots and private political affiliations are strictly prohibited.',
        SectionContributionType.publicFacilities =>
          'Public facilities require department notifications, government scheme sanction orders, or verified physical survey records.',
      };

  Future<void> _handleSubmit() async {
    if (_isUnknownChecked) {
      _valueController.text = 'Not recorded in official statistics';
    }

    if (!_formKey.currentState!.validate()) return;

    final effectiveKey = _selectedPresetKey.startsWith('Other')
        ? _customKeyController.text.trim()
        : _selectedPresetKey;

    if (effectiveKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify the indicator name')),
      );
      return;
    }

    // Extra privacy safeguard check for religion & caste
    if (widget.sectionType == SectionContributionType.religionCaste) {
      final valLower = _valueController.text.toLowerCase();
      if (valLower.contains('mr.') || valLower.contains('mrs.') || valLower.contains('shri') || valLower.contains('named')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy Safeguard: Individual personal names cannot be included in aggregate statistics.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final result = await widget.communityService.addPlaceAttribute(
      placeId: widget.placeId,
      category: _sectionCategory,
      key: effectiveKey,
      value: _valueController.text.trim(),
      sourceDescription: _sourceController.text.trim(),
      reportedPeriod: _periodController.text.trim().isNotEmpty ? _periodController.text.trim() : null,
      uncertainty: _uncertainty,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_sectionTitle contributed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      if (widget.onBackToHome != null) {
        widget.onBackToHome!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.communityService.errorMessage ?? 'Failed to submit data. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('return_to_home_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Location',
          onPressed: () {
            if (widget.onBackToHome != null) {
              widget.onBackToHome!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(_sectionTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Citation & Privacy Notice Card
                Card(
                  elevation: 0.5,
                  color: widget.sectionType == SectionContributionType.religionCaste
                      ? Colors.amber.shade50
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: widget.sectionType == SectionContributionType.religionCaste
                          ? Colors.amber.shade400
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          widget.sectionType == SectionContributionType.religionCaste
                              ? Icons.security_outlined
                              : Icons.menu_book_outlined,
                          size: 18,
                          color: widget.sectionType == SectionContributionType.religionCaste
                              ? Colors.amber.shade900
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _citationRequirementText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: widget.sectionType == SectionContributionType.religionCaste
                                  ? Colors.amber.shade900
                                  : theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Preset Indicator Selector
                Text(
                  'Select Indicator / Statistic',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('dropdown_attribute_key'),
                  initialValue: _selectedPresetKey,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _presetKeys
                      .map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPresetKey = val;
                      });
                    }
                  },
                ),
                if (_selectedPresetKey.startsWith('Other')) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('field_custom_attribute_key'),
                    controller: _customKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Indicator Name *',
                      hintText: 'Enter specific indicator title',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (val) {
                      if (_selectedPresetKey.startsWith('Other') && (val == null || val.trim().isEmpty)) {
                        return 'Please provide indicator title';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Value Field
                Text(
                  'Value / Data Record',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('field_attribute_value'),
                  controller: _valueController,
                  enabled: !_isUnknownChecked,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _isUnknownChecked ? 'Marked as Unavailable' : 'Data Value / Description *',
                    hintText: _isUnknownChecked ? 'Unavailable in official records' : _valueFieldHint,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) {
                    if (!_isUnknownChecked && (val == null || val.trim().isEmpty)) {
                      return 'Please enter the data value';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Honest Unknown Option
                CheckboxListTile(
                  key: const Key('checkbox_unknown_data'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Statistic is currently unknown or not recorded in official documents',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isUnknownChecked,
                  onChanged: (checked) {
                    setState(() {
                      _isUnknownChecked = checked ?? false;
                      if (_isUnknownChecked) {
                        _valueController.text = 'Not recorded in official statistics';
                      } else {
                        _valueController.clear();
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),

                // Source Description Field (Required)
                Text(
                  'Source & Citation *',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('field_attribute_source'),
                  controller: _sourceController,
                  decoration: InputDecoration(
                    labelText: 'Official Source / Publication *',
                    hintText: _sourceFieldHint,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Official citation or source is required (at least 3 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Row for Reference Period & Verification Record Type
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Year / Period', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            key: const Key('field_attribute_period'),
                            controller: _periodController,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 2011 or 2023-24',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Record Confidence', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const Key('dropdown_attribute_uncertainty'),
                            initialValue: _uncertainty,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Official Government Record', child: Text('Official Record', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Census of India', child: Text('Census Record', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Department Survey', child: Text('Dept. Survey', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Estimated / Community', child: Text('Estimate', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _uncertainty = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Submit Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    key: const Key('submit_section_contribution_button'),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_isSubmitting ? 'Submitting Data...' : 'Submit Contribution'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
