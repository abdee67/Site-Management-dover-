import '/utils/parsing_utils.dart';
class PlatformFile {
   int? id;
   String? fileName;
   String? fileType;
   String? fileData;
   int? siteId;
   DateTime? dateEntry;
   DateTime? dateUpdated;
   int? syncStatus = 0;

  PlatformFile({
    this.id,
    this.fileName,
    this.fileType,
    this.fileData,
    this.siteId,
    this.dateEntry,
    this.dateUpdated,
    this.syncStatus,
  });

  factory PlatformFile.fromMap(Map<String, dynamic> map) {
    return PlatformFile(
      id: parseInt(map['id']),
      fileName: map['file_name']?.toString(),
      fileType: map['file_type']?.toString(),
      fileData: map['file_data']?.toString(),
      syncStatus: parseInt(map['sync_status']),
      siteId: parseInt(map['site_id']),
      dateEntry: parseDate(map['date_entry']),
      dateUpdated: parseDate(map['date_updated']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'site_id': siteId,
      'file_name': fileName,
      'file_type': fileType,
      'file_data': fileData,
      'date_entry': dateEntry?.toIso8601String(),
      'date_updated': dateUpdated?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory PlatformFile.fromJson(Map<String, dynamic> json) => PlatformFile.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
