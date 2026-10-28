class PlaceName {
  final String language;
  final String name;
  const PlaceName({required this.language, required this.name});

  factory PlaceName.fromJson(Map<String, dynamic> json) =>
      PlaceName(language: json['language'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'language': language, 'name': name};
}

class PlacePathItem {
  final String id;
  final String level;
  final String canonicalName;

  const PlacePathItem({
    required this.id,
    required this.level,
    required this.canonicalName,
  });

  factory PlacePathItem.fromJson(Map<String, dynamic> json) => PlacePathItem(
        id: json['id'] as String,
        level: json['level'] as String,
        canonicalName: json['canonicalName'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'canonicalName': canonicalName,
      };
}

class Place {
  final String id;
  final String level;
  final List<PlaceName> names;
  final String canonicalName;
  final String? parentId;
  final List<PlacePathItem>? parentPath;

  const Place({
    required this.id,
    required this.level,
    required this.names,
    required this.canonicalName,
    this.parentId,
    this.parentPath,
  });

  String nameForLanguage(String lang) {
    return names.where((n) => n.language == lang).map((n) => n.name).firstOrNull ??
        canonicalName;
  }

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        level: json['level'] as String? ?? '',
        names: (json['names'] as List<dynamic>?)
                ?.map((n) => PlaceName.fromJson(n as Map<String, dynamic>))
                .toList() ??
            [],
        canonicalName: json['canonicalName'] as String? ?? '',
        parentId: json['parentId'] as String?,
        parentPath: (json['parentPath'] as List<dynamic>?)
            ?.map((p) => PlacePathItem.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'names': names.map((n) => n.toJson()).toList(),
        'canonicalName': canonicalName,
        if (parentId != null) 'parentId': parentId,
        if (parentPath != null) 'parentPath': parentPath!.map((p) => p.toJson()).toList(),
      };
}
