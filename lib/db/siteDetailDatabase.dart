// lib/db/customer_database.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/siteDetailTable.dart';
import '/models/contactTable.dart';
import '/models/siteEquipment.dart';
import '/models/powerConfigurationTable.dart';
import '/models/networkConfigTable.dart';
import '/models/nozzlesTable.dart';
import '/models/pumpTable.dart';
import '/models/tanksConfigTable.dart';
import '/models/reviewCommentTable.dart';
import '/models/sitefile.dart';
import 'dbHelper.dart';

class Sitedetaildatabase {
final DatabaseHelper dbHelper = DatabaseHelper.instance;
 static final Sitedetaildatabase _instance = Sitedetaildatabase._internal();
  Sitedetaildatabase._internal();
  static Sitedetaildatabase get instance => _instance;

// In your Sitedetaildatabase class

Future<int> addCompany(String name, String country) async {
  final db = await dbHelper.database;
  return await db.insert(
    'address_table',
    {
      'company_name': name,
      'country': country,
      'date_of_entry': DateTime.now().toIso8601String(),
      'updated_date': DateTime.now().toIso8601String(),
    },
  );
}

Future<int> updateCompany(int id, String newName) async {
  final db = await dbHelper.database;
  return await db.update(
    'address_table',
    {
      'company_name': newName,
      'updated_date': DateTime.now().toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<int> deleteCompany(int id) async {
  final db = await dbHelper.database;
  // First check if any sites reference this company
  final sites = await db.query(
    'site_detail_table',
    where: 'company_name = ?',
    whereArgs: [id],
    limit: 1,
  );
  
  if (sites.isNotEmpty) {
    throw Exception('Cannot delete company - it is referenced by sites');
  }
  
  return await db.delete(
    'address_table',
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<void> printFullSiteDetails(int siteId) async {
  final db = await dbHelper.database;
  
  debugPrint('\n🔍 FULL SITE DETAILS FOR ID: $siteId');
  
  // Match these to your actual column names
  final queries = {
    'Site Details': 'SELECT * FROM site_detail_table WHERE id = ?',
    'Contacts': 'SELECT * FROM contacts_table WHERE site_id = ?',
    'Equipment': 'SELECT * FROM site_equipment_table WHERE site_id = ?',
    'Power Config': 'SELECT * FROM power_configuration_table WHERE site_id = ?',
    'Network Config': 'SELECT * FROM network_config_table WHERE site_id = ?',
    'Tanks': 'SELECT * FROM tanks_config_table WHERE site_id = ?',
    'Pumps': 'SELECT * FROM pump_table WHERE site_id = ?',
    'Nozzles': 'SELECT * FROM nozzles_table WHERE site_id = ?',
    'Notes': 'SELECT * FROM review_comment_table WHERE site_id = ?'
  };

  for (final entry in queries.entries) {
    try {
      final results = await db.rawQuery(entry.value, [siteId]);
      
      debugPrint('├─ ${entry.key}:');
      if (results.isEmpty) {
        debugPrint('│   No records found');
      } else {
        for (final row in results) {
          debugPrint('│   ${row.toString()}');
        }
      }
    } catch (e) {
      debugPrint('│   Error querying ${entry.key}: $e');
    }
  }
  
  debugPrint('└──────────────────────────────────────────────');
}

Future<List<Map<String, dynamic>>> getAllNozzles() async {
  final db = await dbHelper.database;
  return await db.query('site_files');
}

Future<void > printAllNozzles() async {
  final nozzles = await getAllNozzles();
  
  debugPrint('\n🔧 ALL pendings IN DATABASE (${nozzles.length} total)');
  for (final nozzle in nozzles) {
    debugPrint('├─  id : ${nozzle['id']}');
    debugPrint('│   Other data: ${nozzle.toString()}');
  }
  debugPrint('└──────────────────────────────────');
}

// In your Sitedetaildatabase class
Future<List<Map<String, dynamic>>> getCompaniesForDropdown() async {
  final db = await dbHelper.database;
  return await db.query(
    'address_table',
    columns: ['id', 'company_name'],
    orderBy: 'company_name ASC',
  );
}

  

   Future<List<SiteDetail>> searchSiteDetails(String query) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'site_detail_table',
      where: 'site_name LIKE ?',
      whereArgs: ['%$query%'],
    );
    return List.generate(maps.length, (i) => SiteDetail.fromMap(maps[i]));
  }

// Get sites with company information (join query)
Future<List<Map<String, dynamic>>> getSitesWithCompany() async {
  final db = await dbHelper.database;
  return await db.rawQuery('''
    SELECT s.*, a.company_name as company_name_text 
    FROM site_detail_table s
    LEFT JOIN address_table a ON s.company_name = a.id
  ''');
}


// Site Detail CRUD Operations
Future<int> createSiteDetail(SiteDetail site) async {
 final db = await dbHelper.database;
  return await db.insert(
    'site_detail_table',
    site.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<List<SiteDetail>> getAllSites() async {
 final db = await dbHelper.database;
    final maps = await db.rawQuery('''
     SELECT s.*, a.company_name 
        FROM site_detail_table s
        LEFT JOIN address_table a ON s.company_name = a.id
        ORDER BY s.date_entry DESC
      ''');
  return maps.map((e) => SiteDetail.fromMap(e)).toList();
}

Future<int> updateSiteDetail(SiteDetail site) async {
  final db = await dbHelper.database;
  return await db.update(
    'site_detail_table',
    site.toMap(),
    where: 'site_id = ?',
    whereArgs: [site.siteId],
  );
}

Future<SiteDetail?> getSiteById(String siteId) async {
 final db = await dbHelper.database;
  final maps = await db.query(
    'site_detail_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return SiteDetail.fromMap(maps.first);
  }
  return null;
}

Future<int> deleteSite(String siteId) async {
 final db = await dbHelper.database;
  
  // First delete all related records due to foreign key constraints
  await db.delete('contacts_table', where: 'site_id = ?', whereArgs: [siteId]);
  await db.delete('site_equipment_table', where: 'site_id = ?', whereArgs: [siteId]);
  // Add similar deletes for other related tables
  
  // Then delete the site
  return await db.delete(
    'site_detail_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
}

Future<List<String>> getDistinctCompanyNames() async {
 final db = await dbHelper.database;
  final maps = await db.query(
    'site_detail_table',
    columns: ['company_name'],
    distinct: true,
  );
  return maps
      .map((e) => e['company_name'] as String?)
      .whereType<String>()
      .toList();
}

// Equipment CRUD Operations
Future<int> createEquipment(SiteEquipment equipment, String siteId) async {
 final db = await dbHelper.database;
  return await db.insert(
    'site_equipment_table',
    equipment.toMap()..['site_id'] = siteId,
  );
}

Future<SiteEquipment?> getEquipmentForSite(String siteId) async {
 final db = await dbHelper.database;
  final maps = await db.query(
    'site_equipment_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return SiteEquipment.fromMap(maps.first);
  }
  return null;
}

Future<int> updateEquipment(SiteEquipment equipment, String siteId) async {
 final db = await dbHelper.database;
  return await db.update(
    'site_equipment_table',
    equipment.toMap(),
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
}

Future<int> deleteEquipment(String siteId) async {
 final db = await dbHelper.database;
  return await db.delete(
    'site_equipment_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
}

// Contact CRUD Operations
Future<int> createContact(Contact contact, String siteId) async {
 final db = await dbHelper.database;
  return await db.insert(
    'contacts_table',
    contact.toMap()..['site_id'] = siteId,
  );
}

Future<List<Contact>> getContactsForSite(String siteId) async {
 final db = await dbHelper.database;
  final maps = await db.query(
    'contacts_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
  return maps.map((e) => Contact.fromMap(e)).toList();
}

Future<Contact?> getContactById(int contactId) async {
 final db = await dbHelper.database;
  final maps = await db.query(
    'contacts_table',
    where: 'id = ?',
    whereArgs: [contactId],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return Contact.fromMap(maps.first);
  }
  return null;
}

Future<int> updateContact(Contact contact) async {
 final db = await dbHelper.database;
  return await db.update(
    'contacts_table',
    contact.toMap(),
    where: 'id = ?',
    whereArgs: [contact.id],
  );
}

Future<int> deleteContact(int contactId) async {
 final db = await dbHelper.database;
  return await db.delete(
    'contacts_table',
    where: 'id = ?',
    whereArgs: [contactId],
  );
}
  

// Power Configuration CRUD
Future<int> createPowerConfig(PowerConfiguration config, String siteId) async {
  final db = await dbHelper.database;
  return await db.insert(
    'power_configuration_table',
    config.toMap()..['site_id'] = siteId,
  );
}

Future<PowerConfiguration?> getPowerConfigForSite(String siteId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'power_configuration_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return PowerConfiguration.fromMap(maps.first);
  }
  return null;
}

Future<int> updatePowerConfig(PowerConfiguration config, String siteId) async {
  final db = await dbHelper.database;
  return await db.update(
    'power_configuration_table',
    config.toMap(),
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
}

Future<int> deletePowerConfig(String siteId) async {
  final db = await dbHelper.database;
  return await db.delete(
    'power_configuration_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
}

// Network Configuration CRUD
Future<int> createNetworkConfig(NetworkConfig config, String siteId) async {
  final db = await dbHelper.database;
  return await db.insert(
    'network_config_table',
    config.toMap()..['site_id'] = siteId,
  );
}

Future<NetworkConfig?> getNetworkConfigForSite(String siteId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'network_config_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return NetworkConfig.fromMap(maps.first);
  }
  return null;
}

Future<int> updateNetworkConfig(NetworkConfig config, String siteId) async {
  final db = await dbHelper.database;
  return await db.update(
    'network_config_table',
    config.toMap(),
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
}

Future<int> deleteNetworkConfig(String siteId) async {
  final db = await dbHelper.database;
  return await db.delete(
    'network_config_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
}

// Tank Configuration CRUD
Future<int> createTankConfig(TankConfig tank, String siteId) async {
  final db = await dbHelper.database;
  return await db.insert(
    'tanks_config_table',
    tank.toMap()..['site_id'] = siteId,
  );
}

Future<List<TankConfig>> getTanksForSite(String siteId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'tanks_config_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
  return maps.map((e) => TankConfig.fromMap(e)).toList();
}

Future<TankConfig?> getTankById(int tankId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'tanks_config_table',
    where: 'id = ?',
    whereArgs: [tankId],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return TankConfig.fromMap(maps.first);
  }
  return null;
}

Future<int> updateTankConfig(TankConfig tank) async {
  final db = await dbHelper.database;
  return await db.update(
    'tanks_config_table',
    tank.toMap(),
    where: 'id = ?',
    whereArgs: [tank.id],
  );
}

Future<int> deleteTankConfig(int tankId) async {
  final db = await dbHelper.database;
  return await db.delete(
    'tanks_config_table',
    where: 'id = ?',
    whereArgs: [tankId],
  );
}

// Pump Configuration CRUD
Future<int> createPump(Pump pump, String siteId) async {
  final db = await dbHelper.database;
  return await db.insert(
    'pump_table',
    pump.toMap()..['site_id'] = siteId,
  );
}

Future<List<Pump>> getPumpsForSite(String siteId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'pump_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
  return maps.map((e) => Pump.fromMap(e)).toList();
}

Future<Pump?> getPumpById(int pumpId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'pump_table',
    where: 'id = ?',
    whereArgs: [pumpId],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return Pump.fromMap(maps.first);
  }
  return null;
}

Future<int> updatePump(Pump pump) async {
  final db = await dbHelper.database;
  return await db.update(
    'pump_table',
    pump.toMap(),
    where: 'id = ?',
    whereArgs: [pump.id],
  );
}

Future<int> deletePump(int pumpId) async {
  final db = await dbHelper.database;
  return await db.delete(
    'pump_table',
    where: 'id = ?',
    whereArgs: [pumpId],
  );
}

// Nozzle Configuration CRUD
Future<int> createNozzle(Nozzle nozzle, String siteId) async {
  final db = await dbHelper.database;
  return await db.insert(
    'nozzles_table',
    {
      ...nozzle.toMap(),
      'site_id': siteId,
      'pump_id': nozzle.pumpId,
      'tank_id': nozzle.tankId,
    },
  );
}

Future<List<Nozzle>> getNozzlesForSite(String siteId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'nozzles_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
  return maps.map((e) => Nozzle.fromMap(e)).toList();
}

Future<List<Nozzle>> getNozzlesForPump(int pumpId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'nozzles_table',
    where: 'pump_id = ?',
    whereArgs: [pumpId],
  );
  return maps.map((e) => Nozzle.fromMap(e)).toList();
}

Future<int> updateNozzle(Nozzle nozzle) async {
  final db = await dbHelper.database;
  return await db.update(
    'nozzles_table',
    nozzle.toMap(),
    where: 'id = ?',
    whereArgs: [nozzle.id],
  );
}

// Note/Review Comment CRUD
Future<int> createNote(ReviewComment  note, String siteId) async {
  final db = await dbHelper.database;
  return await db.insert(
    'review_comment_table',
    note.toMap()..['site_id'] = siteId,
  );
}

Future<List<ReviewComment >> getNotesForSite(String siteId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'review_comment_table',
    where: 'site_id = ?',
    whereArgs: [siteId],
  );
  return maps.map((e) => ReviewComment .fromMap(e)).toList();
}

Future<ReviewComment ?> getNoteById(int noteId) async {
  final db = await dbHelper.database;
  final maps = await db.query(
    'review_comment_table',
    where: 'id = ?',
    whereArgs: [noteId],
    limit: 1,
  );
  if (maps.isNotEmpty) {
    return ReviewComment .fromMap(maps.first);
  }
  return null;
}

Future<int> updateNote(ReviewComment  note) async {
  final db = await dbHelper.database;
  return await db.update(
    'review_comment_table',
    note.toMap(),
    where: 'id = ?',
    whereArgs: [note.id],
  );
}

Future<int> deleteNote(int noteId) async {
  final db = await dbHelper.database;
  return await db.delete(
    'review_comment_table',
    where: 'id = ?',
    whereArgs: [noteId],
  );
}

Future<int> deleteNozzle(int nozzleId) async {
  final db = await dbHelper.database;
  return await db.delete(
    'nozzles_table',
    where: 'id = ?',
    whereArgs: [nozzleId],
  );
}

   Future<int> deleteSiteDetail(String id) async {
    final db = await dbHelper.database;
  return  await db.delete('site_detail_table', where: 'id = ?', whereArgs: [id]);
  }

  
  // In customer_dao.dart
Future<void> debugPrintAllSiteDetails() async {
  final db = await dbHelper.database;
  final List<Map<String, dynamic>> maps = await db.query('site_detail_table');
  print('=== Site Details in Database ===');
  for (var map in maps) {
    print(map);
  }
  print('=== End of Site Details ===');
  
}
Future<void> saveCompleteSite({
  required SiteDetail site,
  required SiteEquipment equipment,
  required PowerConfiguration powerConfig,
  required NetworkConfig networkConfig,
  required List<TankConfig> tanks,
  required List<Pump> pumps,
  required List<Nozzle> nozzles,
  required List<Contact> contacts,
  required List<ReviewComment> notes,
  bool isUpdate = false,
}) async {
  final db = await dbHelper.database;
  
  await db.transaction((txn) async {
    // 1. Handle Site Detail
    if (isUpdate) {
      await txn.update(
        'site_detail_table',
        site.toMap(),
        where: 'site_id = ?',
        whereArgs: [site.siteId],
      );
    } else {
      await txn.insert(
        'site_detail_table',
        site.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 2. Handle Equipment
    if (isUpdate) {
      await txn.update(
        'site_equipment_table',
        equipment.toMap(),
        where: 'site_id = ?',
        whereArgs: [site.siteId],
      );
    } else {
      await txn.insert(
        'site_equipment_table',
        equipment.toMap()..['site_id'] = site.siteId,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 3. Handle Power Config
    if (isUpdate) {
      await txn.update(
        'power_configuration_table',
        powerConfig.toMap(),
        where: 'site_id = ?',
        whereArgs: [site.siteId],
      );
    } else {
      await txn.insert(
        'power_configuration_table',
        powerConfig.toMap()..['site_id'] = site.siteId,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 4. Handle Network Config
    if (isUpdate) {
      await txn.update(
        'network_config_table',
        networkConfig.toMap(),
        where: 'site_id = ?',
        whereArgs: [site.siteId],
      );
    } else {
      await txn.insert(
        'network_config_table',
        networkConfig.toMap()..['site_id'] = site.siteId,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 5. Handle Tanks (always replace all for simplicity)
    await txn.delete(
      'tanks_config_table',
      where: 'site_id = ?',
      whereArgs: [site.siteId],
    );
    for (final tank in tanks) {
      await txn.insert(
        'tanks_config_table',
        tank.toMap()..['site_id'] = site.siteId,
      );
    }

    // 6. Handle Pumps
    await txn.delete(
      'pump_table',
      where: 'site_id = ?',
      whereArgs: [site.siteId],
    );
    for (final pump in pumps) {
      await txn.insert(
        'pump_table',
        pump.toMap()..['site_id'] = site.siteId,
      );
    }

    // 7. Handle Nozzles
    await txn.delete(
      'nozzles_table',
      where: 'site_id = ?',
      whereArgs: [site.siteId],
    );
    for (final nozzle in nozzles) {
      await txn.insert(
        'nozzles_table',
        {
          ...nozzle.toMap(),
          'site_id': site.siteId,
          'pump_id': nozzle.pumpId,
          'tank_id': nozzle.tankId,
        },
      );
    }

    // 8. Handle Contacts
    await txn.delete(
      'contacts_table',
      where: 'site_id = ?',
      whereArgs: [site.siteId],
    );
    for (final contact in contacts) {
      await txn.insert(
        'contacts_table',
        contact.toMap()..['site_id'] = site.siteId,
      );
    }

    // 9. Handle Notes
    await txn.delete(
      'review_comment_table',
      where: 'site_id = ?',
      whereArgs: [site.siteId],
    );
    for (final note in notes) {
      await txn.insert(
        'review_comment_table',
        note.toMap()..['site_id'] = site.siteId,
      );
    }
  });
}
  Future<bool> authenticateLocalUser(String username, String password) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'user_table',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return result.isNotEmpty;
  }

Future<int> insertAddress(Map<String, dynamic> address) async {
    final db = await dbHelper.database;
    return await db.insert('addresses', address);
  }

  Future<List<Map<String, dynamic>>> getAddresses(int userId) async {
    final db = await dbHelper.database;
    return await db.query(
      'addresses',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

// Add these methods to Sitedetaildatabase class
Future<bool> checkUserExists(String username) async {
  final db = await dbHelper.database;
  final result = await db.query(
    'user_table',
    where: 'username = ?',
    whereArgs: [username],
  );
  return result.isNotEmpty;
}

Future<bool> validateUser(String username, String password) async {
  final db = await dbHelper.database;
  final result = await db.query(
    'user_table',
    where: 'username = ? AND password = ?',
    whereArgs: [username, password],
  );
  return result.isNotEmpty;
}

Future<int> insertUser(String username, String password, {String? userId}) async {
  final db = await dbHelper.database;
  return db.insert(
    'user_table',
    {'username': username, 'password': password, 'userId': userId},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
Future<Map<String, dynamic>?> getUser(String username) async {
  final db = await dbHelper.database;
  final results = await db.query(
    'user_table',
    where: 'username = ?',
    whereArgs: [username],
    limit: 1,
  );
  return results.isNotEmpty ? results.first : null;
}

// Save file upload request to pending_syncs for later sync
Future<void> savePendingFileUpload({
    required String siteId,
    required String filePath,
    required String fileType, // 'pdf' or 'image'
  }) async {
    final db = await dbHelper.database;
    final data = {
      'site_id': siteId,
      'file_path': filePath,
      'file_type': fileType,
    };
    await db.insert('pending_syncs', {
      'site_id': siteId,
      'endpoint': '/sitefile/upload',
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'priority': 1,
      'sync_status': 0,
    });
  }
    // SiteFile CRUD
  Future<int> insertSiteFile(SiteFile file) async {
    final db = await dbHelper.database;
    return await db.insert('site_files', file.toMap());
  }

  Future<List<SiteFile>> getFilesForSite(String siteId) async {
    final db = await dbHelper.database;
    final maps = await db.query('site_files', where: 'site_id = ?', whereArgs: [siteId]);
    return maps.map((e) => SiteFile.fromMap(e)).toList();
  }

  Future<int> deleteSiteFile(int id) async {
    final db = await dbHelper.database;
    return await db.delete('site_files', where: 'id = ?', whereArgs: [id]);
  }
}