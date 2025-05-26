
// lib/db/customer_database.dart
import 'package:flutter/material.dart';
import '/db/siteDetailDatabase.dart'; // Adjust the import according to your project structure
// Adjust the import according to your project structure,

class CompanyManagementPage extends StatefulWidget {
  final Sitedetaildatabase database;

  const CompanyManagementPage({super.key, required this.database});

  @override
  _CompanyManagementPageState createState() => _CompanyManagementPageState();
}

class _CompanyManagementPageState extends State<CompanyManagementPage> {
  List<Map<String, dynamic>> _companies = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    final companies = await widget.database.getCompaniesForDropdown();
    setState(() {
      _companies = companies;
    });
  }

  Future<void> _addCompany() async {
    if (_nameController.text.isEmpty) return;

    try {
      await widget.database.addCompany(
        _nameController.text,
        _countryController.text,
      );
      _nameController.clear();
      _countryController.clear();
      await _loadCompanies();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding company: $e')),
      );
    }
  }

  Future<void> _deleteCompany(int id) async {
    try {
      await widget.database.deleteCompany(id);
      await _loadCompanies();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting company: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Companies')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _countryController,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _addCompany,
                  child: const Text('Add Company'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _companies.length,
              itemBuilder: (context, index) {
                final company = _companies[index];
                return ListTile(
                  title: Text(company['company_name']),
                  subtitle: Text(company['country'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteCompany(company['id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    super.dispose();
  }
}