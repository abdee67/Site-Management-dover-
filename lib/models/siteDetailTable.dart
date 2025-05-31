import '/utils/parsing_utils.dart';
class SiteDetail {
   int? id;
   String? siteName;
   String? siteId;
   String? addressInfo;
   String? countryInfo;
   String? cityInfo;
   String? townInfo; // Likely a typo for "townInfo"
   String? geolocationInfo;
   String? siteCellPhone;
   String? siteEmailAddress;
   String? brandOfFuelsSold;
   String? fuelSupplyTerminalName;
   String? mannedUnmanned;
   DateTime? dateEntry;
   DateTime? dateUpdated;
   int? companyId;
   String? companyName;
   int? syncStatus = 0; // 0 = not synced, 1 = synced
   DateTime? lastUpdated;

  SiteDetail({
    this.id,
    this.siteName,
    this.siteId,
    this.addressInfo,
    this.countryInfo,
    this.cityInfo,
    this.townInfo,
    this.geolocationInfo,
    this.siteCellPhone,
    this.siteEmailAddress,
    this.brandOfFuelsSold,
    this.fuelSupplyTerminalName,
    this.mannedUnmanned,
    this.dateEntry,
    this.dateUpdated,
    this.companyName,
    this.companyId,
    this.syncStatus,
  });

  factory SiteDetail.fromMap(Map<String, dynamic> map) {
    return SiteDetail(
      id: parseInt(map['id']),
      siteName: map['site_name']?.toString(),
      siteId: map['site_id']?.toString(),
      addressInfo: map['address_info']?.toString(),
      countryInfo: map['country_info']?.toString(),
      cityInfo: map['city_info']?.toString(),
      townInfo: map['town_info']?.toString(),
      geolocationInfo: map['geoloaction_info']?.toString(),
      siteCellPhone: map['site_cell_phone']?.toString(),
      siteEmailAddress: map['site_email_address']?.toString(),
      brandOfFuelsSold: map['brand_of_fuels_sold']?.toString(),
      fuelSupplyTerminalName: map['fuel_supply_terminal_name']?.toString(),
      mannedUnmanned: map['manned_unmanned']?.toString(),
      dateEntry: parseDate(map['date_entry']),
      dateUpdated: parseDate(map['date_updated']),
      companyId: parseInt(map['company_name']),
      companyName: (map['company_name_text']?.toString()),
      syncStatus: parseInt(map['sync_status']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'site_name': siteName,
      'site_id': siteId,
      'address_info': addressInfo,
      'country_info': countryInfo,
      'city_info': cityInfo,
      'town_info': townInfo,
      'geoloaction_info': geolocationInfo,
      'site_cell_phone': siteCellPhone,
      'site_email_address': siteEmailAddress,
      'brand_of_fuels_sold': brandOfFuelsSold,
      'fuel_supply_terminal_name': fuelSupplyTerminalName,
      'manned_unmanned': mannedUnmanned,
      'date_entry': dateEntry?.toIso8601String(),
      'date_updated': dateUpdated?.toIso8601String(),
      'company_name': companyId,
      'sync_status': syncStatus,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  factory SiteDetail.fromJson(Map<String, dynamic> json) => SiteDetail.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
