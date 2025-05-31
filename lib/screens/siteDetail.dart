
import 'package:flutter/material.dart';
import '/db/siteDetailDatabase.dart';
import 'siteEntry.dart';
import '/services/api_service.dart'; // Import your API service
import '/services/sync_service.dart'; 

class SiteDetailScreen extends StatefulWidget {
  final String username;
  final Sitedetaildatabase sitedetaildatabase;
  const SiteDetailScreen({
    super.key, 
    required this.sitedetaildatabase, 
    required this.username
  });

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  List<Map<String, dynamic>> _sites = [];
  bool _isLoading = true;
  final bool _isSyncing = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredSites = [];
  final ApiService _apiService = ApiService(); // Initialize API service
  late final SyncService syncService;

  @override
  void initState() {
    super.initState();
    syncService = SyncService(_apiService);
    _searchController.addListener(_filterSites);
    _loadSites();
  }



  void _filterSites() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSites = _sites.where((site) {
        return (site['site_name']?.toString().toLowerCase().contains(query) ?? false) ||
               (site['site_id']?.toString().toLowerCase().contains(query) ?? false) ||
               (site['company_name']?.toString().toLowerCase().contains(query) ?? false) ||
               (site['city_info']?.toString().toLowerCase().contains(query) ?? false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sites: $e')),
      );
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
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: _loadSites
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
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
            child: _isLoading
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
                              title: Text(site['site_name'] ?? 'No Name'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Company id: ${site['id']}'),
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