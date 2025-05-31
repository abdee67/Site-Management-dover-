class SiteDetail {
  String? companyName;
  String? siteName;
  String? siteId;
  String? addressInfo;
  String? countryInfo;
  String? state;
  String? city;
  String? townInfo;
  String? geoLocationInfo;
  String? mannedUnmanned;
  String? fuelSupplyTerminalName;
  String? brandOfFuelsSold;
  int? syncStatus = 0;
}

class EquipmentInfo {
  String? fccModel;
  String? fccLocation;
  String? atgModel;
  String? atgLocation;
  bool? printerRequired;
}

class PowerConfig {
  String? groundingValue;
  bool? mainsNearFccAtg;
  bool? mainsNearFusionGateway;
  bool? upsForFccAtg;
  bool? upsForDispenser;
  bool? mainsAtDispenserForGateway;
  bool? dataPowerSeparation;
  bool? dataConduitPumpToFcc;
  bool? conduitForDispenserGateway;
}

class NetworkConfig {
  bool? hasBroadband;
  bool? freeRouterPorts;
  bool? managedByThirdParty;
  bool? portsAllocatedForFccAtg;
  bool? preventsTeamViewer;
}

class TankConfig {
  int? tankNumber;
  String? gradeInfo;
  double? capacity;
  bool? doubleWalled;
  String? pressureOrSuction;
  bool? siphoned;
  String? siphonedFromTankIds;
  bool? tankChartAvailable;
  bool? dipStickAvailable;
  double? fuelAgeDays;
  double? diameterA;
  double? manholeDepthB;
  double? probeLength;
  bool? manholeCoverMetal;
  bool? manholeWallMetal;
  bool? remoteAntennaRequired;
  double? tankEntryDiameter;
  double? probeCableLengthToKiosk;
}

class PumpConfig {
  int? pumpNumber;
  String? brandInfo;
  String? modelInfo;
  String? serialNumber;
  String? cpuFirmwaresInfo;
  String? protocolInfo;
  double? cableLengthToFcc;
  int? nozzlesInfo;
  String? pumpAddressInfo;
}

class NozzleConfig {
  int? pumpNumber;
  int? nozzleNumber;
  String? gradeInfo;
  int? tankNumber;
}

class Contact {
  String? contactName;
  String? role;
  String? phoneNumber;
  String? emailAddress;
}

class Note {
  String? commentInfo;
}