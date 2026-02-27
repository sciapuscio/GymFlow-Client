/// GymFlow — Portal Block model
///
/// Represents one editorial block (image or rich text) served by
/// the gym-portal API and displayed on the Home/Portada screen.
class PortalBlock {
  final int id;
  final String type; // 'image' | 'richtext'
  final String content; // image URL or HTML string
  final String? caption; // optional subtitle below an image
  final int sortOrder;

  const PortalBlock({
    required this.id,
    required this.type,
    required this.content,
    this.caption,
    required this.sortOrder,
  });

  factory PortalBlock.fromJson(Map<String, dynamic> json) {
    return PortalBlock(
      id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
      type: json['type'] as String? ?? 'richtext',
      content: json['content'] as String? ?? '',
      caption: json['caption'] as String?,
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse('${json['sort_order']}') ?? 0,
    );
  }

  bool get isImage => type == 'image';
  bool get isRichText => type == 'richtext';
}
