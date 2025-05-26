import 'package:dover/db/siteDetailDatabase.dart';
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

class SiteDetailApp extends StatelessWidget {
  const SiteDetailApp({super.key});
  

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
