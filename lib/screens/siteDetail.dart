import 'package:flutter/material.dart';
import '/db/siteDetailDatabase.dart';
import 'siteEntry.dart';
import '/services/api_service.dart';
import '/services/sync_service.dart';
import '/screens/login.dart';

class SiteDetailScreen extends StatefulWidget {
  final String username;
  final Sitedetaildatabase sitedetaildatabase;

  const SiteDetailScreen({
    super.key,
    required this.sitedetaildatabase,
    required this.username,
  });

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _filteredSites = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;


  final ApiService _apiService = ApiService();
  late final SyncService syncService;

  @override
  void initState() {
    super.initState();
    widget.sitedetaildatabase.dbHelper.database.then((db) {
      syncService = SyncService(_apiService, db);
    });
    _searchController.addListener(_filterSites);
    _loadSites();
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
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sites: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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

  void _navigateToCreateNewSite() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SiteDetailWizard(sitedetaildatabase: widget.sitedetaildatabase),
      ),
    ).then((_) => _loadSites());
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
   Future<void> _performLogout() async {
    // Clear any sensitive data if needed
    // For example: await widget.sitedetaildatabase.clearSessionData();
    
    // Navigate to login screen and remove all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen(apiService: _apiService)),
      (Route<dynamic> route) => false,
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateString;
    }
  }


  @override
  Widget build(BuildContext context) {
      return Scaffold(
  appBar: AppBar(
    title: const Text(
      'Site Detail List',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        letterSpacing: 0.5,
      ),
    ),
    centerTitle: true,
    leading: Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Tooltip(
        message: 'User Profile',
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => (),
          child: CircleAvatar(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                widget.username.substring(0, 3).toUpperCase(),
                key: ValueKey<String>(widget.username),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    actions: [
      Tooltip(
        message: 'Refresh List',
        child: IconButton(
          icon: AnimatedRotation(
            turns: _isLoading ? 1 : 0,
            duration: const Duration(milliseconds: 1000),
            child: const Icon(Icons.refresh),
          ),
          onPressed: _loadSites,
        ),
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'More options',
        onSelected: (value) async {
          if (value == 'logout') _logout();
         
        },
        itemBuilder: (BuildContext context) => [
        /** *  PopupMenuItem<String>(
            value: 'upload',
            child: ListTile(
              leading: Icon(Icons.attach_file, color: Colors.blue),
              title: Text('Upload PDF or Image'),
            ),
          ),**/
          const PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    ],
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF006064), Color(0xFF26C6DA)],
        ),
      ),
    ),
    elevation: 4,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(16),
      ),
    ),
  ),
  // ... rest of your scaffold
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search sites...',
                    hintText: 'Search by Name, ID, or Location',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Logged in as ${widget.username}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ),
              ),
              Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredSites.isEmpty
                          ? _buildEmptyState()
                          : _buildSiteList(),
                ),
            ],
          ),

        ],
      ),
    floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateNewSite,
        icon: const Icon(Icons.add),
        label: const Text('New Site'),
        backgroundColor: Color(0xFF006064),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSiteList() {
    return ListView.builder(
      itemCount: _filteredSites.length,
      itemBuilder: (context, index) {
        final site = _filteredSites[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showSiteDetails(site),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        site['site_name'] ?? 'No Name',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          site['site_id'] ?? 'N/A',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue[800]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    site['company_name'] ?? 'No Company',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${site['city_info'] ?? ''}${site['town_info'] != null ? ', ${site['town_info']}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(site['date_entry']),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            ),
          );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No sites found', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
          if (_searchController.text.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchController.clear();
                _filterSites();
              },
              child: const Text('Clear search'),
            ),
        ],
      ),
    );
  }

  void _showSiteDetails(Map<String, dynamic> site) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    site['site_name'] ?? 'No Name',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow(Icons.business, 'Company', site['company_name']),
              _buildDetailRow(Icons.tag, 'Site ID', site['site_id']),
              _buildDetailRow(Icons.location_city, 'City', site['city_info']),
              _buildDetailRow(Icons.location_on, 'Town', site['town_info']),
              _buildDetailRow(Icons.flag, 'Country', site['country_info']),
              _buildDetailRow(Icons.calendar_today, 'Created', _formatDate(site['date_entry'])),
              _buildDetailRow(Icons.update, 'Last Updated', _formatDate(site['date_update'])),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blueGrey)),
                Text(value ?? 'Not specified', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
