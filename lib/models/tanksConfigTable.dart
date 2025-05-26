import '/utils/parsing_utils.dart';
class TankConfig {
   int? id;
   int? siteId;
   int? tankNumber;
   String? gradesInfo;
   double? capacity;
   bool? safeWorkingCapacity;
   bool? doubleWalled;
   bool? siphonedInfo;
   String? siphonedFromTankIds;
   bool? tankChartAvailable;
   bool? dipStickAvailable;
   double? fuelAgeDays;
   String? pressureOrSuction;
   double? diameterA;
   double? manholeDepthB;
   double? probeLength;
   bool? manholeCoverMetal;
   bool? manholeWallMetal;
   bool? remoteAntennaRequired;
   double? tankEntryDiameter;
   double? probeCableLengthToKiosk;
   DateTime? dateEnters;
   DateTime? dateUpdated;
   String? safeWorkingCapacityMeasurement;
   String? probeLengthMeasurement;
   String? diameterAMeasurement;
   String? manholeDepthBMeasurement;
   String? probeCableLengthToKioskMeasurement;

  TankConfig({
    this.id,
    this.siteId,
    this.tankNumber,
    this.gradesInfo,
    this.capacity,
    this.safeWorkingCapacity,
    this.doubleWalled,
    this.siphonedInfo,
    this.siphonedFromTankIds,
    this.tankChartAvailable,
    this.dipStickAvailable,
    this.fuelAgeDays,
    this.pressureOrSuction,
    this.diameterA,
    this.manholeDepthB,
    this.probeLength,
    this.manholeCoverMetal,
    this.manholeWallMetal,
    this.remoteAntennaRequired,
    this.tankEntryDiameter,
    this.probeCableLengthToKiosk,
    this.dateEnters,
    this.dateUpdated,
    this.safeWorkingCapacityMeasurement,
    this.probeLengthMeasurement,
    this.diameterAMeasurement,
    this.manholeDepthBMeasurement,
    this.probeCableLengthToKioskMeasurement,
  });

  factory TankConfig.fromMap(Map<String, dynamic> map) {
    return TankConfig(
      id: parseInt(map['id']),
      siteId: parseInt(map['site_id']),
      tankNumber: parseInt(map['tank_number']),
      gradesInfo: map['grades_info']?.toString(),
      capacity: parseDouble(map['capacity']),
      safeWorkingCapacity: parseBool(map['safe_working_capacity']),
      doubleWalled: parseBool(map['double_walled']),
      siphonedInfo: parseBool(map['siphoned_info']),
      siphonedFromTankIds: map['siphoned_from_tank_ids']?.toString(),
      tankChartAvailable: parseBool(map['tank_chart_available']),
      dipStickAvailable: parseBool(map['dip_stick_available']),
      fuelAgeDays: parseDouble(map['fuel_age_days']),
      pressureOrSuction: map['pressure_or_suction']?.toString(),
      diameterA: parseDouble(map['diameter_a']),
      manholeDepthB: parseDouble(map['manhole_depth_b']),
      probeLength: parseDouble(map['probe_length']),
      manholeCoverMetal: parseBool(map['manhole_cover_metal']),
      manholeWallMetal: parseBool(map['manhole_wall_metal']),
      remoteAntennaRequired: parseBool(map['remote_antenna_required']),
      tankEntryDiameter: parseDouble(map['tank_entry_diameter']),
      probeCableLengthToKiosk: parseDouble(map['probe_cable_length_to_kiosk']),
      dateEnters: parseDate(map['date_enters']),
      dateUpdated: parseDate(map['date_updated']),
      safeWorkingCapacityMeasurement: map['safe_working_capacity_measumentt']?.toString(),
      probeLengthMeasurement: map['probe_length_measurement']?.toString(),
      diameterAMeasurement: map['diameter_a_measurement']?.toString(),
      manholeDepthBMeasurement: map['manhole_depth_b_measurement']?.toString(),
      probeCableLengthToKioskMeasurement: map['probe_cable_length_to_kiosk_measurement']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'site_id': siteId,
      'tank_number': tankNumber,
      'grades_info': gradesInfo,
      'capacity': capacity,
      'safe_working_capacity': boolToChar(safeWorkingCapacity),
      'double_walled': boolToChar(doubleWalled),
      'siphoned_info': boolToChar(siphonedInfo),
      'siphoned_from_tank_ids': siphonedFromTankIds,
      'tank_chart_available': boolToChar(tankChartAvailable),
      'dip_stick_available': boolToChar(dipStickAvailable),
      'fuel_age_days': fuelAgeDays,
      'pressure_or_suction': pressureOrSuction,
      'diameter_a': diameterA,
      'manhole_depth_b': manholeDepthB,
      'probe_length': probeLength,
      'manhole_cover_metal': boolToChar(manholeCoverMetal),
      'manhole_wall_metal': boolToChar(manholeWallMetal),
      'remote_antenna_required': boolToChar(remoteAntennaRequired),
      'tank_entry_diameter': tankEntryDiameter,
      'probe_cable_length_to_kiosk': probeCableLengthToKiosk,
      'date_enters': dateEnters?.toIso8601String(),
      'date_updated': dateUpdated?.toIso8601String(),
      'safe_working_capacity_measumentt': safeWorkingCapacityMeasurement,
      'probe_length_measurement': probeLengthMeasurement,
      'diameter_a_measurement': diameterAMeasurement,
      'manhole_depth_b_measurement': manholeDepthBMeasurement,
      'probe_cable_length_to_kiosk_measurement': probeCableLengthToKioskMeasurement,
    };
  }

  factory TankConfig.fromJson(Map<String, dynamic> json) => TankConfig.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
