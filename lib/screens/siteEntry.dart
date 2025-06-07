// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dover/providers/sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '/db/siteDetailDatabase.dart';
import '../models/siteDetailTable.dart';
import '/models/contactTable.dart';
import '/models/siteEquipment.dart';
import '/models/powerConfigurationTable.dart';
import '/models/networkConfigTable.dart';
import '/models/nozzlesTable.dart';
import '/models/pumpTable.dart';
import '/models/tanksConfigTable.dart';
import '/models/reviewCommentTable.dart';
import '/services/api_service.dart';
import '/services/sync_service.dart';

void main() {
  runApp(const SiteDetailApp());
}

class SiteDetailApp extends StatelessWidget {
  const SiteDetailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Site Management',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.amber.shade600,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: SiteDetailWizard(sitedetaildatabase: Sitedetaildatabase.instance),
    );
  }
}

class SiteDetailWizard extends StatefulWidget {
  final Sitedetaildatabase sitedetaildatabase;
  final SiteDetail? existingSite;
  final String? siteId;
  final SiteEquipment? equipmentInfo;
  final PowerConfiguration? powerConfig;
  final NetworkConfig? networkConfig;
  final List<TankConfig>? tanks;
  final List<Pump>? pumps;
  final List<Nozzle>? nozzles;
  final List<Contact>? contacts;
  final List<ReviewComment>? notes;

  const SiteDetailWizard({
    super.key,
    required this.sitedetaildatabase,
    this.existingSite,
    this.siteId,
    this.contacts,
    this.equipmentInfo,
    this.networkConfig,
    this.notes,
    this.nozzles,
    this.powerConfig,
    this.pumps,
    this.tanks,
  });

  @override
  State<SiteDetailWizard> createState() => _SiteDetailWizardState();
}

class _SiteDetailWizardState extends State<SiteDetailWizard> {
  late SiteDetail _siteDetail;
  late SiteEquipment _equipmentInfo;
  late PowerConfiguration _powerConfig;
  late NetworkConfig _networkConfig;
  late List<TankConfig> _tanks;
  late List<Pump> _pumps;
  late List<Nozzle> _nozzles;
  late List<Contact> _contacts;
  late List<ReviewComment> _notes;
  int _currentStep = 0;
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();
  bool _isSyncingAddresses = false;
  late final SyncService _syncService;
  bool _isTransitioning = false; // Add this flag
  final _formKey = GlobalKey<FormState>();
  bool _isGettingLocation = false;
  // Form data models
  final Set<int> _visitedSteps = {0};
  List<Map<String, dynamic>> _companyNames = [];
  int? _selectedCompanyId;

  @override
  void initState() {
    super.initState();
    _siteDetail =
        widget.existingSite ?? SiteDetail()
          ..countryInfo = 'Ethiopia';
    _equipmentInfo = widget.equipmentInfo ?? SiteEquipment();
    _powerConfig = widget.powerConfig ?? PowerConfiguration();
    _networkConfig = widget.networkConfig ?? NetworkConfig();
    _tanks = widget.tanks ?? [];
    _pumps = widget.pumps ?? [];
    _nozzles = widget.nozzles ?? [];
    _contacts = widget.contacts ?? [];
    _notes = widget.notes ?? [];
    _syncService = SyncService(_apiService);
    _initConnectivityListener();
    _loadCompanyNames();
    // ... other init code ...
  }

