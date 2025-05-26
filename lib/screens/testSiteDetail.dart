import 'package:flutter/material.dart';
import '/models/siteDetailTable.dart';
import '/db/siteDetailDatabase.dart'; // Adjust the import according to your project structure
import '/db/dbHelper.dart'; // Adjust the import according to your project structure,
import 'siteEntry.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer Table',
      theme: ThemeData(
        iconTheme: IconThemeData(color: Colors.black),
        primarySwatch: Colors.blue,
      ),
      home: const SiteDetailScreen(),
    );
  }
}

class SiteDetailScreen extends StatefulWidget {

  const SiteDetailScreen({super.key,});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}
class _SiteDetailScreenState extends State<SiteDetailScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final Sitedetaildatabase sitedetaildatabase = Sitedetaildatabase.instance;
   List<SiteDetail> allsiteDetail = [];// All data loaded from the database
   final List<SiteDetail> companyOptions = [];
  List<SiteDetail> filteredData = [];
  final Set<int> selectedIndex = {}; // Single selection mode
  final TextEditingController globalSearchController = TextEditingController();
  final Map<String, TextEditingController> columnFilters = {
    'siteName': TextEditingController(),
    'siteID': TextEditingController(),
    'cityInfo': TextEditingController(),
    'townInfo': TextEditingController(),
    'enterdDate': TextEditingController(),
    'updatedDate': TextEditingController(),
    'user': TextEditingController(),
  };

  String? selectedCompanyFilter;
  int currentPage = 0;
  final int rowsPerPage = 7;
  bool isAscending = true;
  bool isLoading = false;
  String searchQuery = '';
  String? sortColumn;
  int selectedNavIndex = 0;
  bool isSidebarVisible = false;

  @override
  void initState() {
    super.initState();
    filteredData = List.from(allsiteDetail);
    loadSiteDetail();
  }

  Future<void> loadSiteDetail() async {
    setState(() {
      isLoading = true;
    });
    try {
     final loaded = await sitedetaildatabase.getAllSites();
     setState(() => allsiteDetail = loaded); isLoading = false;
     print('Successfully loaded Site details: ${allsiteDetail.length}');
      filteredData = List.from(allsiteDetail);
      applyFilters();
    } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading Site details: $e'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              loadSiteDetail();
            },
          ),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Error loading Sites: $e');
    } 
    finally {
      setState(() => isLoading = false);
    }
    }

  void refreshData() {
    setState(() {
      filteredData = List.from(allsiteDetail);
      currentPage = 0;
      selectedIndex.clear();
      globalSearchController.clear();
      columnFilters.forEach((key, controller) => controller.clear());
      selectedCompanyFilter = null;
      sortColumn = null;
      isAscending = true;
    });
  }

  void applyFilters() {
    setState(() {
      filteredData = allsiteDetail.where((siteDetail) {
         if (selectedCompanyFilter != null && 
            selectedCompanyFilter!.isNotEmpty && 
            siteDetail.companyName != selectedCompanyFilter) {
          return false;
        }

     // Apply text filters
        for (final key in columnFilters.keys) {
          if (columnFilters[key] is TextEditingController) {
            final filter = columnFilters[key]?.text.toLowerCase();
            final value = siteDetail.toJson()[key]?.toString().toLowerCase() ?? '';
            if (filter!.isNotEmpty && !value.contains(filter)) {
              return false;
            }
          }
        }

        final matchesGlobalSearch = globalSearchController.text.isEmpty ||
            siteDetail.siteName!.toLowerCase().contains(globalSearchController.text.toLowerCase()) ||
            siteDetail.townInfo!.toLowerCase().contains(globalSearchController.text.toLowerCase()) ||
           siteDetail.siteId!.toLowerCase().contains(globalSearchController.text.toLowerCase()) ||
            siteDetail.cityInfo!.toLowerCase().contains(globalSearchController.text.toLowerCase()) ||
            siteDetail.dateEntry!.toString().toLowerCase().contains(globalSearchController.text.toLowerCase()) ||
            siteDetail.dateUpdated!.toString().toLowerCase().contains(globalSearchController.text.toLowerCase());

        final matchesColumnFilters = columnFilters.entries.every((entry) {
          final key = entry.key;
          final controller = entry.value;
          return controller.text.isEmpty || (siteDetail.toJson()[key]?.toString() ?? '').toLowerCase().contains(controller.text.toLowerCase());
        });

        return matchesGlobalSearch && matchesColumnFilters;
      }).toList();

      if (sortColumn != null) {
        filteredData.sort((a, b) {
          final valA = a.toJson()[sortColumn]?.toString() ?? '';
          final valB = b.toJson()[sortColumn]?.toString() ?? '';
          return isAscending ? valA.compareTo(valB) : valB.compareTo(valA);
        });
      }

      currentPage = 0;
    });
  }

  List<DataColumn> buildColumns() {
    return [
      const DataColumn(label: SizedBox.shrink()), // Empty header for checkbox column
      sortableColumn('siteName', 'Site Name'),
      sortableColumn('siteId', 'Site ID'),
      sortableColumn('cityInfo', 'City'),
      sortableColumn('townInfo', 'Town'),
      sortableColumn('dateEntry', 'Enterd'),
      sortableColumn('datedUpdated', 'Updated'),
         DataColumn(
        label: DropdownButton<String>(
          value: selectedCompanyFilter,
  items: [
            const DropdownMenuItem(value: null, child: Text('Company')),
            ...companyOptions.map((companyName) => DropdownMenuItem(
              value: companyName.companyName.toString(),
              child: Text(companyName.companyName.toString()),
            )),
          ],
          hint: const Text('Company'),
          underline: Container(),
          isDense: true,
          onChanged: (value) {
            setState(() {
              selectedCompanyFilter = value;
              applyFilters();
            });
          },
        
        ),
      ),
     
    ];
  }

  DataColumn sortableColumn(String key, String label) => DataColumn(
        label: Row(
          children: [
            Text(label),
            if (sortColumn == key)
              Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
              )
            else
              const Icon(Icons.unfold_more, size: 16),
          ],
        ),
        onSort: (columnIndex, ascending) {
          setState(() {
            if (sortColumn == key) {
              isAscending = !isAscending;
            } else {
              sortColumn = key;
              isAscending = true;
            }
            applyFilters();
          });
        },
      );
