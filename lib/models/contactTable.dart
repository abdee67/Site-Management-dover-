class Contact {
   int? id;
   int? siteId;
   String? contactName;
   String? role;
   String? phoneNumber;
   DateTime? dateEntry;
   DateTime? dateUpdated;
   String? email; // Foreign key
   int? syncStatus = 0;

  Contact({
    this.id,
    this.siteId,
    this.contactName,
    this.role,
    this.phoneNumber,
    this.dateEntry,
    this.dateUpdated,
    this.email,
  });



  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'site_id': siteId,
      'contact_name': contactName,
      'role_table': role,
      'phone_number': phoneNumber,
      'date_entry': dateEntry?.toIso8601String(),
      'date_updated': dateUpdated?.toIso8601String(),
      'email_address': email,
      'sync_status': syncStatus,
    };
  }
    factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      siteId: map['site_id'],
      contactName: map['contact_name'],
      role: map['role_table'],
      phoneNumber: map['phone_number'],
      dateEntry: map['date_entry'] != null ? DateTime.parse(map['date_entry']) : null,
      dateUpdated: map['date_updated'] != null ? DateTime.parse(map['date_updated']) : null,
      email: map['email_address'],
    );
  }
}
