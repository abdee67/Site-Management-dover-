class PendingFileUpload {
  final int id;
  final int siteId;
  final String filePath;
  final String fileName;
  final String fileType;
  final DateTime createdAt;
  final int syncStatus;
  
  PendingFileUpload({
    required this.id,
    required this.siteId,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.createdAt,
    this.syncStatus = 0, // Default sync status is 0 (not synced)
  });
  factory PendingFileUpload.fromMap(Map<String, dynamic> map) {
    return PendingFileUpload(
      id: map['id'] as int,
      siteId: map['site_id'] as int,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      fileType: map['file_type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: map['sync_status'] as int? ?? 0, // Default to 0 if null
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'site_id': siteId,
      'file_path': filePath,
      'file_name': fileName,
      'file_type': fileType,
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
  // Add constructor and toMap/fromMap methods
}