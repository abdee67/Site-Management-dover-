// sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'api_service.dart';

class SyncService {
  static const int maxRetries = 3; // Maximum number of retry attempts
  final ApiService _apiService;
  final Database database;
  final Connectivity _connectivity = Connectivity();
   static const String baseUrl = 'https://demo.techequations.com/dover/api';
     static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };


  SyncService(this._apiService, this.database);

Future<void> processPendingSyncs(Database db) async {
  try {
    // Check connectivity first
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    // Get all pending syncs ordered by priority and retry count
    final pendingSyncs = await db.query(
      'pending_syncs',
      orderBy: 'priority DESC, retry_count ASC',
    );

    for (final sync in pendingSyncs) {
      try {
        // Prepare main data
        final Map<String, dynamic> apiData = jsonDecode(sync['data'] as String);
        
        // Add attachments if this is a full sync

          final attachments = await _prepareAttachments(db, sync['site_id'] as int);
          apiData['attachmentCollection'] = attachments;
        

        // Send combined data
        final response = await _apiService.postSiteDetailsBatch(apiData);

        if (response.statusCode == 200) {
          // Mark files as synced if they were included
            await _markFilesAsSynced(db, sync['site_id'] as int);
          // Success - remove from pending
          await db.delete(
            'pending_syncs',
            where: 'id = ?',
            whereArgs: [sync['id']],
          );
        } else {
          // Failed - increment retry count
          await _updateSyncAttempt(db, sync['id'] as int, sync['retry_count'] as int);
        }
      } catch (e) {
        debugPrint('Failed to process pending sync: $e');
        await _updateSyncAttempt(db, sync['id'] as int, sync['retry_count'] as int);
      }
    }
  } catch (e) {
    debugPrint('Error in processPendingSyncs: $e');
  }
}

Future<List<Map<String, dynamic>>> _prepareAttachments(Database db, int siteId) async {
  final attachments = <Map<String, dynamic>>[];
  final pendingFiles = await db.query(
    'site_files',
    where: 'site_id = ? AND sync_status = 0',
    whereArgs: [siteId],
  );

  // Process files in batches to avoid memory issues
  for (var i = 0; i < pendingFiles.length; i += 5) {
    final batch = pendingFiles.sublist(i, min(i + 5, pendingFiles.length));
    
    await Future.wait(batch.map((file) async {
      try {
        final filePath = file['file_path'] as String;
        final fileObj = File(filePath);
        
        if (await fileObj.exists()) {
          final bytes = await fileObj.readAsBytes();
          attachments.add({
            "filename": file['file_name'] as String,
            "filePath": base64Encode(bytes),
            "fileType": file['file_type'] as String,
          });
        }
      } catch (e) {
        debugPrint('Error preparing file: $e');
      }
    }));
  }

  return attachments;
}

Future<void> _markFilesAsSynced(Database db, int siteId) async {
  await db.update(
    'site_files',
    {'sync_status': 1},
    where: 'site_id = ? AND sync_status = 0',
    whereArgs: [siteId],
  );
}

Future<void> _updateSyncAttempt(Database db, int syncId, int currentRetryCount) async {
  await db.update(
    'pending_syncs',
    {
      'retry_count': currentRetryCount + 1,
      'last_attempt': DateTime.now().toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [syncId],
  );
}
}