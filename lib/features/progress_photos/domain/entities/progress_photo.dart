class ProgressPhotoSession {
  const ProgressPhotoSession({
    required this.id,
    required this.sessionDate,
    required this.isComplete,
    required this.photos,
  });

  final String id;
  final String sessionDate;
  final bool isComplete;
  final List<ProgressPhoto> photos;

  factory ProgressPhotoSession.fromJson(Map<String, dynamic> json) =>
      ProgressPhotoSession(
        id: json['id'] as String,
        sessionDate: json['session_date'] as String,
        isComplete: json['is_complete'] == true,
        photos: ((json['photos'] as List?) ?? const [])
            .whereType<Map>()
            .map((photo) => ProgressPhoto.fromJson(Map<String, dynamic>.from(photo)))
            .toList(growable: false),
      );
}

class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.view,
    required this.imageUrl,
    this.replacesPhotoId,
  });

  final String id;
  final String view;
  final String imageUrl;
  final String? replacesPhotoId;

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
    id: json['id'] as String,
    view: json['view'] as String,
    imageUrl: json['image_url'] as String,
    replacesPhotoId: json['replaces_photo_id'] as String?,
  );
}
