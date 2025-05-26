import 'dart:async';
import 'dart:convert';

import 'package:dover/db/siteDetailDatabase.dart';
import 'package:dover/services/api_service.dart';
import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/siteDetail.dart';
import 'screens/siteEntry.dart';


// Import ItemDatabase
// Import DatabaseHelper

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // In your main.dart or wherever you initialize your database
final database = Sitedetaildatabase.instance;
await database.insertSampleCompanies();
database.printFullSiteDetails;
await database.printAllNozzles();
  runApp(const SiteDetailApp());
}
class SiteDetailApp extends StatefulWidget {
  const SiteDetailApp({super.key});

  @override
  _SiteDetailAppState createState() => _SiteDetailAppState();
}

class _SiteDetailAppState extends State<SiteDetailApp> with WidgetsBindingObserver {
  Timer? _syncTimer;
  final Sitedetaildatabase db = Sitedetaildatabase.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSyncTimer();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      await _processPendingSyncs();
    });
  }

  Future<void> _processPendingSyncs() async {
    final dbInstance = await db.dbHelper.database;
    final pendingSyncs = await dbInstance.query('pending_syncs');
    
    if (pendingSyncs.isNotEmpty) {
      final apiService = ApiService();
      for (final sync in pendingSyncs) {
        try {
          final response = await apiService.postSiteDetailsBatch(
            jsonDecode(sync['data'] as String),
          );
          
          if (response.statusCode == 200) {
            await dbInstance.delete(
              'pending_syncs',
              where: 'id = ?',
              whereArgs: [sync['id']],
            );
          }
        } catch (e) {
          debugPrint('Periodic sync failed: $e');
        }
      }
    }
  }

  // This widget is the root of your application.
 @override
Widget build(BuildContext context) {
  return MaterialApp(
    title: 'Dover',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    initialRoute: '/',
    routes: {
      '/': (context) => LoginScreen(),
      '/addressEntry': (context) => Placeholder(),
      '/sites': (context) => SiteDetailScreen(sitedetaildatabase: Sitedetaildatabase.instance,),
      '/sites/siteDetail':(context) => SiteDetailWizard(sitedetaildatabase:Sitedetaildatabase.instance),
     // '/companyEntry': (context) => CompanyManagementPage(
             // database: Sitedetaildatabase.instance,
         //   ),
    }
  );
}
    }
