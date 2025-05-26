import '/utils/parsing_utils.dart';
class PowerConfiguration {
   int? id;
   int? siteId;
   String? groundingValue;
   DateTime? dateEntry;
   DateTime? dateUpdatedDate;
   bool? mainPowerFccAtg;
   bool? mainPowerFusionWirelessGateway;
   bool? upsForFccAtg;
   bool? upsDispenser;
   bool? mainPowerDispenserWirelessGateway;
   bool? separationOfDataCable;
   bool? availabilityDataPumpToFcc;
   bool? conduitCableInstall;

  PowerConfiguration({
    this.id,
    this.siteId,
    this.groundingValue,
    this.dateEntry,
    this.dateUpdatedDate,
    this.mainPowerFccAtg,
    this.mainPowerFusionWirelessGateway,
    this.upsForFccAtg,
    this.upsDispenser,
    this.mainPowerDispenserWirelessGateway,
    this.separationOfDataCable,
    this.availabilityDataPumpToFcc,
    this.conduitCableInstall,
  });

  factory PowerConfiguration.fromMap(Map<String, dynamic> map) {
    return PowerConfiguration(
      id: parseInt(map['id']),
      siteId: parseInt(map['site_id']),
      groundingValue: map['grounding_value']?.toString(),
      dateEntry: parseDate(map['date_entry']),
      dateUpdatedDate: parseDate(map['date_updated_date']),
      mainPowerFccAtg: parseBool(map['main_power_FCC_ATG']),
      mainPowerFusionWirelessGateway: parseBool(map['main_power_fusion_wireless_gateway']),
      upsForFccAtg: parseBool(map['ups_for_fcc_atg']),
      upsDispenser: parseBool(map['ups_dispenser']),
      mainPowerDispenserWirelessGateway: parseBool(map['main_power_dispenser_wireless_gateway']),
      separationOfDataCable: parseBool(map['separation_of_data_cable']),
      availabilityDataPumpToFcc: parseBool(map['availablity_data_pump_to_fcc']),
      conduitCableInstall: parseBool(map['conduit_cable_install']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'site_id': siteId,
      'grounding_value': groundingValue,
      'date_entry': dateEntry?.toIso8601String(),
      'date_updated_date': dateUpdatedDate?.toIso8601String(),
      'main_power_FCC_ATG': boolToChar(mainPowerFccAtg),
      'main_power_fusion_wireless_gateway': boolToChar(mainPowerFusionWirelessGateway),
      'ups_for_fcc_atg': boolToChar(upsForFccAtg),
      'ups_dispenser': boolToChar(upsDispenser),
      'main_power_dispenser_wireless_gateway': boolToChar(mainPowerDispenserWirelessGateway),
      'separation_of_data_cable': boolToChar(separationOfDataCable),
      'availablity_data_pump_to_fcc': boolToChar(availabilityDataPumpToFcc),
      'conduit_cable_install': boolToChar(conduitCableInstall),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory PowerConfiguration.fromJson(Map<String, dynamic> json) => PowerConfiguration.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