  // Initialize connectivity listener
  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        // When connectivity is restored, try to process pending syncs
        final db = await widget.sitedetaildatabase.dbHelper.database;
        await _syncService.processPendingSyncs(db);
      }
    });
  }

  Future<void> _syncAddressData(Sitedetaildatabase db) async {
    try {
      // First check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (!isOnline) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet connection. Cannot sync addresses.'),
            ),
          );
        }
        return;
      }

      setState(() => _isSyncingAddresses = true);

      final database = await db.dbHelper.database;
      final credentials = await _apiService.getStoredCredentials();

      if (credentials == null) {
        _showConnectivityError();
        return;
      }

      final result = await _apiService.authenticateUser(
        credentials['username']!,
        credentials['password']!,
      );

      if (result['success'] == true && result['addresses'] != null) {
        final addresses = result['addresses'] as List<dynamic>;

        // Only update existing records, don't delete the table
        for (var address in addresses) {
          await database.insert('address_table', {
            'id': address['id'],
            'company_name': address['companyName'],
            'country': address['country'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Reload company names after sync
        await _loadCompanyNames();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Addresses updated successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('Address sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing addresses: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingAddresses = false);
      }
    }
  }

  void _showConnectivityError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'First login requires internet connection. Please connect to the internet.',
        ),
      ),
    );
  }

  Future<void> _loadCompanyNames() async {
    try {
      final companies =
          await widget.sitedetaildatabase.getCompaniesForDropdown();

      if (mounted) {
        setState(() {
          _companyNames = companies;
          if (widget.existingSite?.companyId != null) {
            _selectedCompanyId = widget.existingSite?.companyId;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading companies: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: AppBar(
          automaticallyImplyLeading: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF006064), Color(0xFF26C6DA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Text(
            _getStepTitles(_currentStep),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          actions: [
            Tooltip(
              message: 'Sync Address Data',
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child:
                    _isSyncingAddresses
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : IconButton(
                          icon: const Icon(
                            Icons.sync_outlined,
                            color: Colors.white,
                          ),
                          onPressed:
                              () => _syncAddressData(widget.sitedetaildatabase),
                        ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 9,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 6,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          //Progress indicator
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), //Disable Swipe

              children: [
                _buildSiteDetailsStep(),
                _buildEquipmentStep(),
                _buildPowerConfigStep(),
                _buildNetworkConfigStep(),
                _buildTankConfigStep(),
                _buildPumpConfigStep(),
                _buildNozzleConfigStep(),
                _buildNotesStep(),
                _buildConfirmationStep(),
              ],
            ),
          ),
          //Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  FilledButton.tonal(
                    onPressed: _isTransitioning ? null : _goToPreviousStep,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, size: 20),
                        SizedBox(width: 4),
                        Text('Previous'),
                      ],
                    ),
                  )
                else
                  const SizedBox(width: 120),

                FilledButton(
                  onPressed:
                      _isTransitioning
                          ? null
                          : (_currentStep < 8 ? _goToNextStep : _submitForm),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    backgroundColor:
                        _currentStep < 8
                            ? Color(0xFF006064)
                            : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_currentStep < 8 ? 'Next' : 'Submit'),
                      if (_currentStep < 8) ...[
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 20),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitles(int step) {
    final titles = [
      'Site Details',
      'Equipment',
      'Power Config',
      'Networking',
      'Tank Config',
      'Pump Config',
      'Nozzle Config',
      'Notes',
      'Confirmation',
    ];
    return titles[step];
  }

  void _goToNextStep() {
    if (_isTransitioning) return; // Prevent multiple triggers

    // Check if current step is complete before proceeding
    bool isCurrentStepValid = _validateCurrentStep();

    if (!isCurrentStepValid) {
      // Show error feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all required fields before proceeding',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _visitedSteps.add(_currentStep);
    if (_currentStep == 5) {
      _generateNozzlesFromPumps();
    }
    setState(() {
      if (_currentStep < 8) {
        _isTransitioning = true; // Start transition
        _currentStep++;

        _pageController
            .nextPage(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOut,
            )
            .then((_) {
              setState(() => _isTransitioning = false); // End transition
            });
      }
    });
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Site Details Step
        final isFormValid =
            _selectedCompanyId != null &&
            (_siteDetail.siteName?.isNotEmpty ?? false) &&
            (_siteDetail.siteId?.isNotEmpty ?? false) &&
            (_siteDetail.addressInfo?.isNotEmpty ?? false) &&
            _contacts.isNotEmpty;

        // Optionally trigger form validation if using Form widget
        if (_formKey.currentState != null) {
          _formKey.currentState!.validate();
        }

        return isFormValid;

      case 1: // Add validation for other steps as needed
        return true; // Or add specific validation for step 1

      default:
        return true; // Other steps don't require validation
    }
  }

  void _goToPreviousStep() {
    if (_isTransitioning) return; // Prevent multiple triggers

    setState(() {
      if (_currentStep > 0) {
        _isTransitioning = true; // Start transition
        _currentStep--;

        _pageController
            .previousPage(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOut,
            )
            .then((_) {
              setState(() => _isTransitioning = false); // End transition
            });
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled, show dialog to enable
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isGettingLocation = true);
        // Permissions are denied forever, show dialog to open app settings
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions are permanently denied. Please enable them in app settings',
              ),
            ),
          );
          await openAppSettings();
        }
        return;
      }

      // Get the current position
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        // Format coordinates to 6 decimal places
        String formattedCoords =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

        // Update the text field with the coordinates
        setState(() {
          _siteDetail.geolocationInfo = formattedCoords;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location obtained: ${position.latitude}, ${position.longitude}',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Widget _buildCompanyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isSyncingAddresses)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Color(0xFF006064),
            color: Colors.lightBlueAccent,
          ),
        DropdownButtonFormField<int>(
          value: _selectedCompanyId,
          decoration: InputDecoration(
            labelText: 'Company Name *',
            labelStyle: const TextStyle(color: Colors.blueGrey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF006064)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF006064)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF006064), width: 2),
            ),
            filled: true,
            fillColor: Colors.blueGrey[50],
            suffixIcon:
                _isSyncingAddresses
                    ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF006064),
                        ),
                      ),
                    )
                    : const Icon(Icons.business, color: Color(0xFF006064)),
          ),
          items:
              _companyNames
                  .map(
                    (company) => DropdownMenuItem<int>(
                      value: company['id'],
                      child: Text(
                        company['company_name'],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCompanyId = value;
              _siteDetail.companyId = value;
              _siteDetail.companyName =
                  _companyNames.firstWhere(
                    (c) => c['id'] == value,
                  )['company_name'];
            });
          },
          validator:
              (value) => value == null ? 'Company must be selected' : null,
          borderRadius: BorderRadius.circular(12),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF006064)),
          dropdownColor: Colors.blueGrey[50],
        ),
      ],
    );
  }

  Widget _buildSiteDetailsStep() {
    // Track form validity
    bool isFormValid =
        _selectedCompanyId != null &&
        (_siteDetail.siteName?.isNotEmpty ?? false) &&
        (_siteDetail.siteId?.isNotEmpty ?? false) &&
        (_siteDetail.addressInfo?.isNotEmpty ?? false) &&
        _contacts.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key:
            _formKey, // You'll need to add a GlobalKey<FormState> to your widget

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: Color(0xFF006064), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF006064),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Basic Site Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF006064), height: 20),
                    const SizedBox(height: 10),
                    _buildCompanyDropdown(),
                    const SizedBox(height: 16),

                    // Required fields with improved styling
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Site Name *',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'Enter the site name (required)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.place,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                      ),
                      validator:
                          (value) =>
                              value?.isEmpty ?? true
                                  ? 'Please enter the site name'
                                  : null,
                      onSaved: (value) => _siteDetail.siteName = value,
                      onChanged: (value) {
                        setState(() {
                          _siteDetail.siteName = value;
                        });
                      },
                      initialValue: _siteDetail.siteName,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Site ID *',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'Enter unique site ID (required)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.tag,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                      ),
                      validator:
                          (value) =>
                              value?.isEmpty ?? true
                                  ? 'Please enter the site ID'
                                  : null,
                      onSaved: (value) => _siteDetail.siteId = value,
                      onChanged: (value) => _siteDetail.siteId = value,
                      initialValue: _siteDetail.siteId,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Full Address *',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'Woreda, Kebele, etc. (required)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.location_on,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                      ),
                      maxLines: 3,
                      validator:
                          (value) =>
                              value?.isEmpty ?? true
                                  ? 'Please enter the address'
                                  : null,
                      onSaved: (value) => _siteDetail.addressInfo = value,
                      onChanged: (value) => _siteDetail.addressInfo = value,
                      initialValue: _siteDetail.addressInfo,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Location Details Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: Color(0xFF006064), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.map_outlined, color: Color(0xFF006064)),
                        SizedBox(width: 8),
                        Text(
                          'Location Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF006064), height: 20),
                    const SizedBox(height: 10),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Country',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'Ethiopia (auto-filled)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.flag,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                      ),
                      readOnly: true,
                      initialValue: 'Ethiopia',
                      onSaved: (value) => _siteDetail.countryInfo = 'Ethiopia',
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'City/Town',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'e.g. Addis Ababa',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.location_city,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                      ),
                      onSaved: (value) => _siteDetail.cityInfo = value,
                      onChanged: (value) => _siteDetail.cityInfo = value,
                      initialValue: _siteDetail.cityInfo,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Specific Area/Subcity',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'e.g. Bole, Kirkos',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.pin_drop,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                      ),
                      onSaved: (value) => _siteDetail.townInfo = value,
                      onChanged: (value) => _siteDetail.townInfo = value,
                      initialValue: _siteDetail.townInfo,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'GPS Coordinates (optional)',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'e.g. 9.005401, 38.763611',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.gps_fixed,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                        suffixIcon:
                            _isGettingLocation
                                ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : IconButton(
                                  icon: const Icon(
                                    Icons.my_location,
                                    color: Color(0xFF006064),
                                    size: 20,
                                  ),
                                  onPressed:
                                      _getCurrentLocation, // Connect to the location function
                                ),
                      ),
                      controller: TextEditingController(
                        text: _siteDetail.geolocationInfo ?? '',
                      ),
                      readOnly:
                          true, // Make field read-only since we're auto-filling it
                      onTap:
                          _getCurrentLocation, // Allow tapping anywhere in the field to get location
                      onSaved: (value) => _siteDetail.geolocationInfo = value,
                      onChanged: (value) => _siteDetail.geolocationInfo = value,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Site Configuration Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: Color(0xFF006064), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.settings, color: Color(0xFF006064)),
                        SizedBox(width: 8),
                        Text(
                          'Site Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF006064), height: 20),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: _siteDetail.mannedUnmanned,
                      decoration: InputDecoration(
                        labelText: 'Site Type',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'Select manned or unmanned',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.people,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                      ),
                      items:
                          ['Manned', 'Unmanned']
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type,
                                    style: const TextStyle(
                                      color: Color(0xFF006064),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setState(
                            () => _siteDetail.mannedUnmanned = value,
                          ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Fuel Supply Source',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'Name of terminal/supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.local_gas_station,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                      ),
                      onSaved:
                          (value) => _siteDetail.fuelSupplyTerminalName = value,
                      onChanged:
                          (value) => _siteDetail.fuelSupplyTerminalName = value,
                      initialValue: _siteDetail.fuelSupplyTerminalName,
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _siteDetail.brandOfFuelsSold,
                      decoration: InputDecoration(
                        labelText: 'Fuel Types Sold',
                        labelStyle: const TextStyle(color: Colors.blueGrey),
                        hintText: 'Select fuel types',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF006064)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF006064),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                        prefixIcon: const Icon(
                          Icons.local_offer,
                          color: Color(0xFF006064),
                          size: 20,
                        ),
                      ),
                      items:
                          ['AGO', 'MGR', 'KERO']
                              .map(
                                (fuel) => DropdownMenuItem(
                                  value: fuel,
                                  child: Text(
                                    fuel,
                                    style: const TextStyle(
                                      color: Color(0xFF006064),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setState(
                            () => _siteDetail.brandOfFuelsSold = value,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Contacts Card with validation
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(
                  color: _contacts.isEmpty ? Colors.orange : Color(0xFF006064),
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.contacts, color: Color(0xFF006064)),
                          const SizedBox(width: 8),
                          const Text(
                            'Contact Persons',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Color(0xFF006064),
                              size: 28,
                            ),
                            onPressed: _addContact,
                            tooltip: 'Add new contact',
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF006064), height: 20),
                      const SizedBox(height: 10),
                      ..._buildContactsList(),
                      const SizedBox(height: 10),
                      if (_contacts.isNotEmpty)
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Another Contact'),
                            onPressed: _addContact,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Color(0xFF006064),
                            ),
                          ),
                        ),
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

  List<Widget> _buildContactsList() {
    return _contacts.asMap().entries.map((entry) {
      final index = entry.key;
      final contact = entry.value;
      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF006064), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contact ${index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteConfirmationDialog(index),
                    tooltip: 'Remove contact',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Contact Name *',
                  labelStyle: const TextStyle(color: Colors.blueGrey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF006064), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.blueGrey[50],
                  prefixIcon: const Icon(
                    Icons.person,
                    size: 20,
                    color: Color(0xFF006064),
                  ),
                ),
                initialValue: contact.contactName,
                validator:
                    (value) =>
                        value?.isEmpty ?? true ? 'Name is required' : null,
                onChanged: (value) => contact.contactName = value,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: contact.role,
                decoration: InputDecoration(
                  labelText: 'Role *',
                  labelStyle: const TextStyle(color: Colors.blueGrey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF006064), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.blueGrey[50],
                  prefixIcon: const Icon(
                    Icons.work,
                    size: 20,
                    color: Color(0xFF006064),
                  ),
                ),
                items:
                    ['Area Contact', 'Site Contact']
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(
                              role,
                              style: const TextStyle(color: Colors.blueGrey),
                            ),
                          ),
                        )
                        .toList(),
                validator: (value) => value == null ? 'Role is required' : null,
                onChanged: (value) => setState(() => contact.role = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  labelStyle: const TextStyle(color: Colors.blueGrey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF006064), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.blueGrey[50],
                  prefixIcon: const Icon(
                    Icons.phone,
                    size: 20,
                    color: Color(0xFF006064),
                  ),
                ),
                initialValue: contact.phoneNumber,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Phone is required';
                  if (!RegExp(r'^[0-9+]+$').hasMatch(value!)) {
                    return 'Enter valid phone number';
                  }
                  return null;
                },
                onChanged: (value) => contact.phoneNumber = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(color: Colors.blueGrey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF006064), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.blueGrey[50],
                  prefixIcon: const Icon(
                    Icons.email,
                    size: 20,
                    color: Color(0xFF006064),
                  ),
                ),
                initialValue: contact.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isNotEmpty ?? false) {
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value!)) {
                      return 'Enter valid email';
                    }
                  }
                  return null;
                },
                onChanged: (value) => contact.email = value,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showDeleteConfirmationDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this contact?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Color(0xFF006064)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteContact(index);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      },
    );
  }

  void _deleteContact(int index) {
    setState(() {
      if (_contacts.length > 1) {
        _contacts.removeAt(index);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact deleted'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one contact is required'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  void _addContact() {
    setState(() {
      _contacts.add(Contact());
    });
  }

  Widget _buildEquipmentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(1)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.build, color: Color(0xFF006064)),
                  const SizedBox(width: 10),
                  const Text(
                    'Equipment Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // FCC Section
            _buildSectionHeader('FCC Equipment'),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'FCC Type and Model *',
                prefixIcon: const Icon(Icons.memory, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF006064), width: 2),
                ),
                filled: true,
                fillColor: Colors.blueGrey[50],
              ),

              onSaved: (value) => _equipmentInfo.fccModel = value,
              onChanged: (value) => _equipmentInfo.fccModel = value,
              initialValue: _equipmentInfo.fccModel,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'FCC Location *',
                prefixIcon: const Icon(Icons.location_on, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF006064), width: 2),
                ),
                filled: true,
                fillColor: Colors.blueGrey[50],
              ),

              onSaved: (value) => _equipmentInfo.fccLocations = value,
              onChanged: (value) => _equipmentInfo.fccLocations = value,
              initialValue: _equipmentInfo.fccLocations,
            ),
            const SizedBox(height: 20),

            // ATG Section
            _buildSectionHeader('ATG Equipment'),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'ATG Type and Model *',
                prefixIcon: const Icon(Icons.storage, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF006064), width: 2),
                ),
                filled: true,
                fillColor: Colors.blueGrey[50],
              ),

              onSaved: (value) => _equipmentInfo.atgModel = value,
              onChanged: (value) => _equipmentInfo.atgModel = value,
              initialValue: _equipmentInfo.atgModel,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'ATG Location *',
                prefixIcon: const Icon(Icons.location_on, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF006064), width: 2),
                ),
                filled: true,
                fillColor: Colors.blueGrey[50],
              ),

              onSaved: (value) => _equipmentInfo.atgLocation = value,
              onChanged: (value) => _equipmentInfo.atgLocation = value,
              initialValue: _equipmentInfo.atgLocation,
            ),
            const SizedBox(height: 20),

            // Printer Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color:
                      _equipmentInfo.printerRequired ?? false
                          ? Colors.green.shade600
                          : Color(0xFF006064),
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  'Requires printer for FCC/ATG Console?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        _equipmentInfo.printerRequired ?? false
                            ? Colors.green.shade800
                            : Color(0xFF006064),
                  ),
                ),
                value: _equipmentInfo.printerRequired ?? false,
                onChanged:
                    (value) =>
                        setState(() => _equipmentInfo.printerRequired = value),
                secondary: Icon(
                  Icons.print,
                  color:
                      _equipmentInfo.printerRequired ?? false
                          ? Colors.green.shade600
                          : Colors.grey.shade600,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF006064),
        ),
      ),
    );
  }

  Widget _buildPowerConfigStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(2)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.power, color: Color(0xFF006064), size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Power Supply & Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Grounding Value Field
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Station Grounding Value',
                prefixIcon: const Icon(Icons.electrical_services, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF006064)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF006064)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF00838F),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.teal[50],
              ),
              onSaved: (value) => _powerConfig.groundingValue = value,
              onChanged: (value) => _powerConfig.groundingValue = value,
              initialValue: _powerConfig.groundingValue,
            ),
            const SizedBox(height: 28),

            // Power Checklist Section
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'Power Checklist',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006064),
                ),
              ),
            ),

            // Checklist Items
            _buildPowerChecklistItem(
              title: 'Mains power outlets (220V) within 1m of FCC/ATG',
              value: _powerConfig.mainPowerFccAtg ?? false,
              onChanged:
                  (value) =>
                      setState(() => _powerConfig.mainPowerFccAtg = value),
              icon: Icons.power,
            ),

            _buildPowerChecklistItem(
              title:
                  'Mains power outlets (220V) within 1m of Fusion Wireless Gateway',
              value: _powerConfig.mainPowerFusionWirelessGateway ?? false,
              onChanged:
                  (value) => setState(
                    () => _powerConfig.mainPowerFusionWirelessGateway = value,
                  ),
              icon: Icons.power,
            ),

            _buildPowerChecklistItem(
              title: 'FCC/ATG power supply protection via UPS available',
              value: _powerConfig.upsForFccAtg ?? false,
              onChanged:
                  (value) => setState(() => _powerConfig.upsForFccAtg = value),
              icon: Icons.battery_charging_full,
            ),

            _buildPowerChecklistItem(
              title: 'Dispenser power supply protection via UPS available',
              value: _powerConfig.upsDispenser ?? false,
              onChanged:
                  (value) => setState(() => _powerConfig.upsDispenser = value),
              icon: Icons.battery_charging_full,
            ),

            _buildPowerChecklistItem(
              title:
                  'Mains power outlets (220V) at Dispenser for Dispenser Wireless Gateway',
              value: _powerConfig.mainPowerDispenserWirelessGateway ?? false,
              onChanged:
                  (value) => setState(
                    () =>
                        _powerConfig.mainPowerDispenserWirelessGateway = value,
                  ),
              icon: Icons.power,
            ),

            _buildPowerChecklistItem(
              title: 'Separation of data and power cable conduits in place',
              value: _powerConfig.separationOfDataCable ?? false,
              onChanged:
                  (value) => setState(
                    () => _powerConfig.separationOfDataCable = value,
                  ),
              icon: Icons.cable,
            ),

            _buildPowerChecklistItem(
              title: 'Availability of data conduit from Pumps to FCC room',
              value: _powerConfig.availabilityDataPumpToFcc ?? false,
              onChanged:
                  (value) => setState(
                    () => _powerConfig.availabilityDataPumpToFcc = value,
                  ),
              icon: Icons.router,
            ),

            _buildPowerChecklistItem(
              title:
                  'Conduit/Cable gland for Dispenser Wireless Gateway communication cable',
              value: _powerConfig.conduitCableInstall ?? false,
              onChanged:
                  (value) =>
                      setState(() => _powerConfig.conduitCableInstall = value),
              icon: Icons.settings_ethernet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerChecklistItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: value ? Colors.green.shade300 : Color(0xFF006064),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: value ? Colors.green.shade800 : Color(0xFF006064),
          ),
        ),
        value: value,
        onChanged: onChanged,
        secondary: Icon(
          icon,
          color: value ? Colors.green.shade600 : Colors.grey.shade600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        activeColor: Colors.green.shade600,
      ),
    );
  }

  Widget _buildNetworkConfigStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(3)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.wifi, color: Color(0xFF006064), size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Internet & Network Setup',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Main Connectivity Section
            _buildNetworkSectionHeader('Broadband Connection'),
            _buildNetworkSwitchItem(
              title: 'Does the site have a broadband connection?',
              value: _networkConfig.hasBroadband ?? false,
              onChanged:
                  (value) =>
                      setState(() => _networkConfig.hasBroadband = value),
              icon: Icons.network_wifi,
            ),
            const SizedBox(height: 20),

            // Network Details Section
            _buildNetworkSectionHeader('Network Configuration'),
            _buildNetworkSwitchItem(
              title: 'Are there free network ports on the broadband router?',
              value: _networkConfig.freePort ?? false,
              onChanged:
                  (value) => setState(() => _networkConfig.freePort = value),
              icon: Icons.lan_outlined,
            ),

            _buildNetworkSwitchItem(
              title: 'Is the network managed by a third party?',
              value: _networkConfig.managedByThird ?? false,
              onChanged: (value) {
                setState(() {
                  _networkConfig.managedByThird = value;
                  if (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'If managed by a third party, you may need to contact them for configuration details.',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Color(0xFF006064),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                });
              },
              icon: Icons.groups_outlined,
            ),

            _buildNetworkSwitchItem(
              title: 'Are ports specifically allocated for use by the FCC/ATG?',
              value: _networkConfig.portAllocatedFccAtg ?? false,
              onChanged:
                  (value) => setState(
                    () => _networkConfig.portAllocatedFccAtg = value,
                  ),
              icon: Icons.portable_wifi_off_outlined,
            ),

            _buildNetworkSwitchItem(
              title:
                  'Does the site network prevent remote access via TeamViewer?',
              value: _networkConfig.teamviewerBlocked ?? false,
              onChanged:
                  (value) =>
                      setState(() => _networkConfig.teamviewerBlocked = value),
              icon: Icons.settings_remote_outlined,
              isWarning: _networkConfig.teamviewerBlocked ?? false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF006064),
        ),
      ),
    );
  }

  Widget _buildNetworkSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool isWarning = false,
  }) {
    final activeColor =
        isWarning ? Colors.orange.shade700 : Colors.green.shade600;
    final activeTextColor =
        isWarning ? Colors.orange.shade800 : Colors.green.shade800;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: value ? activeColor : Color(0xFF006064)),
      ),

      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: value ? activeTextColor : Color(0xFF006064),
          ),
        ),
        value: value,
        onChanged: onChanged,
        secondary: Icon(
          icon,
          color: value ? activeColor : Colors.grey.shade600,
          size: 24,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        activeColor: activeColor,
      ),
    );
  }

  Widget _buildTankConfigStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(4)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF006064), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storage,
                          color: Color(0xFF006064),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Tank Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Color(0xFF006064),
                            size: 28,
                          ),
                          onPressed: _addTank,
                          tooltip: 'Add Tank',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildTanksList(),
            const SizedBox(height: 10),
            if (_tanks.isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Another Tank'),
                  onPressed: _addTank,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFF006064),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTanksList() {
    return _tanks.asMap().entries.map((entry) {
      final index = entry.key;
      final tank = entry.value;
      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF006064), width: 1),
        ),
        child: ExpansionTile(
          title: Text(
            'Tank ${tank.tankNumber ?? "New"}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: const Icon(Icons.storage, color: Color(0xFF006064)),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteTankDialog(index),
            tooltip: 'Delete Tank',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildTankInputField(
                    label: 'Tank Number *',
                    value: tank.tankNumber?.toString(),
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => tank.tankNumber = int.tryParse(value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tank.gradesInfo,
                    decoration: _buildInputDecoration(
                      label: 'Fuel Grade *',
                      icon: Icons.local_gas_station,
                    ),
                    items:
                        [
                              'MGR(Gasoline)',
                              'AGO(Diesel)',
                              'Kero(Kereonse)',
                              'JETA1',
                            ]
                            .map(
                              (grade) => DropdownMenuItem(
                                value: grade,
                                child: Text(grade),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() => tank.gradesInfo = value),
                  ),
                  const SizedBox(height: 12),
                  _buildTankInputField(
                    label: 'Safe Working Capacity (Liters)',
                    value: tank.capacity?.toString(),
                    icon: Icons.straighten,
                    keyboardType: TextInputType.number,
                    onChanged:
                        (value) => tank.capacity = double.tryParse(value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<double>(
                    value: tank.tankEntryDiameter,
                    decoration: _buildInputDecoration(
                      label: 'Tank Entry for Probes (inch)',
                      icon: Icons.straighten,
                    ),
                    items:
                        [2.0, 3.0, 4.0]
                            .map(
                              (size) => DropdownMenuItem(
                                value: size,
                                child: Text('$size"'),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) =>
                            setState(() => tank.tankEntryDiameter = value),
                  ),
                  const SizedBox(height: 12),
                  _buildTankInputField(
                    label: 'Cable Length to Kiosk (m)',
                    value: tank.probeCableLengthToKiosk?.toString(),
                    icon: Icons.cable,
                    keyboardType: TextInputType.number,
                    onChanged:
                        (value) =>
                            tank.probeCableLengthToKiosk = double.tryParse(
                              value,
                            ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tank.pressureOrSuction,
                    decoration: _buildInputDecoration(
                      label: 'Pressure/Suction',
                      icon: Icons.compress,
                    ),
                    items:
                        ['Pressure', 'Suction']
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) =>
                            setState(() => tank.pressureOrSuction = value),
                  ),
                  const SizedBox(height: 12),
                  _buildTankInputField(
                    label: 'Tank Age (Days)',
                    value: tank.fuelAgeDays?.toString(),
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                    onChanged:
                        (value) => tank.fuelAgeDays = double.tryParse(value),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Tank Measurements',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildTankInputField(
                    label: 'Tank Diameter (A) (m)',
                    value: tank.diameterA?.toString(),
                    icon: Icons.straighten,
                    keyboardType: TextInputType.number,
                    onChanged:
                        (value) => tank.diameterA = double.tryParse(value),
                  ),
                  const SizedBox(height: 12),
                  _buildTankInputField(
                    label: 'Manhole Depth (B) (m)',
                    value: tank.manholeDepthB?.toString(),
                    icon: Icons.height,
                    keyboardType: TextInputType.number,
                    onChanged:
                        (value) => tank.manholeDepthB = double.tryParse(value),
                  ),
                  const SizedBox(height: 12),
                  _buildTankInputField(
                    label: 'Probe Length (m)',
                    value: tank.probeLength?.toString(),
                    icon: Icons.straighten,
                    keyboardType: TextInputType.number,
                    onChanged:
                        (value) => tank.probeLength = double.tryParse(value),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Tank Features',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildTankSwitchItem(
                    title: 'Double Walled',
                    value: tank.doubleWalled ?? false,
                    onChanged:
                        (value) => setState(() => tank.doubleWalled = value),
                    icon: Icons.layers,
                  ),
                  _buildTankSwitchItem(
                    title: 'Siphoned',
                    value: tank.siphonedInfo ?? false,
                    onChanged: (value) {
                      setState(() {
                        tank.siphonedInfo = value;
                        if (!value) tank.siphonedFromTankIds = null;
                      });
                    },
                    icon: Icons.compare_arrows,
                  ),
                  if (tank.siphonedInfo ?? false) ...[
                    const SizedBox(height: 8),
                    _buildTankInputField(
                      label: 'Siphoned From Tank IDs',
                      value: tank.siphonedFromTankIds,
                      icon: Icons.link,
                      onChanged: (value) => tank.siphonedFromTankIds = value,
                    ),
                  ],
                  _buildTankSwitchItem(
                    title: 'Tank Chart Available',
                    value: tank.tankChartAvailable ?? false,
                    onChanged:
                        (value) =>
                            setState(() => tank.tankChartAvailable = value),
                    icon: Icons.insert_chart,
                  ),
                  _buildTankSwitchItem(
                    title: 'Dipstick Available',
                    value: tank.dipStickAvailable ?? false,
                    onChanged:
                        (value) =>
                            setState(() => tank.dipStickAvailable = value),
                    icon: Icons.rule,
                  ),
                  _buildTankSwitchItem(
                    title: 'Manhole Cover Metal',
                    value: tank.manholeCoverMetal ?? false,
                    onChanged:
                        (value) =>
                            setState(() => tank.manholeCoverMetal = value),
                    icon: Icons.construction,
                  ),
                  _buildTankSwitchItem(
                    title: 'Manhole Wall Metal',
                    value: tank.manholeWallMetal ?? false,
                    onChanged:
                        (value) =>
                            setState(() => tank.manholeWallMetal = value),
                    icon: Icons.construction,
                  ),
                  _buildTankSwitchItem(
                    title: 'Remote Antenna Required',
                    value: tank.remoteAntennaRequired ?? false,
                    onChanged:
                        (value) =>
                            setState(() => tank.remoteAntennaRequired = value),
                    icon: Icons.settings_remote,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Helper Widgets
  Widget _buildTankInputField({
    required String label,
    required String? value,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF006064)),
        ),
        filled: true,
        fillColor: Colors.blueGrey[50],
      ),
      initialValue: value,
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF006064)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF006064)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF006064), width: 2),
      ),
      filled: true,
      fillColor: Colors.blueGrey[50],
    );
  }

  Widget _buildTankSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: value ? Colors.green.shade300 : Color(0xFF006064),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: value ? Colors.green.shade800 : Color(0xFF006064),
          ),
        ),
        value: value,
        onChanged: onChanged,
        secondary: Icon(
          icon,
          color: value ? Colors.green.shade600 : Color(0xFF006064),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        activeColor: Colors.green.shade600,
      ),
    );
  }

  void _showDeleteTankDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Tank"),
          content: const Text(
            "Are you sure you want to delete this tank configuration?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _tanks.removeAt(index));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tank configuration deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Color(0xFF006064)),
          ),
        );
      },
    );
  }

  void _addTank() {
    setState(() {
      _tanks.add(TankConfig()..tankNumber = (_tanks.length + 1));
    });
  }

  Widget _buildPumpConfigStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(5)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF006064), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_gas_station,
                          color: Color(0xFF006064),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Pump Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Color(0xFF006064),
                            size: 28,
                          ),
                          onPressed: _addPump,
                          tooltip: 'Add Pump',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildPumpsList(),
            if (_pumps.isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Another Pump'),
                  onPressed: _addPump,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFF006064),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPumpsList() {
    return _pumps.asMap().entries.map((entry) {
      final index = entry.key;
      final pump = entry.value;
      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.blueGrey, width: 1),
        ),
        child: ExpansionTile(
          title: Text(
            'Pump ${pump.pumpNumber ?? "New"}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: const Icon(Icons.local_gas_station, color: Colors.blueGrey),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeletePumpDialog(index),
            tooltip: 'Delete Pump',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildPumpInputField(
                    label: 'Pump Number *',
                    value: pump.pumpNumber?.toString(),
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => pump.pumpNumber = int.tryParse(value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: pump.brandInfo,
                    decoration: InputDecoration(
                      labelText: 'Brand *',
                      labelStyle: const TextStyle(color: Colors.blueGrey),
                      hintText: 'Select one brand type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF006064)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0xFF006064),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.blueGrey[50],
                      prefixIcon: const Icon(
                        Icons.branding_watermark,
                        color: Color(0xFF006064),
                        size: 20,
                      ),
                    ),

                    items:
                        [
                              'Wayne',
                              'Gilbarco',
                              'Tokhiem',
                              'Spyrides',
                              'Petrotech',
                              'Mepsan',
                              'ZCHENG',
                              'Eagle star',
                            ]
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type,
                                  style: const TextStyle(
                                    color: Color(0xFF006064),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() => pump.brandInfo = value),
                  ),
                  const SizedBox(height: 12),
                  _buildPumpInputField(
                    label: 'Model',
                    value: pump.modelInfo,
                    icon: Icons.model_training,
                    onChanged: (value) => pump.modelInfo = value,
                  ),
                  const SizedBox(height: 12),
                  _buildPumpInputField(
                    label: 'Serial Number',
                    value: pump.serialNumber,
                    icon: Icons.confirmation_number,
                    onChanged: (value) => pump.serialNumber = value,
                  ),
                  const SizedBox(height: 12),
                  _buildPumpInputField(
                    label: 'CPU/Firmware',
                    value: pump.cpuFirmwaresInfo,
                    icon: Icons.memory,
                    onChanged: (value) => pump.cpuFirmwaresInfo = value,
                  ),
                  const SizedBox(height: 12),
                  _buildPumpInputField(
                    label: 'Protocol',
                    value: pump.protocolInfo,
                    icon: Icons.settings_input_component,
                    onChanged: (value) => pump.protocolInfo = value,
                  ),
                  const SizedBox(height: 12),
                  _buildPumpInputField(
                    label: 'Nozzles Count',
                    value: pump.nozzlesInfo?.toString(),
                    icon: Icons.format_list_numbered,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => pump.nozzlesInfo = value,
                  ),
                  const SizedBox(height: 12),
                  _buildPumpInputField(
                    label: 'Pump Address',
                    value: pump.pumpAddressInfo,
                    icon: Icons.numbers,
                    onChanged: (value) => pump.pumpAddressInfo = value,
                  ),
                  const SizedBox(height: 12),
                  _buildPumpInputField(
                    label: 'Cable Length to FCC (m)',
                    value: pump.cableLengthToFcc?.toString(),
                    icon: Icons.cable,
                    keyboardType: TextInputType.number,
                    onChanged:
                        (value) =>
                            pump.cableLengthToFcc = double.tryParse(value),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Helper Widgets
  Widget _buildPumpInputField({
    required String label,
    required String? value,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF006064)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF006064)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF006064), width: 2),
        ),
        filled: true,
        fillColor: Colors.blueGrey[50],
      ),
      initialValue: value,
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }

  InputDecoration _buildPumpInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.blueGrey[50],
    );
  }

  void _showDeletePumpDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Pump"),
          content: const Text(
            "Are you sure you want to delete this pump configuration?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _pumps.removeAt(index));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pump configuration deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  void _addPump() {
    setState(() {
      _pumps.add(Pump()..pumpNumber = (_pumps.length + 1));
    });
  }

  Widget _buildNozzleConfigStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(6)
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_gas_station,
                          color: Color(0xFF006064),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Nozzle Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const Spacer(),
                        if (_pumps.isNotEmpty)
                          IconButton.filledTonal(
                            icon: const Icon(Icons.autorenew),
                            onPressed: _generateNozzlesFromPumps,
                            tooltip: 'Generate Nozzles from Pumps',
                            style: IconButton.styleFrom(
                              backgroundColor: Color(0xFF006064),
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_nozzles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 48,
                              color: Colors.amber.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _pumps.isEmpty
                                  ? 'Please configure pumps first'
                                  : 'No nozzles configured yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_pumps.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Nozzles will be automatically generated based on the nozzle counts specified in the pump configuration.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _generateNozzlesFromPumps,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Generate Nozzles Now'),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      ..._buildNozzlesList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNozzlesList() {
    // Group nozzles by pump
    final Map<int?, List<Nozzle>> nozzlesByPump = {};
    for (final nozzle in _nozzles) {
      nozzlesByPump.putIfAbsent(nozzle.pumpId, () => []).add(nozzle);
    }

    return [
      // List of nozzles grouped by pump
      ...nozzlesByPump.entries.map((entry) {
        final pumpId = entry.key;
        final pumpNozzles = entry.value;

        // Find the pump details
        final pump = _pumps.firstWhere(
          (p) => p.pumpNumber == pumpId,
          orElse: () => Pump(),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pump header
            if (pumpId != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.local_gas_station, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pump ${pump.pumpNumber} - ${pump.brandInfo} ${pump.modelInfo}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF006064),
                        ),
                      ),
                    ),
                    Text(
                      '${pumpNozzles.length} nozzle${pumpNozzles.length > 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Divider(),
            ],

            // Nozzles for this pump
            ...pumpNozzles.map((nozzle) {
              final index = _nozzles.indexOf(nozzle);
              final currentTank =
                  nozzle.tankId != null
                      ? _tanks.firstWhere(
                        (t) => t.tankNumber == nozzle.tankId,
                        orElse: () => TankConfig(),
                      )
                      : null;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(top: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.oil_barrel, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Nozzle ${nozzle.nozzleNumbers}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grade selection
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: nozzle.gradeInfo,
                        decoration: InputDecoration(
                          labelText: 'Fuel Grade',
                          labelStyle: const TextStyle(color: Color(0xFF006064)),
                          hintText: 'Select one fuel grade',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF006064)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF006064),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.blueGrey[50],
                          prefixIcon: const Icon(
                            Icons.water_drop_outlined,
                            color: Color(0xFF006064),
                            size: 20,
                          ),
                        ),

                        items:
                            [
                                  'MGR(Gasoline)',
                                  'AGO(Diesel)',
                                  'Kero(Kereonse)',
                                  'JETA1',
                                ]
                                .map(
                                  (grade) => DropdownMenuItem(
                                    value: grade,
                                    child: Text(
                                      grade,
                                      style: const TextStyle(
                                        color: Color(0xFF006064),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) => setState(() => nozzle.gradeInfo = value),
                      ),

                      const SizedBox(height: 12),

                      // Tank selection
                      DropdownButtonFormField<TankConfig>(
                        value: currentTank,
                        decoration: InputDecoration(
                          labelText: 'Assigned Tank',
                          labelStyle: const TextStyle(color: Colors.blueGrey),
                          hintText: 'Select one Tank',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF006064)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF006064),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.blueGrey[50],
                          prefixIcon: const Icon(
                            Icons.local_gas_station_outlined,
                            color: Color(0xFF006064),
                            size: 20,
                          ),
                        ),

                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text(
                              'Select Tank...',
                              style: TextStyle(color: Color(0xFF006064)),
                            ),
                          ),
                          ..._tanks.map(
                            (tank) => DropdownMenuItem(
                              value: tank,
                              child: Text(
                                'Tank ${tank.tankNumber} - ${tank.gradesInfo}',
                                style: TextStyle(color: Color(0xFF006064)),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (selectedTank) {
                          setState(() {
                            nozzle.tankId = selectedTank?.tankNumber;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }),

      // Show unassigned nozzles (if any)
      if (nozzlesByPump.containsKey(null)) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Unassigned Nozzles',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('${nozzlesByPump[null]!.length}'),
                backgroundColor: Colors.amber.shade100,
              ),
            ],
          ),
        ),
        const Divider(),
        ...nozzlesByPump[null]!.map((nozzle) {
          final index = _nozzles.indexOf(nozzle);
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(top: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.oil_barrel, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Nozzle ${nozzle.nozzleNumbers ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This nozzle is not assigned to any pump',
                    style: TextStyle(color: Colors.amber.shade800),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    ];
  }

  void _generateNozzlesFromPumps() {
    setState(() {
      _nozzles.clear();

      for (final pump in _pumps) {
        if (pump.pumpNumber == null) continue;

        final nozzleCount =
            pump.nozzlesInfo != null ? int.tryParse(pump.nozzlesInfo!) ?? 0 : 0;

        for (int i = 1; i <= nozzleCount; i++) {
          final nozzle =
              Nozzle()
                ..pumpId = pump.pumpNumber
                ..nozzleNumbers = i
                ..gradeInfo = null
                ..tankId = null;

          _nozzles.add(nozzle);
        }
      }

      if (_nozzles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _pumps.isEmpty
                  ? 'No pumps configured - please add pumps first'
                  : 'No nozzles generated - check pump nozzle counts',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Generated ${_nozzles.length} nozzle${_nozzles.length > 1 ? 's' : ''}',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    });
  }

  Widget _buildNotesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(7)
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notes, color: Color(0xFF006064)),
                        const SizedBox(width: 8),
                        const Text(
                          'Site Review Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          onPressed: _addNote,
                          tooltip: 'Add New Note',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                          ),
                        ),
                      ],
                    ),
                    if (_notes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No notes added yet',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: _addNote,
                              child: const Text('Add First Note'),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._buildNotesList(),
                    if (_notes.isNotEmpty)
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Another Note'),
                          onPressed: _addNote,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Color(0xFF006064),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNotesList() {
    return _notes.asMap().entries.map((entry) {
      final index = entry.key;
      final note = entry.value;

      return Card(
        elevation: 1,
        margin: const EdgeInsets.only(top: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Note #${index + 1}',
                  labelStyle: TextStyle(
                    color: Color(0xFF006064),
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF006064)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF006064)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF006064)),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: const Icon(Icons.short_text, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _deleteNote(index),
                    tooltip: 'Remove Note',
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                maxLines: 5,
                minLines: 3,
                keyboardType: TextInputType.multiline,
                initialValue: note.commentInfo,
                onChanged: (value) => note.commentInfo = value,
              ),
              if (note.commentInfo?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${note.commentInfo?.length ?? 0} characters',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _deleteNote(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Note"),
          content: const Text("Are you sure you want to delete this note?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _notes.removeAt(index);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Note deleted"),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  void _addNote() {
    setState(() {
      _notes.add(ReviewComment());
    });
  }

  Widget _buildConfirmationStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(8)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review Your Configuration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006064),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(height: 8),
                  Text(
                    'Please carefully review all the information entered in the previous steps before saving.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Edits can be made by navigating back using the "Previous" button.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Site Details
            _buildConfirmationSection(
              title: 'Site Details & Location',
              icon: Icons.business,
              children: [
                _buildConfirmationItem('Company Name', _siteDetail.companyName),
                _buildConfirmationItem('Site Name', _siteDetail.siteName),
                _buildConfirmationItem('Address', _siteDetail.addressInfo),
                _buildConfirmationItem(
                  'Location',
                  '${_siteDetail.townInfo ?? ''}${_siteDetail.townInfo != null && _siteDetail.cityInfo != null ? ', ' : ''}'
                      '${_siteDetail.cityInfo ?? ''}${_siteDetail.cityInfo != null && _siteDetail.countryInfo != null ? ', ' : ''}'
                      '${_siteDetail.countryInfo ?? ''}',
                ),
                _buildConfirmationItem(
                  'Geo-Location',
                  _siteDetail.geolocationInfo,
                ),
                _buildConfirmationItem('Site Type', _siteDetail.mannedUnmanned),
                _buildConfirmationItem(
                  'Fuel Supply/Terminal',
                  _siteDetail.fuelSupplyTerminalName,
                ),
                _buildConfirmationItem(
                  'Fuel Brands',
                  _siteDetail.brandOfFuelsSold,
                ),
              ],
            ),

            // Equipment
            _buildConfirmationSection(
              title: 'Equipment',
              icon: Icons.build,
              children: [
                _buildConfirmationItem('FCC Model', _equipmentInfo.fccModel),
                _buildConfirmationItem(
                  'FCC Location',
                  _equipmentInfo.fccLocations,
                ),
                _buildConfirmationItem('ATG Model', _equipmentInfo.atgModel),
                _buildConfirmationItem(
                  'ATG Location',
                  _equipmentInfo.atgLocation,
                ),
                _buildConfirmationItem(
                  'Printer Required',
                  _equipmentInfo.printerRequired == true ? 'Yes' : 'No',
                ),
              ],
            ),

            // Power & Networking
            _buildConfirmationSection(
              title: 'Power & Networking',
              icon: Icons.power,
              children: [
                _buildConfirmationItem(
                  'Grounding Value',
                  _powerConfig.groundingValue,
                ),
                _buildConfirmationChecklistItem(
                  'Mains near FCC/ATG',
                  _powerConfig.mainPowerFccAtg,
                ),
                _buildConfirmationChecklistItem(
                  'Mains near Fusion Gateway',
                  _powerConfig.mainPowerFusionWirelessGateway,
                ),
                _buildConfirmationChecklistItem(
                  'UPS for FCC/ATG',
                  _powerConfig.upsForFccAtg,
                ),
                _buildConfirmationChecklistItem(
                  'UPS for Dispenser',
                  _powerConfig.upsDispenser,
                ),
                _buildConfirmationChecklistItem(
                  'Data/Power Separation',
                  _powerConfig.separationOfDataCable,
                ),
                _buildConfirmationChecklistItem(
                  'Broadband Available',
                  _networkConfig.hasBroadband,
                ),
                _buildConfirmationChecklistItem(
                  'Free Router Ports',
                  _networkConfig.freePort,
                ),
                _buildConfirmationChecklistItem(
                  'Managed by Third Party',
                  _networkConfig.managedByThird,
                ),
              ],
            ),

            // Contacts
            _buildConfirmationSection(
              title: 'Contacts (${_contacts.length})',
              icon: Icons.people,
              children:
                  _contacts
                      .map(
                        (contact) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildConfirmationItem('Name', contact.contactName),
                            _buildConfirmationItem('Role', contact.role),
                            _buildConfirmationItem(
                              'Phone',
                              contact.phoneNumber,
                            ),
                            _buildConfirmationItem('Email', contact.email),
                            const Divider(),
                          ],
                        ),
                      )
                      .toList(),
            ),

            // Tanks
            _buildConfirmationSection(
              title: 'Tanks (${_tanks.length})',
              icon: Icons.storage,
              children:
                  _tanks
                      .map(
                        (tank) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildConfirmationItem(
                              'Tank Number',
                              tank.tankNumber?.toString(),
                            ),
                            _buildConfirmationItem(
                              'Fuel Grade',
                              tank.gradesInfo,
                            ),
                            _buildConfirmationItem(
                              'Capacity',
                              tank.capacity?.toString(),
                            ),
                            _buildConfirmationItem(
                              'Double Walled',
                              tank.doubleWalled == true ? 'Yes' : 'No',
                            ),
                            _buildConfirmationItem(
                              'Pressure/Suction',
                              tank.pressureOrSuction,
                            ),
                            const Divider(),
                          ],
                        ),
                      )
                      .toList(),
            ),

            // Pumps
            _buildConfirmationSection(
              title: 'Pumps (${_pumps.length})',
              icon: Icons.local_gas_station,
              children:
                  _pumps
                      .map(
                        (pump) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildConfirmationItem(
                              'Pump Number',
                              pump.pumpNumber?.toString(),
                            ),
                            _buildConfirmationItem('Brand', pump.brandInfo),
                            _buildConfirmationItem('Model', pump.modelInfo),
                            _buildConfirmationItem(
                              'Nozzles',
                              pump.nozzlesInfo?.toString(),
                            ),
                            const Divider(),
                          ],
                        ),
                      )
                      .toList(),
            ),

            // Nozzles
            _buildConfirmationSection(
              title: 'Nozzles (${_nozzles.length})',
              icon: Icons.local_gas_station_outlined,
              children:
                  _nozzles
                      .map(
                        (nozzle) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildConfirmationItem(
                              'Pump',
                              nozzle.pumpId?.toString(),
                            ),
                            _buildConfirmationItem(
                              'Nozzle',
                              nozzle.nozzleNumbers?.toString(),
                            ),
                            _buildConfirmationItem('Grade', nozzle.gradeInfo),
                            _buildConfirmationItem(
                              'Tank',
                              nozzle.tankId?.toString(),
                            ),
                            const Divider(),
                          ],
                        ),
                      )
                      .toList(),
            ),

            // Notes
            _buildConfirmationSection(
              title: 'Notes (${_notes.length})',
              icon: Icons.notes,
              children:
                  _notes
                      .map(
                        (note) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildConfirmationItem('Note', note.commentInfo),
                            const Divider(),
                          ],
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      leading: Icon(icon, color: Colors.blue.shade800),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildConfirmationItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? 'Not specified',
              style: TextStyle(
                color: value == null ? Colors.grey : Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationChecklistItem(String label, bool? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value == true ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                value == true ? '✓' : '✗',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  // Step builders will be defined below...
  void _submitForm() {
  bool allValid = true;
  if (_siteDetail.siteName == null || _siteDetail.siteName!.isEmpty) {
    allValid = false;
  }
  if (_equipmentInfo.fccModel == null || _equipmentInfo.fccModel!.isEmpty) {
    allValid = false;
  }

  if (allValid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, color: Colors.amber, size: 48),
            SizedBox(height: 16),
            Text(
              'Are you sure you want to submit this site configuration?',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              _saveData(); // Close the dialog
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              // Show saving indicator
              scaffoldMessenger.showSnackBar(
                 SnackBar(
                  content: Text('Saving site details...'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please complete all required form fields!'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

  // Update the _saveData method to properly handle relationships
  Future<void> _saveData() async {
    // Initialize sync provider for UI feedback
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    syncProvider.startSync('Preparing data...');

    try {
      // Get stored credentials
      final credentials = await _apiService.getStoredCredentials();
      String userId = credentials?['userId'] ?? 'offline-user';

      // Check connectivity
      syncProvider.updateProgress(0.1, 'Checking connectivity...');
      final connectivityResult = await Connectivity().checkConnectivity();
      // ignore: unrelated_type_equality_checks
      final isOnline = connectivityResult != ConnectivityResult.none;

      // If online and no userId, try to authenticate
      if (isOnline && userId == 'offline-user') {
        try {
          syncProvider.updateProgress(0.2, 'Authenticating user...');
          final authResult = await _apiService.authenticateUser(
            credentials!['username']!,
            credentials['password']!,
          );

          if (authResult['success']) {
            userId = authResult['userId'] ?? userId;
          }
        } catch (e) {
          debugPrint('Authentication failed but proceeding offline: $e');
        }
      }

      // Prepare API data with the user ID we have
      final apiData = await _prepareApiData(userId);

      // Check for duplicates if online
      if (isOnline && _siteDetail.siteId != null) {
        syncProvider.updateProgress(0.3, 'Checking for duplicates...');
        final exists = await ApiService().checkSiteExists(_siteDetail.siteId!);
        if (exists && mounted) {
          syncProvider.endSync();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This site already exists on server')),
          );
          return;
        }
      }

      // 3. Save to local database
      syncProvider.updateProgress(0.5, 'Saving to local database...');
      final db = await widget.sitedetaildatabase.dbHelper.database;
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        // Save Site Detail
        if (_siteDetail.id == null) {
          _siteDetail.dateEntry = DateTime.parse(now);
          _siteDetail.id = await txn.insert(
            'site_detail_table',
            _siteDetail.toMap()..['sync_status'] = 0,
          );
        } else {
          _siteDetail.dateUpdated = DateTime.parse(now);
          await txn.update(
            'site_detail_table',
            _siteDetail.toMap()..['sync_status'] = 0,
            where: 'id = ?',
            whereArgs: [_siteDetail.id],
          );
        }

        if (_siteDetail.id == null) {
          throw Exception('Failed to save site details');
        }

        // 2. Save Contacts
        for (final contact in _contacts) {
          contact.siteId = _siteDetail.id;
          if (contact.id == null) {
            contact.dateEntry = DateTime.parse(now);
            contact.id = await txn.insert('contacts_table', contact.toMap());
          } else {
            contact.dateUpdated = DateTime.parse(now);
            await txn.update(
              'contacts_table',
              contact.toMap()..['sync_status'] = 0,
              where: 'id = ?',
              whereArgs: [contact.id],
            );
          }
        }

        // 3. Save Equipment
        _equipmentInfo.siteId = _siteDetail.id;
        if (_equipmentInfo.id == null) {
          _equipmentInfo.dateEntry = DateTime.parse(now);
          _equipmentInfo.id = await txn.insert(
            'site_equipment_table',
            _equipmentInfo.toMap(),
          );
        } else {
          _equipmentInfo.dateUpdated = DateTime.parse(now);
          await txn.update(
            'site_equipment_table',
            _equipmentInfo.toMap()..['sync_status'] = 0,
            where: 'id = ?',
            whereArgs: [_equipmentInfo.id],
          );
        }

        // 4. Save Power Config
        _powerConfig.siteId = _siteDetail.id;
        if (_powerConfig.id == null) {
          _powerConfig.dateEntry = DateTime.parse(now);
          _powerConfig.id = await txn.insert(
            'power_configuration_table',
            _powerConfig.toMap()..['sync_status'] = 0,
          );
        } else {
          _powerConfig.dateUpdatedDate = DateTime.parse(now);
          await txn.update(
            'power_configuration_table',
            _powerConfig.toMap()..['sync_status'] = 0,
            where: 'id = ?',
            whereArgs: [_powerConfig.id],
          );
        }

        // 5. Save Network Config
        _networkConfig.siteId = _siteDetail.id;
        if (_networkConfig.id == null) {
          _networkConfig.dateEntry = DateTime.parse(now);
          _networkConfig.id = await txn.insert(
            'network_config_table',
            _networkConfig.toMap()..['sync_status'] = 0,
          );
        } else {
          _networkConfig.dateUpdated = DateTime.parse(now);
          await txn.update(
            'network_config_table',
            _networkConfig.toMap()..['sync_status'] = 0,
            where: 'id = ?',
            whereArgs: [_networkConfig.id],
          );
        }

        // 6. Save Tanks
        final savedTanks = <TankConfig>[];
        for (final tank in _tanks) {
          tank.siteId = _siteDetail.id;
          if (tank.id == null) {
            tank.dateEnters = DateTime.parse(now);
            tank.id = await txn.insert('tanks_config_table', tank.toMap());
          } else {
            tank.dateUpdated = DateTime.parse(now);
            await txn.update(
              'tanks_config_table',
              tank.toMap()..['sync_status'] = 0,
              where: 'id = ?',
              whereArgs: [tank.id],
            );
          }
          savedTanks.add(tank);
        }

        // 7. Save Pumps
        final savedPumps = <Pump>[];
        for (final pump in _pumps) {
          pump.siteId = _siteDetail.id;
          if (pump.id == null) {
            pump.dateEntry = DateTime.parse(now);
            pump.id = await txn.insert('pump_table', pump.toMap());
          } else {
            pump.dateUpdated = DateTime.parse(now);
            await txn.update(
              'pump_table',
              pump.toMap()..['sync_status'] = 0,
              where: 'id = ?',
              whereArgs: [pump.id],
            );
          }
          savedPumps.add(pump);
        }

        // 8. Save Nozzles
        for (final nozzle in _nozzles) {
          if (nozzle.id == null) {
            nozzle.dateEntry = DateTime.parse(now);
            nozzle.id = await txn.insert('nozzles_table', nozzle.toMap());
          } else {
            nozzle.dateUpdate = DateTime.parse(now);
            await txn.update(
              'nozzles_table',
              nozzle.toMap()..['sync_status'] = 0,
              where: 'id = ?',
              whereArgs: [nozzle.id],
            );
          }
        }

        // 9. Save Notes
        for (final note in _notes) {
          note.siteId = _siteDetail.id;
          if (note.id == null) {
            note.dateEntry = DateTime.parse(now);
            note.id = await txn.insert('review_comment_table', note.toMap());
          } else {
            note.dateUpdated = DateTime.parse(now);
            await txn.update(
              'review_comment_table',
              note.toMap()..['sync_status'] = 0,
              where: 'id = ?',
              whereArgs: [note.id],
            );
          }
        }
      });

      // If online, attempt to sync
      // If you have internet
      if (isOnline) {
        try {
          syncProvider.updateProgress(0.9, 'Saving...');
          final response = await _apiService
              .postSiteDetailsBatch(apiData)
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            await _markAsSynced(db);
            await _syncService.processPendingSyncs(db);
            syncProvider.endSync();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Saved online! All good!')),
              );
              Navigator.of(context).pop(true);
            }
            return;
          }
        } catch (e) {
          debugPrint('Sync failed: $e');
        }
      }

      // If no internet or sync failed
      await _saveForLaterSync(db, apiData);
      syncProvider.endSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 Saved on your device (will send to cloud later)'),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving data: $e');
      debugPrintStack(stackTrace: stackTrace);
      syncProvider.endSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Oops! Something went wrong. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _markAsSynced(Database db) async {
    await db.transaction((txn) async {
      await txn.update(
        'site_detail_table',
        {'sync_status': 1},
        where: 'id = ?',
        whereArgs: [_siteDetail.id],
      );

      // Mark all related tables as synced
      //await _markRelatedAsSynced(txn);
    });
  }

  Future<void> _saveForLaterSync(
    Database db,
    Map<String, dynamic> apiData,
  ) async {
    // First check if this sync is already pending
    final existing = await db.query(
      'pending_syncs',
      where: 'site_id = ? AND endpoint = ?',
      whereArgs: [_siteDetail.id, 'sitedetailtable/batch'],
    );

    if (existing.isEmpty) {
      await db.insert('pending_syncs', {
        'site_id': _siteDetail.id ?? 0,
        'endpoint': 'sitedetailtable/batch',
        'data': jsonEncode(apiData),
        'created_at': DateTime.now().toIso8601String(),
        'last_attempt': null,
        'retry_count': 0,
        'priority': 1,
      });
    }
  }

  // Helper method to process any pending syncs

  Future<Map<String, dynamic>> _prepareApiData(String userId) async {
    // Get stored credentials

    return {
      "siteName": _siteDetail.siteName,
      "siteId": _siteDetail.siteId,
      "addressInfo": _siteDetail.addressInfo,
      "countryInfo": _siteDetail.countryInfo,
      "cityInfo": _siteDetail.cityInfo,
      "towmInfo": _siteDetail.townInfo,
      "geoloactionInfo": _siteDetail.geolocationInfo,
      "mannedUnmanned": _siteDetail.mannedUnmanned,
      "fuelSupplyTerminalName": _siteDetail.fuelSupplyTerminalName,
      "brandOfFuelsSold": _siteDetail.brandOfFuelsSold,
      "companyName": {"id": _selectedCompanyId},
      // Add user ID if you have it
      "usersTable": {
        "id": userId,
      }, // You'll need to replace with actual user ID
      // Contacts
      "contactsTableCollection":
          _contacts
              .map(
                (contact) => {
                  "contactName": contact.contactName,
                  "roleTable": contact.role,
                  "phoneNumber": contact.phoneNumber,
                  "emailAddress": contact.email,
                  "usersTable": {"id": userId}, // Replace with actual user ID
                },
              )
              .toList(),

      // Equipment
      "siteEquipmentTableCollection": [
        {
          "fccModel": _equipmentInfo.fccModel,
          "fccLocations": _equipmentInfo.fccLocations,
          "atgModel": _equipmentInfo.atgModel,
          "atgLocation": _equipmentInfo.atgLocation,
          "printerRequired": _equipmentInfo.printerRequired == true ? "Y" : "N",
          "usersTable": {"id": userId}, // Replace with actual user ID
        },
      ],

      // Power Config
      "powerConfigurationTableCollection": [
        {
          "groundingValue": _powerConfig.groundingValue,
          "mainpowerFCCATG": _powerConfig.mainPowerFccAtg == true ? "Y" : "N",
          "mainPowerFusionWirelessGateway":
              _powerConfig.mainPowerFusionWirelessGateway == true ? "Y" : "N",
          "upsForFccAtg": _powerConfig.upsForFccAtg == true ? "Y" : "N",
          "upsDispenser": _powerConfig.upsDispenser == true ? "Y" : "N",
          "mainPowerDispenserWirelessGateway":
              _powerConfig.mainPowerFusionWirelessGateway == true ? "Y" : "N",
          "separationOfDataCable":
              _powerConfig.separationOfDataCable == true ? "Y" : "N",
          "availablityDataPumpToFcc":
              _powerConfig.availabilityDataPumpToFcc == true ? "Y" : "N",
          "conduitCableInstall":
              _powerConfig.conduitCableInstall == true ? "Y" : "N",
          "usersTable": {"id": userId}, // Replace with actual user ID
        },
      ],

      // Networking
      "networkConfigTableCollection": [
        {
          "hasBroadband": _networkConfig.hasBroadband == true ? "Y" : "N",
          "freePort": _networkConfig.freePort == true ? "Y" : "N",
          "managedByThird": _networkConfig.managedByThird == true ? "Y" : "N",
          "portAlocatedFccAtg":
              _networkConfig.portAllocatedFccAtg == true ? "Y" : "N",
          "teamviewerBlocked":
              _networkConfig.teamviewerBlocked == true ? "Y" : "N",
          "usersTable": {"id": userId}, // Replace with actual user ID
        },
      ],

      "tanksConfigTableCollection":
          _tanks.map((tank) {
            // Filter nozzles related to this specific tank
            final tankNozzles =
                _nozzles
                    .where((nozzle) => nozzle.tankId == tank.tankNumber)
                    .toList();

            return {
              "tankNumber": tank.tankNumber,
              "gradesInfo": tank.gradesInfo,
              "capacity": tank.capacity?.toString(),
              "doubleWalled": tank.doubleWalled == true ? "Y" : "N",
              "pressureOrSuction": tank.pressureOrSuction,
              "siphonedInfo": tank.siphonedInfo == true ? "Y" : "N",
              "siphonedFromTankIds": tank.siphonedFromTankIds,
              "tankChartAvailable": tank.tankChartAvailable == true ? "Y" : "N",
              "dipStickAvailable": tank.dipStickAvailable == true ? "Y" : "N",
              "fuelAgeDays": tank.fuelAgeDays?.toString(),
              "diameterA": tank.diameterA,
              "manholeDepthB": tank.manholeDepthB,
              "probeLength": tank.probeLength,
              "manholeCoverMetal": tank.manholeCoverMetal == true ? "Y" : "N",
              "manholeWallMetal": tank.manholeWallMetal == true ? "Y" : "N",
              "remoteAntennaRequired":
                  tank.remoteAntennaRequired == true ? "Y" : "N",
              "tankEntryDiameter": tank.tankEntryDiameter,
              "probeCableLengthToKiosk": tank.probeCableLengthToKiosk,

              // 🔁 Only add related nozzles here:
              "nozzlesTableCollection":
                  tankNozzles.map((nozzle) {
                    return {
                      "nozzelNumbers": nozzle.nozzleNumbers,
                      "gradeInfo": nozzle.gradeInfo,
                      "pumpId1": nozzle.pumpId,
                      "tankId1": nozzle.tankId,
                      "userTable": {"id": userId},
                    };
                  }).toList(),

              "usersId": {"id": userId},
            };
          }).toList(),

      "pumpTableCollection":
          _pumps.map((pump) {
            // Filter nozzles related to this specific pump
            final pumpNozzles =
                _nozzles
                    .where((nozzle) => nozzle.pumpId == pump.pumpNumber)
                    .toList();

            return {
              "pumpNumber": pump.pumpNumber,
              "brandInfo": pump.brandInfo,
              "modelInfo": pump.modelInfo,
              "serialNumber": pump.serialNumber,
              "cpuFirmwaresInfo": pump.cpuFirmwaresInfo,
              "nozzlesInfo": pump.nozzlesInfo,
              "pumpAddressInfo": pump.pumpAddressInfo,
              "protocolInfo": pump.protocolInfo,
              "cableLengthToFcc": pump.cableLengthToFcc,

              // 🔁 Only include nozzles related to this pump
              "nozzlesTableCollection":
                  pumpNozzles.map((nozzle) {
                    return {
                      "nozzelNumbers": nozzle.nozzleNumbers,
                      "gradeInfo": nozzle.gradeInfo,
                      "pumpId1": nozzle.pumpId,
                      "tankId1": nozzle.tankId,
                      "userTable": {"id": userId},
                    };
                  }).toList(),

              "userTables": {"id": userId},
            };
          }).toList(),

      // Notes/Comments
      "reviewCommentTableCollection":
          _notes
              .map(
                (note) => {
                  "commentInfo": note.commentInfo,
                  "userTable": {"id": userId}, // Replace with actual user ID
                },
              )
              .toList(),
    };
  }
}
