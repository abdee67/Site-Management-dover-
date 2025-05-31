// sync_service.dart
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'api_service.dart';

class SyncService {
  final ApiService _apiService;
  final Connectivity _connectivity = Connectivity();

  SyncService(this._apiService);

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
          final response = await _apiService.postSiteDetailsBatch(
            jsonDecode(sync['data'] as String),
          );

          if (response.statusCode == 200) {
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