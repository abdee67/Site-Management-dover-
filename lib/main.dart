
import 'dart:async';

import 'package:dover/db/siteDetailDatabase.dart';
import 'package:dover/providers/sync_provider.dart';
import 'package:dover/services/api_service.dart';
import 'package:dover/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login.dart';
import 'screens/siteDetail.dart';
import 'screens/siteEntry.dart';

// Import ItemDatabase
// Import DatabaseHelper

void main() async {
    final apiService = ApiService();
     final database = Sitedetaildatabase.instance;
  WidgetsFlutterBinding.ensureInitialized();

  // After successful login
  // In your main.dart or wherever you initialize your database
  database.printFullSiteDetails;
  await database.printAllNozzles();

  final dbInstance = await database.dbHelper.database;
  final syncService = SyncService(apiService, dbInstance);
  runApp( MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        Provider(create: (_) => database),
        Provider(create: (_) => apiService),
        Provider(create: (_) => syncService),
      ],
      child: SiteDetailApp(apiService: apiService),
    ),

  );
    Timer.periodic(const Duration(seconds: 15), (timer) async {
    final db = await Sitedetaildatabase.instance.dbHelper.database;
    final syncService = SyncService(ApiService(), db);
    await syncService.processPendingSyncs(db);
  });
}

class SiteDetailApp extends StatefulWidget {
  final ApiService apiService;

  const SiteDetailApp({super.key, required this.apiService});

  @override
  _SiteDetailAppState createState() => _SiteDetailAppState();
}

class _SiteDetailAppState extends State<SiteDetailApp>
    with WidgetsBindingObserver {
  final Sitedetaildatabase db = Sitedetaildatabase.instance;

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
        '/': (context) => LoginScreen(apiService: widget.apiService),
        '/addressEntry': (context) => Placeholder(),
        '/sites':
            (context) => SiteDetailScreen(
              sitedetaildatabase: Sitedetaildatabase.instance, username: '',
            ),
        '/sites/siteDetail':
            (context) => SiteDetailWizard(
              sitedetaildatabase: Sitedetaildatabase.instance,
            ),
        // '/companyEntry': (context) => CompanyManagementPage(
        // database: Sitedetaildatabase.instance,
        //   ),
      },
    );
  }
}

