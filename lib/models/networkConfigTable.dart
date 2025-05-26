class NetworkConfig {
   int? id;
   int? siteId;
   bool? hasBroadband;
   bool? freePort;
   bool? managedByThird;
   bool? portAllocatedFccAtg;
   bool? teamviewerBlocked;
   DateTime? dateEntry;
   DateTime? dateUpdated;

  NetworkConfig({
    this.id,
    this.siteId,
    this.hasBroadband,
    this.freePort,
    this.managedByThird,
    this.portAllocatedFccAtg,
    this.teamviewerBlocked,
    this.dateEntry,
    this.dateUpdated,
  });

  factory NetworkConfig.fromMap(Map<String, dynamic> map) {
    return NetworkConfig(
      id: _parseInt(map['id']),
      siteId: _parseInt(map['site_id']),
      hasBroadband: _parseBool(map['has_broadband']),
      freePort: _parseBool(map['free_port']),
      managedByThird: _parseBool(map['managed_by_third']),
      portAllocatedFccAtg: _parseBool(map['port_alocated_fcc_atg']),
      teamviewerBlocked: _parseBool(map['teamviewer_blocked']),
      dateEntry: _parseDate(map['date_entry']),
      dateUpdated: _parseDate(map['date_updated']),
    );
  }

  Map<String, dynamic> toMap() {
   final  map = <String, dynamic>{
      'site_id': siteId,
      'has_broadband': _boolToChar(hasBroadband),
      'free_port': _boolToChar(freePort),
      'managed_by_third': _boolToChar(managedByThird),
      'port_alocated_fcc_atg': _boolToChar(portAllocatedFccAtg),
      'teamviewer_blocked': _boolToChar(teamviewerBlocked),
      'date_entry': dateEntry?.toIso8601String(),
      'date_updated': dateUpdated?.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory NetworkConfig.fromJson(Map<String, dynamic> json) => NetworkConfig.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  // Helpers
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    final str = value.toString().toUpperCase();
    return str == 'Y' || str == '1';
  }

  static String? _boolToChar(bool? value) {
    if (value == null) return null;
    return value ? 'Y' : 'N';
  }
}
