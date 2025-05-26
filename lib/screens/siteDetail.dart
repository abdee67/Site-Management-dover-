import 'package:dover/models/nozzlesTable.dart';
import 'package:dover/models/reviewCommentTable.dart';
import 'package:dover/models/siteEquipment.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '/models/siteDetailTable.dart';
import '/db/siteDetailDatabase.dart'; // Adjust the import according to your project structure
// Adjust the import according to your project structure,
import 'siteEntry.dart';
import '/models/contactTable.dart';
import '/models/powerConfigurationTable.dart';
import '/models/networkConfigTable.dart';
import '/models/pumpTable.dart';
import '/models/tanksConfigTable.dart';

class SiteDetailScreen extends StatefulWidget {
  final Sitedetaildatabase sitedetaildatabase;
  const SiteDetailScreen({super.key, required this.sitedetaildatabase});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  List<Map<String, dynamic>> _sites = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredSites = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSites);
    _loadSites();
  }

  void _filterSites() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSites =
          _sites.where((site) {
            return (site['site_name']?.toString().toLowerCase().contains(
                      query,
                    ) ??
                    false) ||
                (site['site_id']?.toString().toLowerCase().contains(query) ??
                    false) ||
                (site['company_name']?.toString().toLowerCase().contains(
                      query,
                    ) ??
                    false) ||
                (site['city_info']?.toString().toLowerCase().contains(query) ??
                    false);
          }).toList();
    });
  }

  Future<void> _loadSites() async {
    setState(() => _isLoading = true);
    try {
      final db = await widget.sitedetaildatabase.dbHelper.database;
      final sites = await db.rawQuery('''
        SELECT s.*, a.company_name 
        FROM site_detail_table s
        LEFT JOIN address_table a ON s.company_name = a.id
        ORDER BY s.date_entry DESC
      ''');
      setState(() {
        _sites = sites;
        _filteredSites = List.from(sites);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading sites: $e')));
    }
  }

  // Update the navigateToEditSite method to load all data properly
  Future<void> navigateToEditSite(Database db, int siteId) async {
    try {
      // 1. Fetch Site Detail
      final siteResults = await db.query(
        'site_detail_table',
        where: 'id = ?',
        whereArgs: [siteId],
      );
      if (siteResults.isEmpty) {
        throw Exception('Site not found for ID: $siteId');
      }
      final siteData = siteResults.first;

      // 2. Fetch All Related Data
      final contacts = await db.query(
        'contacts_table',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );

      final siteEquipment = await db.query(
        'site_equipment_table',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );

      final powerConfig = await db.query(
        'power_configuration_table',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );

      final networkConfig = await db.query(
        'network_config_table',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );

      final tanksData = await db.query(
        'tanks_config_table',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );

      final pumpsData = await db.query(
        'pump_table',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );

      final nozzlesData = await db.query(
        'nozzles_table',
        where: 'pump_id IN (SELECT id FROM pump_table WHERE site_id = ?)',
        whereArgs: [siteId],
      );

      final notesData = await db.query(
        'review_comment_table',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );

      // 3. Map all data to models
      final List<Contact> contactList =
          contacts.map((c) => Contact.fromMap(c)).toList();
      final List<TankConfig> tankList =
          tanksData.map((t) => TankConfig.fromMap(t)).toList();
      final List<Pump> pumpList =
          pumpsData.map((p) => Pump.fromMap(p)).toList();
      final List<Nozzle> nozzleList =
          nozzlesData.map((n) => Nozzle.fromMap(n)).toList();
      final List<ReviewComment> noteList =
          notesData.map((n) => ReviewComment.fromMap(n)).toList();

      // Prepare nozzle selections based on pump and tank data
      for (final nozzle in nozzleList) {
        if (nozzle.pumpId != null) {
          final pump = pumpList.firstWhere(
            (p) => p.id == nozzle.pumpId,
            orElse: () => Pump(),
          );
          if (pump.id != null) {
            nozzle.pumpsSelection =
                'Pump ${pump.pumpNumber} - ${pump.brandInfo}';
          }
        }

        if (nozzle.tankId != null) {
          final tank = tankList.firstWhere(
            (t) => t.id == nozzle.tankId,
            orElse: () => TankConfig(),
          );
          if (tank.id != null) {
            nozzle.tankSelection =
                'Tank ${tank.tankNumber} - ${tank.gradesInfo}';
          }
        }
      }

      // 4. Navigate to Edit Page
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SiteDetailWizard(
                  sitedetaildatabase: widget.sitedetaildatabase,
                  existingSite: SiteDetail.fromMap(siteData),
                  equipmentInfo:
                      siteEquipment.isNotEmpty
                          ? SiteEquipment.fromMap(siteEquipment.first)
                          : null,
                  powerConfig:
                      powerConfig.isNotEmpty
                          ? PowerConfiguration.fromMap(powerConfig.first)
                          : null,
                  networkConfig:
                      networkConfig.isNotEmpty
                          ? NetworkConfig.fromMap(networkConfig.first)
                          : null,
                  tanks: tankList,
                  pumps: pumpList,
                  nozzles: nozzleList,
                  contacts: contactList,
                  notes: noteList,
                ),
          ),
        );
        _loadSites(); // Refresh the list after returning
      }
    } catch (e, stack) {
      debugPrint('Error loading site: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading site: ${e.toString()}')),
        );
      }
    }
  }

  void _navigateToCreateNewSite() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                SiteDetailWizard(sitedetaildatabase: widget.sitedetaildatabase),
      ),
    ).then((_) => _loadSites());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Details'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSites),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search sites...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSites.isEmpty
                    ? const Center(child: Text('No sites found'))
                    : ListView.builder(
                      itemCount: _filteredSites.length,
                      itemBuilder: (context, index) {
                        final site = _filteredSites[index];
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            onTap: () async {
                              final db =
                                  await widget
                                      .sitedetaildatabase
                                      .dbHelper
                                      .database;
                              await navigateToEditSite(db, site['id']);
                            },
                            title: Text(site['site_name'] ?? 'No Name'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Company: ${site['company_name']}'),
                                Text('SiteName: ${site['site_name']}'),
                                Text('Site ID: ${site['site_id']}'),
                                Text('City: ${site['city_info']}'),
                                Text(
                                  'Town: ${site['town_info']}, ${site['country_info']}',
                                ),
                                Text('Created: ${site['date_entry']}'),
                                Text('Updated at: ${site['date_update']}'),
                              ],
                            ),
                            trailing: const Icon(Icons.edit),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateNewSite,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
