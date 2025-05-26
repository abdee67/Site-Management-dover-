import 'package:dover/screens/siteDetail.dart';
import 'package:flutter/material.dart';
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
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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

  // Form data models
  final Set<int> _visitedSteps = {0};
  List<Map<String, dynamic>> _companyNames = [];
  int? _selectedCompanyId;

  @override
  void initState() {
    super.initState();
    _siteDetail = widget.existingSite ?? SiteDetail();
    _equipmentInfo = widget.equipmentInfo ?? SiteEquipment();
    _powerConfig = widget.powerConfig ?? PowerConfiguration();
    _networkConfig = widget.networkConfig ?? NetworkConfig();
    _tanks = widget.tanks ?? [];
    _pumps = widget.pumps ?? [];
    _nozzles = widget.nozzles ?? [];
    _contacts = widget.contacts ?? [];
    _notes = widget.notes ?? [];
    _loadCompanyNames();
    // ... other init code ...
  }

  Future<void> _loadCompanyNames() async {
    try {
      final companies =
          await widget.sitedetaildatabase.getCompaniesForDropdown();
      setState(() {
        _companyNames = companies;
        if (widget.existingSite?.companyId != null) {
          _selectedCompanyId = widget.existingSite?.companyId;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading companies: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitles(_currentStep)),
        actions: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goToPreviousStep,
            ),
          if (_currentStep < 7)
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _goToNextStep,
            ),
        ],
      ),
      body: Column(
        children: [
          //Progress indicator
          LinearProgressIndicator(value: (_currentStep + 1) / 9),
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
      // Previous button (hidden on first step)
      if (_currentStep > 0)
        ElevatedButton(
          onPressed: _goToPreviousStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: const Text('Previous'),
        )
      else
        const SizedBox(width: 120), // Reserve space

      // Next or Submit button
      ElevatedButton(
        onPressed: _currentStep < 8 ? _goToNextStep : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: _currentStep < 8 ? Colors.amber.shade600 : Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Text(_currentStep < 8 ? 'Next' : 'Submit'),
      ),
    ],
  ),
)

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
    _visitedSteps.add(_currentStep);
    setState(() {
      if (_currentStep < 8) {
        _currentStep++;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _goToPreviousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget _buildSiteDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(0)
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<int>(
              value: _selectedCompanyId,
              decoration: const InputDecoration(labelText: 'Company Name'),
              items:
                  _companyNames
                      .map(
                        (company) => DropdownMenuItem<int>(
                          value: company['id'],
                          child: Text(company['company_name']),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCompanyId = value;
                  _siteDetail.companyId = value;
                  // Store the name for display purposes
                  _siteDetail.companyName =
                      _companyNames.firstWhere(
                        (c) => c['id'] == value,
                      )['company_name'];
                });
              },
              validator:
                  (value) => value == null ? 'Company must be selected' : null,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Site Name'),
              validator:
                  (value) =>
                      value?.isEmpty ?? true ? 'Site name is mandatory' : null,
              onSaved: (value) => _siteDetail.siteName = value,
              onChanged: (value) => _siteDetail.siteName = value,
              initialValue: _siteDetail.siteName,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Site ID'),
              validator:
                  (value) =>
                      value?.isEmpty ?? true ? 'Site ID is mandatory' : null,
              onSaved: (value) => _siteDetail.siteId = value,
              onChanged: (value) => _siteDetail.siteId = value,
              initialValue: _siteDetail.siteId,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Full Address'),
              maxLines: 3,
              validator:
                  (value) =>
                      value?.isEmpty ?? true ? 'Address cannot be empty' : null,
              onSaved: (value) => _siteDetail.addressInfo = value,
              onChanged: (value) => _siteDetail.addressInfo = value,
              initialValue: _siteDetail.addressInfo,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Country'),
              onSaved: (value) => _siteDetail.countryInfo = value,
              onChanged: (value) => _siteDetail.countryInfo = value,
              initialValue: _siteDetail.countryInfo,
            ),
            DropdownButtonFormField<String>(
              value: _siteDetail.cityInfo,
              decoration: const InputDecoration(labelText: 'City'),
              items:
                  ['City A', 'City B', 'City C']
                      .map(
                        (city) =>
                            DropdownMenuItem(value: city, child: Text(city)),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() => _siteDetail.cityInfo = value),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Town/Area'),
              onSaved: (value) => _siteDetail.townInfo = value,
              onChanged: (value) => _siteDetail.townInfo = value,
              initialValue: _siteDetail.townInfo,
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Geo-Location (Lat, Lon)',
              ),
              readOnly: false,
              onSaved: (value) => _siteDetail.geolocationInfo = value,
              onChanged: (value) => _siteDetail.geolocationInfo = value,
              initialValue: _siteDetail.geolocationInfo,
            ),
            DropdownButtonFormField<String>(
              value: _siteDetail.mannedUnmanned,
              decoration: const InputDecoration(labelText: 'Site Type'),
              items:
                  ['Manned', 'Unmanned']
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() => _siteDetail.mannedUnmanned = value),
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Fuel Supply / Terminal',
              ),
              onSaved: (value) => _siteDetail.fuelSupplyTerminalName = value,
              onChanged: (value) => _siteDetail.fuelSupplyTerminalName = value,
              initialValue: _siteDetail.fuelSupplyTerminalName,
            ),
            DropdownButtonFormField<String>(
              value: _siteDetail.brandOfFuelsSold,
              decoration: const InputDecoration(
                labelText: 'Brands of Fuel Sold',
              ),
              items:
                  ['AGO', 'MGR', 'KERO']
                      .map(
                        (fuel) =>
                            DropdownMenuItem(value: fuel, child: Text(fuel)),
                      )
                      .toList(),
              onChanged:
                  (value) =>
                      setState(() => _siteDetail.brandOfFuelsSold = value),
            ),

            const SizedBox(height: 20),
            const Text(
              'Site Contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._buildContactsList(),
            ElevatedButton(
              onPressed: _addContact,
              child: const Text('Add Contact'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContactsList() {
    return _contacts.map((contact) {
      final index = _contacts.indexOf(contact);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Contact Name'),
                initialValue: contact.contactName,
                onChanged: (value) => contact.contactName = value,
              ),
              DropdownButtonFormField<String>(
                value: contact.role,
                decoration: const InputDecoration(labelText: 'Role'),
                items:
                    ['Area Contact', 'Site Contact']
                        .map(
                          (role) =>
                              DropdownMenuItem(value: role, child: Text(role)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => contact.role = value),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Phone Number'),
                initialValue: contact.phoneNumber,
                keyboardType: TextInputType.phone,
                onChanged: (value) => contact.phoneNumber = value,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email Address'),
                initialValue: contact.email,
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) => contact.email = value,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(() => _contacts.removeAt(index)),
              ),
            ],
          ),
        ),
      );
    }).toList();
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
            const Text(
              'Equipment Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'FCC Type and Model',
              ),
              onSaved: (value) => _equipmentInfo.fccModel = value,
              onChanged: (value) => _equipmentInfo.fccModel = value,
              initialValue: _equipmentInfo.fccModel,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'FCC Location'),
              onSaved: (value) => _equipmentInfo.fccLocations = value,
              onChanged: (value) => _equipmentInfo.fccLocations = value,
              initialValue: _equipmentInfo.fccLocations,
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'ATG Type and Model',
              ),
              onSaved: (value) => _equipmentInfo.atgModel = value,
              onChanged: (value) => _equipmentInfo.atgModel = value,
              initialValue: _equipmentInfo.atgModel,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'ATG Location'),
              onSaved: (value) => _equipmentInfo.atgLocation = value,
              onChanged: (value) => _equipmentInfo.atgLocation = value,
              initialValue: _equipmentInfo.atgLocation,
            ),
            SwitchListTile(
              title: const Text('Requires printer for FCC/ATG Console?'),
              value: _equipmentInfo.printerRequired ?? false,
              onChanged:
                  (value) =>
                      setState(() => _equipmentInfo.printerRequired = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerConfigStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(2)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Power Supply & Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Station Grounding Value',
              ),
              onSaved: (value) => _powerConfig.groundingValue = value,
              onChanged: (value) => _powerConfig.groundingValue = value,
              initialValue: _powerConfig.groundingValue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Power Checklist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text(
                'Mains power outlets (220V) within 1m of FCC/ATG',
              ),
              value: _powerConfig.mainPowerFccAtg ?? false,
              onChanged:
                  (value) =>
                      setState(() => _powerConfig.mainPowerFccAtg = value),
            ),
            SwitchListTile(
              title: const Text(
                'Mains power outlets (220V) within 1m of Fusion Wireless Gateway',
              ),
              value: _powerConfig.mainPowerFusionWirelessGateway ?? false,
              onChanged:
                  (value) => setState(
                    () => _powerConfig.mainPowerFusionWirelessGateway = value,
                  ),
            ),
            SwitchListTile(
              title: const Text(
                'FCC/ATG power supply protection via UPS available',
              ),
              value: _powerConfig.upsForFccAtg ?? false,
              onChanged:
                  (value) => setState(() => _powerConfig.upsForFccAtg = value),
            ),
            SwitchListTile(
              title: const Text(
                'Dispenser power supply protection via UPS available',
              ),
              value: _powerConfig.upsDispenser ?? false,
              onChanged:
                  (value) => setState(() => _powerConfig.upsDispenser = value),
            ),
            SwitchListTile(
              title: const Text(
                'Mains power outlets (220V) at Dispenser for Dispenser Wireless Gateway',
              ),
              value: _powerConfig.mainPowerFusionWirelessGateway ?? false,
              onChanged:
                  (value) => setState(
                    () => _powerConfig.mainPowerFusionWirelessGateway = value,
                  ),
            ),
            SwitchListTile(
              title: const Text(
                'Separation of data and power cable conduits in place',
              ),
              value: _powerConfig.separationOfDataCable ?? false,
              onChanged:
                  (value) => setState(
                    () => _powerConfig.separationOfDataCable = value,
                  ),
            ),
            SwitchListTile(
              title: const Text(
                'Availability of data conduit from Pumps to FCC room',
              ),
              value: _powerConfig.availabilityDataPumpToFcc ?? false,
              onChanged:
                  (value) => setState(
                    () => _powerConfig.availabilityDataPumpToFcc = value,
                  ),
            ),
            SwitchListTile(
              title: const Text(
                'Conduit/Cable gland for Dispenser Wireless Gateway communication cable',
              ),
              value: _powerConfig.conduitCableInstall ?? false,
              onChanged:
                  (value) =>
                      setState(() => _powerConfig.conduitCableInstall = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkConfigStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(3)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Internet Connectivity & Network Setup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('Does the site have a broadband connection?'),
              value: _networkConfig.hasBroadband ?? false,
              onChanged:
                  (value) =>
                      setState(() => _networkConfig.hasBroadband = value),
            ),
            const SizedBox(height: 20),
            const Text(
              'Network Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text(
                'Are there free network ports on the broadband router?',
              ),
              value: _networkConfig.freePort ?? false,
              onChanged:
                  (value) => setState(() => _networkConfig.freePort = value),
            ),
            SwitchListTile(
              title: const Text('Is the network managed by a third party?'),
              value: _networkConfig.managedByThird ?? false,
              onChanged:
                  (value) => setState(() {
                    _networkConfig.managedByThird = value;
                    if (value) {
                      // Show a snackbar if managed by third party
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'If managed by a third party, you may need to contact them for configuration details.',
                          ),
                        ),
                      );
                    }
                  }),
            ),
            SwitchListTile(
              title: const Text(
                'Are ports specifically allocated for use by the FCC/ATG?',
              ),
              value: _networkConfig.portAllocatedFccAtg ?? false,
              onChanged:
                  (value) => setState(
                    () => _networkConfig.portAllocatedFccAtg = value,
                  ),
            ),
            SwitchListTile(
              title: const Text(
                'Does the site network prevent remote access via TeamViewer?',
              ),
              value: _networkConfig.teamviewerBlocked ?? false,
              onChanged:
                  (value) =>
                      setState(() => _networkConfig.teamviewerBlocked = value),
            ),
          ],
        ),
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
            const Text(
              'Tank Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._buildTanksList(),
            ElevatedButton(onPressed: _addTank, child: const Text('Add Tank')),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTanksList() {
    return _tanks.map((tank) {
      final index = _tanks.indexOf(tank);
      return ExpansionTile(
        title: Text('Tank ${tank.tankNumber}'),
        children: [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Tank Number'),
            initialValue: tank.tankNumber?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) => tank.tankNumber = int.tryParse(value ?? ''),
          ),
          DropdownButtonFormField<String>(
            value: tank.gradesInfo,
            decoration: const InputDecoration(labelText: 'Fuel Grade'),
            items:
                ['MGR(Gasoline)', 'AGO(Diesel)', 'Kero(Kereonse)', 'JETA1']
                    .map(
                      (grade) =>
                          DropdownMenuItem(value: grade, child: Text(grade)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => tank.gradesInfo = value),
          ),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Safe Working Capacity (Liters)',
            ),
            initialValue: tank.capacity?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) => tank.capacity = double.tryParse(value ?? ''),
          ),
          SwitchListTile(
            title: const Text('Double Walled'),
            value: tank.doubleWalled ?? false,
            onChanged: (value) => setState(() => tank.doubleWalled = value),
          ),
          DropdownButtonFormField<String>(
            value: tank.pressureOrSuction,
            decoration: const InputDecoration(labelText: 'Pressure/Suction'),
            items:
                ['Pressure', 'Suction']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
            onChanged:
                (value) => setState(() => tank.pressureOrSuction = value),
          ),
          SwitchListTile(
            title: const Text('Siphoned'),
            value: tank.siphonedInfo ?? false,
            onChanged:
                (value) => setState(() {
                  tank.siphonedInfo = value;
                  if (!value) {
                    tank.siphonedFromTankIds = null;
                  }
                }),
          ),
          if (tank.siphonedInfo ?? false)
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Siphoned From Tank IDs',
              ),
              initialValue: tank.siphonedFromTankIds,
              onChanged: (value) => tank.siphonedFromTankIds = value,
            ),
          SwitchListTile(
            title: const Text('Tank Chart Available'),
            value: tank.tankChartAvailable ?? false,
            onChanged:
                (value) => setState(() => tank.tankChartAvailable = value),
          ),
          SwitchListTile(
            title: const Text('Dipstick Available'),
            value: tank.dipStickAvailable ?? false,
            onChanged:
                (value) => setState(() => tank.dipStickAvailable = value),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Tank Age (Days)'),
            initialValue: tank.fuelAgeDays?.toString(),
            keyboardType: TextInputType.number,
            onChanged:
                (value) => tank.fuelAgeDays = double.tryParse(value ?? ''),
          ),
          // Additional tank measurements
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Tank Diameter (A) (m)',
            ),
            initialValue: tank.diameterA?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) => tank.diameterA = double.tryParse(value ?? ''),
          ),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Manhole Depth (B) (m)',
            ),
            initialValue: tank.manholeDepthB?.toString(),
            keyboardType: TextInputType.number,
            onChanged:
                (value) => tank.manholeDepthB = double.tryParse(value ?? ''),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Probe Length (m)'),
            initialValue: tank.probeLength?.toString(),
            keyboardType: TextInputType.number,
            onChanged:
                (value) => tank.probeLength = double.tryParse(value ?? ''),
          ),
          SwitchListTile(
            title: const Text('Manhole Cover Metal'),
            value: tank.manholeCoverMetal ?? false,
            onChanged:
                (value) => setState(() => tank.manholeCoverMetal = value),
          ),
          SwitchListTile(
            title: const Text('Manhole Wall Metal'),
            value: tank.manholeWallMetal ?? false,
            onChanged: (value) => setState(() => tank.manholeWallMetal = value),
          ),
          SwitchListTile(
            title: const Text('Remote Antenna Required'),
            value: tank.remoteAntennaRequired ?? false,
            onChanged:
                (value) => setState(() => tank.remoteAntennaRequired = value),
          ),
          DropdownButtonFormField<double>(
            value: tank.tankEntryDiameter,
            decoration: const InputDecoration(
              labelText: 'Tank Entry for Probes (inch)',
            ),
            items:
                [2.0, 3.0, 4.0]
                    .map(
                      (size) =>
                          DropdownMenuItem(value: size, child: Text('$size"')),
                    )
                    .toList(),
            onChanged:
                (value) => setState(() => tank.tankEntryDiameter = value),
          ),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Cable Length to Kiosk (m)',
            ),
            initialValue: tank.probeCableLengthToKiosk?.toString(),
            keyboardType: TextInputType.number,
            onChanged:
                (value) =>
                    tank.probeCableLengthToKiosk = double.tryParse(value ?? ''),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => setState(() => _tanks.removeAt(index)),
          ),
        ],
      );
    }).toList();
  }

  void _addTank() {
    setState(() {
      _tanks.add(TankConfig()..tankNumber = (_tanks.length + 1));
    });
  }

  Widget _buildPumpConfigStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(5)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pump Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._buildPumpsList(),
            ElevatedButton(onPressed: _addPump, child: const Text('Add Pump')),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPumpsList() {
    return _pumps.map((pump) {
      final index = _pumps.indexOf(pump);
      return ExpansionTile(
        title: Text('Pump ${pump.pumpNumber}'),
        children: [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Pump Number'),
            initialValue: pump.pumpNumber?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) => pump.pumpNumber = int.tryParse(value ?? ''),
          ),
          DropdownButtonFormField<String>(
            value: pump.brandInfo,
            decoration: const InputDecoration(labelText: 'Brand'),
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
                      (brand) =>
                          DropdownMenuItem(value: brand, child: Text(brand)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => pump.brandInfo = value),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Model'),
            initialValue: pump.modelInfo,
            onChanged: (value) => pump.modelInfo = value,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Serial Number'),
            initialValue: pump.serialNumber,
            onChanged: (value) => pump.serialNumber = value,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'CPU/Firmware'),
            initialValue: pump.cpuFirmwaresInfo,
            onChanged: (value) => pump.cpuFirmwaresInfo = value,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Protocol'),
            initialValue: pump.protocolInfo,
            onChanged: (value) => pump.protocolInfo = value,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Nozzles Count'),
            initialValue: pump.nozzlesInfo?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) => pump.nozzlesInfo = value,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Pump Address'),
            initialValue: pump.pumpAddressInfo,
            onChanged: (value) => pump.pumpAddressInfo = value,
          ),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Cable Length to FCC (m)',
            ),
            initialValue: pump.cableLengthToFcc?.toString(),
            keyboardType: TextInputType.number,
            onChanged:
                (value) => pump.cableLengthToFcc = double.tryParse(value ?? ''),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => setState(() => _pumps.removeAt(index)),
          ),
        ],
      );
    }).toList();
  }

  void _addPump() {
    setState(() {
      _pumps.add(Pump()..pumpNumber = (_pumps.length + 1));
    });
  }

  Widget _buildNozzleConfigStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(6)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nozzle Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._buildNozzlesList(),
            ElevatedButton(
              onPressed: _addNozzle,
              child: const Text('Add Nozzle'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNozzlesList() {
    return _nozzles.asMap().entries.map((entry) {
      final index = entry.key;
      final nozzle = entry.value;

      // Find matching pump and tank for the current nozzle
      final pump = _pumps.firstWhere(
        (p) => p.id == nozzle.pumpId,
        orElse: () => Pump(),
      );

      final tank = _tanks.firstWhere(
        (t) => t.id == nozzle.tankId,
        orElse: () => TankConfig(),
      );

      // Set the display values for dropdowns
      final pumpDisplayValue =
          pump.id != null
              ? 'Pump ${pump.pumpNumber} - ${pump.brandInfo}'
              : null;

      final tankDisplayValue =
          tank.id != null
              ? 'Tank ${tank.tankNumber} - ${tank.gradesInfo}'
              : null;

      final validGradeInfo =
          [
                'MGR(Gasoline)',
                'AGO(Diesel)',
                'Kero(Kereonse)',
                'JETA1',
              ].contains(nozzle.gradeInfo)
              ? nozzle.gradeInfo
              : null;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: pumpDisplayValue,
                decoration: InputDecoration(labelText: 'Pump'),
                items:
                    _pumps.map((pump) {
                      return DropdownMenuItem<String>(
                        value: 'Pump ${pump.pumpNumber} - ${pump.brandInfo}',
                        child: Text(
                          'Pump ${pump.pumpNumber} - ${pump.brandInfo}',
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    nozzle.pumpsSelection = value;
                    if (value != null) {
                      final pumpNumber = int.parse(value.split(' ')[1]);
                      nozzle.pumpId =
                          _pumps
                              .firstWhere((p) => p.pumpNumber == pumpNumber)
                              .id;
                    }
                  });
                },
              ),

              TextFormField(
                decoration: const InputDecoration(labelText: 'Nozzle Number'),
                initialValue: nozzle.nozzleNumbers?.toString(),
                keyboardType: TextInputType.number,
                onChanged:
                    (value) => nozzle.nozzleNumbers = int.tryParse(value ?? ''),
              ),

              DropdownButtonFormField<String>(
                value: validGradeInfo,
                decoration: const InputDecoration(labelText: 'Grade'),
                items:
                    ['MGR(Gasoline)', 'AGO(Diesel)', 'Kero(Kereonse)', 'JETA1']
                        .map(
                          (grade) => DropdownMenuItem(
                            value: grade,
                            child: Text(grade),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => nozzle.gradeInfo = value),
              ),

              DropdownButtonFormField<String>(
                value: tankDisplayValue,
                decoration: InputDecoration(labelText: 'Tank'),
                items:
                    _tanks.map((tank) {
                      return DropdownMenuItem<String>(
                        value: 'Tank ${tank.tankNumber} - ${tank.gradesInfo}',
                        child: Text(
                          'Tank ${tank.tankNumber} - ${tank.gradesInfo}',
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    nozzle.tankSelection = value;
                    if (value != null) {
                      final tankNumber = int.parse(value.split(' ')[1]);
                      nozzle.tankId =
                          _tanks
                              .firstWhere((t) => t.tankNumber == tankNumber)
                              .id;
                    }
                  });
                },
              ),

              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(() => _nozzles.removeAt(index)),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _addNozzle() {
    if (_pumps.isNotEmpty && _tanks.isNotEmpty) {
      setState(() {
        _nozzles.add(Nozzle());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one pump and tank first.'),
        ),
      );
    }
  }

  Widget _buildNotesStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        autovalidateMode:
            _visitedSteps.contains(7)
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Notes and Review Comments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ..._buildNotesList(),
            ElevatedButton(onPressed: _addNote, child: const Text('Add Note')),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNotesList() {
    return _notes.map((note) {
      final index = _notes.indexOf(note);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Note/Comment'),
                maxLines: 3,
                initialValue: note.commentInfo,
                onChanged: (value) => note.commentInfo = value,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(() => _notes.removeAt(index)),
              ),
            ],
          ),
        ),
      );
    }).toList();
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              icon: Icons.local_gas_station,
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
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      children: children,
    );
  }

  Widget _buildConfirmationItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value ?? 'Not specified')),
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
        builder:
            (context) => AlertDialog(
              title: const Text('Confirm Submission'),
              content: const Text(
                'Are you sure you want to submit this site configuration',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancle'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Site configuration Submitted Successfully',
                        ),
                      ),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields!')),
      );
    }
  }

  // Update the _saveData method to properly handle relationships
  Future<void> _saveData() async {
    try {
      bool isSaved = false;
      final db = await widget.sitedetaildatabase.dbHelper.database;

      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        // 1. Save Site Detail
        if (_siteDetail.id == null) {
          _siteDetail.dateEntry = DateTime.parse(now);
          _siteDetail.id = await txn.insert(
            'site_detail_table',
            _siteDetail.toMap(),
          );
        } else {
          _siteDetail.dateUpdated = DateTime.parse(now);
          await txn.update(
            'site_detail_table',
            _siteDetail.toMap(),
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
              contact.toMap(),
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
            _equipmentInfo.toMap(),
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
            _powerConfig.toMap(),
          );
        } else {
          _powerConfig.dateUpdatedDate = DateTime.parse(now);
          await txn.update(
            'power_configuration_table',
            _powerConfig.toMap(),
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
            _networkConfig.toMap(),
          );
        } else {
          _networkConfig.dateUpdated = DateTime.parse(now);
          await txn.update(
            'network_config_table',
            _networkConfig.toMap(),
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
              tank.toMap(),
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
              pump.toMap(),
              where: 'id = ?',
              whereArgs: [pump.id],
            );
          }
          savedPumps.add(pump);
        }

        // 8. Save Nozzles
        for (final nozzle in _nozzles) {
          // Resolve Pump ID (using pumpNumber to ID mapping)
          if (nozzle.pumpsSelection != null) {
            final pumpNumber = int.tryParse(
              nozzle.pumpsSelection!.split(' ')[1],
            );
            if (pumpNumber != null) {
              final pump = savedPumps.firstWhere(
                (p) => p.pumpNumber == pumpNumber,
                orElse: () => Pump(),
              );
              if (pump.id != null) {
                nozzle.pumpId = pump.id;
              } else {
                debugPrint(
                  'Warning: Could not find pump with number $pumpNumber',
                );
                continue; // Skip this nozzle if pump not found
              }
            }
          }

          // Resolve Tank ID (using tankNumber to ID mapping)
          if (nozzle.tankSelection != null) {
            final tankNumber = int.tryParse(
              nozzle.tankSelection!.split(' ')[1],
            );
            if (tankNumber != null) {
              final tank = savedTanks.firstWhere(
                (t) => t.tankNumber == tankNumber,
                orElse: () => TankConfig(),
              );
              if (tank.id != null) {
                nozzle.tankId = tank.id;
              } else {
                debugPrint(
                  'Warning: Could not find tank with number $tankNumber',
                );
                continue; // Skip this nozzle if tank not found
              }
            }
          }

          if (nozzle.id == null) {
            nozzle.dateEntry = DateTime.parse(now);
            nozzle.id = await txn.insert('nozzles_table', nozzle.toMap());
          } else {
            nozzle.dateUpdate = DateTime.parse(now);
            await txn.update(
              'nozzles_table',
              nozzle.toMap(),
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
              note.toMap(),
              where: 'id = ?',
              whereArgs: [note.id],
            );
          }
        }

        isSaved = true;
      });

      if (isSaved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site configuration saved successfully!'),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back after saving
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving site configuration: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
