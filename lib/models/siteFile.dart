import '/utils/parsing_utils.dart';
class SiteFile {
   int? id;
   int? siteId;
   String? filePath;
   String? fileName;
   String? fileType;
    int? syncStatus = 0;
   DateTime? createdAt;
   DateTime? updatedAt;

  SiteFile({
    this.id,
     this.siteId,
     this.filePath,
     this.fileName,
     this.fileType,
     this.createdAt,
      this.syncStatus,
      this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'site_id': siteId,
      'file_path': filePath,
      'file_name': fileName,
      'file_type': fileType,
      'sync_status': syncStatus,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory SiteFile.fromMap(Map<String, dynamic> map) {
    return SiteFile(
      id: parseInt(map['id']),
      siteId: parseInt(map['site_id']),
      filePath: map['file_path']?.toString(),
      fileName: map['file_name']?.toString(),
      fileType: map['file_type']?.toString(),
      syncStatus: parseInt(map['sync_status']),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }
}