// In your customer list screen
  void _navigateToCreateNewSite() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SiteDetailWizard(
          sitedetaildatabase: sitedetaildatabase,
          // No siteId or existingSite passed for new site
        ),
      ),
    ).then((_) => loadSiteDetail()); // Refresh list after returning
  }


  void _navigateToEditSite(String siteId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SiteDetailWizard(
          sitedetaildatabase: sitedetaildatabase,
          siteId: siteId, // Pass siteId to load existing site
        ),
      ),
    ).then((_) => loadSiteDetail()); // Refresh list after returning
  }
          Future<void> _refreshSiteList() async {
            await loadSiteDetail();
            setState(() {
              filteredData = List.from(allsiteDetail);
          applyFilters();
            });
      }
void _deleteSite(SiteDetail siteDetail) async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Site'),
      content: const Text('Are you sure you want to delete this Site?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            setState(() {
              allsiteDetail.removeWhere((p) => p.id == siteDetail.id);
              filteredData = List.from(allsiteDetail);
              selectedIndex.clear();
              applyFilters();
            });
            await sitedetaildatabase.deleteSiteDetail(siteDetail.id.toString());
            Navigator.pop(context);
            selectedIndex.clear();
  await loadSiteDetail();
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
  void _navigateFromSidebar(int index) {
    setState(() {
      selectedNavIndex = index;
      isSidebarVisible = false;
    });
    
    switch(index) {
      case 0: Navigator.pushNamed(context, '/salesEntry'); break;
      case 1: Navigator.pushNamed(context, '/itemEntry'); break;
      case 2: Navigator.pushNamed(context, '/customerEntry'); break;
      case 3: Navigator.pushNamed(context, '/availablitity'); break;
      case 4: Navigator.pushNamed(context, '/salesReport'); break;
      case 5: Navigator.pushNamed(context, '/stockReport'); break;
    }
  }

  Widget buildUomDropdown(
  String currentValue, 
  bool isEditing, 
  Function(String) onChanged
) {
  return isEditing
      ? DropdownButton<String>(
          value: currentValue,
          items: companyOptions.map((SiteDetail site) {
            return DropdownMenuItem<String>(
              value: site.companyName?.toString(),
              child: Text(site.companyName as String),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
              setState(() {}); // Trigger rebuild
            }
          },
        )
      : Text(currentValue);
}

  @override
  Widget build(BuildContext context) {
    final paginatedData = filteredData.
    skip(currentPage * rowsPerPage)
    .take(rowsPerPage).
    toList();
    final isEditMode = selectedIndex.isNotEmpty;
    
    return GestureDetector(
      onTap: () {
        if (isSidebarVisible) {
          setState(() {
            isSidebarVisible = false;
          });
        }
      },
      child: Scaffold(
         appBar: AppBar(
    leadingWidth: 150, // Set a fixed width for leading icons
    leading: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() {
              isSidebarVisible = !isSidebarVisible;
            });
          },
        ),
        const SizedBox(width: 2), // Proper spacing between icons
        IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            // Navigate to actual home screen instead of recreating same screen
            Navigator.pushReplacementNamed(context, '/salesandstockDashboard');
          },
        ),
        const SizedBox(width: 2), // Proper spacing between icons
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed:loadSiteDetail
        ),
      ],
    ),
    title: Row(
      mainAxisAlignment: MainAxisAlignment.center, // Center the title content
      children: [
        const SizedBox(width: 4),
        const Text('Site Detail'),
        const SizedBox(width: 10),
        ClipOval(
          child: Image.asset(
            'assets/images/companyLogo.png',
            height: 36,
            width: 36,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => 
              const Icon(Icons.business, size: 24),
          ),
        ),
      ],
    ),
    centerTitle: true,
     backgroundColor: Colors.brown,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ), // Ensure title is centered in AppBar
  ),

        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  buildToolbar(isEditMode),
                  const SizedBox(height: 16),
                  buildSearchBars(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columnSpacing: 12,
                          headingRowHeight: 40,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 48,
                          columns: buildColumns(),
                          rows: List.generate(paginatedData.length, (i) {
                            final index = currentPage * rowsPerPage + i;
                            final site = paginatedData[i];
                            return DataRow(
                              selected: selectedIndex.contains(index),
                              cells: [
                                DataCell(
                                  Radio<int>(
                                    value: index,
                                    groupValue: selectedIndex.isNotEmpty ? selectedIndex.first : null,
                                    onChanged: (int? value) {
                                      setState(() {
                                        if (value != null) {
                                        selectedIndex.clear();
                                        selectedIndex.add(value);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                DataCell(Text(site.companyName as String)),
                                DataCell(Text(site.siteName ?? '')),
                                DataCell(Text(site.siteId ?? '')),
                                DataCell(Text(site.cityInfo ?? '')),
                                DataCell(Text(site.townInfo ?? '')),
                                DataCell(Text(site.dateEntry?.toIso8601String() ?? '')),
                                DataCell(Text(site.dateUpdated?.toIso8601String() ?? '')),
                              ],
                            );
                          }),
                          border: TableBorder.all(width: 0.5, color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  buildPagination(),
                ],
              ),
            ),
            
            // Sidebar
            if (isSidebarVisible)
              Positioned(
                left: 0,
                top: kToolbarHeight,
                child: Material(
                  elevation: 8,
                  child: Container(
                    width: 200,
                    height: MediaQuery.of(context).size.height - kToolbarHeight,
                    color: Colors.white,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildNavItem(Icons.point_of_sale, 'Sales Entry', 0),
                        _buildNavItem(Icons.event_available, 'Availability', 1),
                        _buildNavItem(Icons.person_add_alt_1, 'Customer Entry', 2),
                        _buildNavItem(Icons.inventory_2, 'Item Entry', 3),
                        _buildNavItem(Icons.bar_chart, 'Sales Report', 4),
                        _buildNavItem(Icons.inventory, 'Stock Report', 5),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildNavItem(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selectedNavIndex == index,
      selectedTileColor: Colors.blue,
      onTap: () {
        setState(() {
          selectedNavIndex = index;
          _navigateFromSidebar(index);
        });
      },
    );
  }

  Widget buildSearchBars() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: globalSearchController,
                decoration: const InputDecoration(
                  labelText: 'Global Search',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => applyFilters(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: columnFilters.keys.map((key) {
              return SizedBox(
                width: 73,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: columnFilters[key],
                    decoration: InputDecoration(
                      labelText: key,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => applyFilters(),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget buildPagination() {
    final totalPages = (filteredData.length / rowsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: currentPage > 0 ? () => setState(() => currentPage--) : null,
        ),
        Text('Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}'),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: currentPage < totalPages - 1 && totalPages > 0
              ? () => setState(() => currentPage++)
              : null,
        ),
      ],
    );
  }

  Widget buildToolbar(bool isEditMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
           ElevatedButton.icon(
          onPressed: isEditMode
              ? (selectedIndex.isNotEmpty 
                  ? () => _navigateToEditSite(selectedIndex.first as String) 
                  : null)
              : () => _navigateToCreateNewSite(),
          icon: Icon(isEditMode ? Icons.edit : Icons.add),
          label: Text(isEditMode ? 'Edit' : 'Create'),
        ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isEditMode
                ? () => _deleteSite(filteredData[selectedIndex.first])
                : null,
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh All'),
          ),
        ],
      ),
    );
  }
}