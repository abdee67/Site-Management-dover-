// lib/db/database_helper.dart
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = "dover.db";
  static const _databaseVersion = 2;

  

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

 Future<Database> initDB() async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final path = join(documentsDirectory.path, _databaseName);

  return await openDatabase(
    path,
    version: _databaseVersion,
    onConfigure: (db) async {
    await db.execute("PRAGMA foreign_keys = ON");
  },
    onCreate: (db, version) async {
      print("📦 Creating tables...");

      await db.execute('''
        CREATE TABLE address_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          company_name TEXT,
          country TEXT,
          date_of_entry TEXT,
          updated_date TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE site_detail_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          site_name TEXT,
          site_id TEXT,
          address_info TEXT,
          country_info TEXT,
          city_info TEXT,
          town_info TEXT,
          geoloaction_info TEXT,
          site_cell_phone TEXT,
          site_email_address TEXT,
          brand_of_fuels_sold TEXT,
          fuel_supply_terminal_name TEXT,
          manned_unmanned TEXT,
          date_entry TEXT,
          date_updated TEXT,
          status TEXT DEFAULT 'N',
          users TEXT DEFAULT NULL,
          company_name INTEGER,
          FOREIGN KEY (company_name) REFERENCES address_table(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE contacts_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          site_id INTEGER,
          contact_name TEXT,
          role_table TEXT,
          phone_number TEXT,
          date_entry TEXT,
          date_updated TEXT,
          email_address TEXT,
          FOREIGN KEY (site_id) REFERENCES site_detail_table(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE network_config_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          site_id INTEGER,
          has_broadband TEXT,
          free_port TEXT,
          managed_by_third TEXT,
          port_alocated_fcc_atg TEXT,
          teamviewer_blocked TEXT,
          date_entry TEXT,
          date_updated TEXT,
          FOREIGN KEY (site_id) REFERENCES site_detail_table(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE pump_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          site_id INTEGER,
          pump_number INTEGER,
          brand_info TEXT,
          model_info TEXT,
          serial_number TEXT,
          cpu_firmwares_info TEXT,
          protocol_info TEXT,
          cable_length_to_fcc REAL,
          nozzles_info TEXT,
          pump_address_info TEXT,
          cable_length_to_fcc_measurement TEXT,
          date_entry TEXT,
          date_updated TEXT,
          FOREIGN KEY (site_id) REFERENCES site_detail_table(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE tanks_config_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          site_id INTEGER,
          tank_number INTEGER,
          grades_info TEXT,
          capacity REAL,
          safe_working_capacity TEXT,
          double_walled TEXT,
          siphoned_info TEXT,
          siphoned_from_tank_ids TEXT,
          tank_chart_available TEXT,
          dip_stick_available TEXT,
          fuel_age_days REAL,
          pressure_or_suction TEXT,
          diameter_a REAL,
          manhole_depth_b REAL,
          probe_length REAL,
          manhole_cover_metal TEXT,
          manhole_wall_metal TEXT,
          remote_antenna_required TEXT,
          tank_entry_diameter REAL,
          probe_cable_length_to_kiosk REAL,
          date_enters TEXT,
          date_updated TEXT,
          safe_working_capacity_measumentt TEXT,
          probe_length_measurement TEXT,
          diameter_a_measurement TEXT,
          manhole_depth_b_measurement TEXT,
          probe_cable_length_to_kiosk_measurement TEXT,
          FOREIGN KEY (site_id) REFERENCES site_detail_table(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE nozzles_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pump_id INTEGER,
          nozzel_numbers INTEGER,
          grade_info TEXT,
          tank_id INTEGER,
          date_entry TEXT,
          date_update TEXT,
          FOREIGN KEY (pump_id) REFERENCES pump_table(id),
          FOREIGN KEY (tank_id) REFERENCES tanks_config_table(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE power_configuration_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          site_id INTEGER,
          grounding_value TEXT,
          date_entry TEXT,
          date_updated_date TEXT,
          main_power_FCC_ATG TEXT,
          main_power_fusion_wireless_gateway TEXT,
          ups_for_fcc_atg TEXT,
          ups_dispenser TEXT,
          main_power_dispenser_wireless_gateway TEXT,
          separation_of_data_cable TEXT,
          availablity_data_pump_to_fcc TEXT,
          conduit_cable_install TEXT,
          FOREIGN KEY (site_id) REFERENCES site_detail_table(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE site_equipment_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          site_id INTEGER,
          fcc_model TEXT,
          fcc_locations TEXT,
          atg_model TEXT,
          atg_location TEXT,
          printer_required TEXT,
          date_updated TEXT,
          date_entry TEXT,
          FOREIGN KEY (site_id) REFERENCES site_detail_table(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE review_comment_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          comment_info TEXT,
          site_id INTEGER,
          date_entry TEXT,
          date_updated TEXT,
          FOREIGN KEY (site_id) REFERENCES site_detail_table(id)
        )
      ''');
      
        // ✅ Add new pending_syncs table
        await db.execute('''
          CREATE TABLE pending_syncs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER,
            endpoint TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0
          )
        ''');


      print("✅ All tables created.");
    },
     // ✅ This is important for upgrading existing apps
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          print("⚙️ Upgrading DB from version $oldVersion to $newVersion...");
          await db.execute('''
            CREATE TABLE pending_syncs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              site_id INTEGER,
              endpoint TEXT NOT NULL,
              data TEXT NOT NULL,
              created_at TEXT NOT NULL,
              retry_count INTEGER DEFAULT 0
            )
          ''');
          print("✅ pending_syncs table added.");
        }
      },
    onOpen: (db) async {
      await db.execute("PRAGMA foreign_keys = ON");
      final tables = await db.rawQuery('SELECT name FROM sqlite_master WHERE type="table"');
      print('📋 Tables in database: $tables');
    },
  );
}

}