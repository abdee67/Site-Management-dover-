class Address {
  final int? id;
  final String? companyName;
  final String? country;
  final DateTime? dateOfEntry;
  final DateTime? updatedDate;

  Address({
    this.id,
    this.companyName,
    this.country,
    this.dateOfEntry,
    this.updatedDate,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: _parseInt(map['id']),
      companyName: map['company_name']?.toString(),
      country: map['country']?.toString(),
      dateOfEntry: _parseDate(map['date_of_entry']),
      updatedDate: _parseDate(map['updated_date']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'company_name': companyName,
      'country': country,
      'date_of_entry': dateOfEntry?.toIso8601String(),
      'updated_date': updatedDate?.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // For JSON serialization
  factory Address.fromJson(Map<String, dynamic> json) => Address.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

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
}
