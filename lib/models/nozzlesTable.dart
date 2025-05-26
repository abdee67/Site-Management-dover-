import '/utils/parsing_utils.dart';
class Nozzle {
   int? id;
   int? pumpId;
   int? nozzleNumbers;
   String? gradeInfo;
   int? tankId;
  String? pumpsSelection; // For UI display
  String? tankSelection;  // For UI display
   DateTime? dateEntry;
   DateTime? dateUpdate;

  Nozzle({
    this.id,
    this.pumpId,
    this.nozzleNumbers,
    this.gradeInfo,
    this.tankId,
    this.pumpsSelection,
    this.tankSelection,
    this.dateEntry,
    this.dateUpdate,
  });

  factory Nozzle.fromMap(Map<String, dynamic> map) {
    return Nozzle(
      id: parseInt(map['id']),
      pumpId: parseInt(map['pump_id']),
      nozzleNumbers: parseInt(map['nozzel_numbers']),
      gradeInfo: map['grade_info']?.toString(),
      tankId: parseInt(map['tank_id']),
      pumpsSelection: map['pumpsSelection'], // This won't come from DB
      tankSelection: map['tankSelection'], // This won't come from DB
  
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'pump_id': pumpId,
      'nozzel_numbers': nozzleNumbers,
      'grade_info': gradeInfo,
      'tank_id': tankId,
      'date_entry': dateEntry?.toIso8601String(),
      'date_update': dateUpdate?.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Nozzle.fromJson(Map<String, dynamic> json) => Nozzle.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

}
