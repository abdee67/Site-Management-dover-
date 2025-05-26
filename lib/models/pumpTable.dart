import '/utils/parsing_utils.dart';
class Pump {
   int? id;
   int? siteId;
   int? pumpNumber;
   String? brandInfo;
   String? modelInfo;
   String? serialNumber;
   String? cpuFirmwaresInfo;
   String? protocolInfo;
   double? cableLengthToFcc;
   String? nozzlesInfo;
   String? pumpAddressInfo;
   String? cableLengthToFccMeasurement;
   DateTime? dateEntry;
   DateTime? dateUpdated;

  Pump({
    this.id,
    this.siteId,
    this.pumpNumber,
    this.brandInfo,
    this.modelInfo,
    this.serialNumber,
    this.cpuFirmwaresInfo,
    this.protocolInfo,
    this.cableLengthToFcc,
    this.nozzlesInfo,
    this.pumpAddressInfo,
    this.cableLengthToFccMeasurement,
    this.dateEntry,
    this.dateUpdated,
  });

  factory Pump.fromMap(Map<String, dynamic> map) {
    return Pump(
      id: parseInt(map['id']),
      siteId: parseInt(map['site_id']),
      pumpNumber: parseInt(map['pump_number']),
      brandInfo: map['brand_info']?.toString(),
      modelInfo: map['model_info']?.toString(),
      serialNumber: map['serial_number']?.toString(),
      cpuFirmwaresInfo: map['cpu_firmwares_info']?.toString(),
      protocolInfo: map['protocol_info']?.toString(),
      cableLengthToFcc: parseDouble(map['cable_length_to_fcc']),
      nozzlesInfo: map['nozzles_info']?.toString(),
      pumpAddressInfo: map['pump_address_info']?.toString(),
      cableLengthToFccMeasurement: map['cable_length_to_fcc_measurement']?.toString(),
      dateEntry: parseDate(map['date_entry']),
      dateUpdated: parseDate(map['date_updated']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'site_id': siteId,
      'pump_number': pumpNumber,
      'brand_info': brandInfo,
      'model_info': modelInfo,
      'serial_number': serialNumber,
      'cpu_firmwares_info': cpuFirmwaresInfo,
      'protocol_info': protocolInfo,
      'cable_length_to_fcc': cableLengthToFcc,
      'nozzles_info': nozzlesInfo,
      'pump_address_info': pumpAddressInfo,
      'cable_length_to_fcc_measurement': cableLengthToFccMeasurement,
      'date_entry': dateEntry?.toIso8601String(),
      'date_updated': dateUpdated?.toIso8601String(),
    };
  }

  factory Pump.fromJson(Map<String, dynamic> json) => Pump.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
