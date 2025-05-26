import '/utils/parsing_utils.dart';
class ReviewComment {
   int? id;
   String? commentInfo;
   int? siteId;
   DateTime? dateEntry;
   DateTime? dateUpdated;

  ReviewComment({
    this.id,
    this.commentInfo,
    this.siteId,
    this.dateEntry,
    this.dateUpdated,
  });

  factory ReviewComment.fromMap(Map<String, dynamic> map) {
    return ReviewComment(
      id: parseInt(map['id']),
      commentInfo: map['comment_info']?.toString(),
      siteId: parseInt(map['site_id']),
      dateEntry: parseDate(map['date_entry']),
      dateUpdated: parseDate(map['date_updated']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'comment_info': commentInfo,
      'site_id': siteId,
      'date_entry': dateEntry?.toIso8601String(),
      'date_updated': dateUpdated?.toIso8601String(),
    };
  }

  factory ReviewComment.fromJson(Map<String, dynamic> json) => ReviewComment.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
