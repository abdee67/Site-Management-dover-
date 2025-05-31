import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '/db/siteDetailDatabase.dart';
import '/services/api_service.dart';
import '/screens/sitedetail.dart';

class LoginScreen extends StatefulWidget{
  final ApiService apiService;
  const LoginScreen({required this.apiService,super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Sitedetaildatabase db = Sitedetaildatabase.instance;
bool _isLoading = false;
  @override
  void initState() {
    super.initState();
  }
   Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;
    final username = _usernameController.text;
    final password = _passwordController.text;

    try {
      // Check if user exists in local DB
      final userExists = await db.checkUserExists(username);

      if (isOnline) {
        if (userExists) {
          // Online + existing user: validate locally
          final isValid = await db.validateUser(username, password);
          if (isValid) {
            _navigateToHome();
          } else {
            _showError('Invalid credentials');
          }
        } else {
          // Online + new user: authenticate via API
          final result = await widget.apiService.authenticateUser(username, password);
          if (result['success'] == true) {
            // Save to local DB
            final userId = result['userId'] as String?;
            await db.insertUser(username, password, userId: userId);
             // RESET ADDRESS TABLE ONLY FOR FIRST-TIME LOGIN
          if (result['addresses'] != null) {
            await _resetAndSyncAddresses(result['addresses']);
          }
            _navigateToHome();
          } else {
            _showError(result['error']);
          }
        }
      } else {
        if (userExists) {
          // Offline + existing user: validate locally
          final isValid = await db.validateUser(username, password);
          if (isValid) {
            _navigateToHome();
          } else {
            _showError('Invalid credentials');
          }
        } else {
          // Offline + new user: not possible
          _showError('No internet connection. First login requires internet');
        }
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }
Future<void> _resetAndSyncAddresses(List<dynamic> addresses) async {
  try {
    final database = await db.dbHelper.database;
    await database.delete('address_table');
    
    for (var address in addresses) {
      await database.insert(
        'address_table',
        {
          'id': address['id'],
          'company_name': address['companyName'],
          'country': address['country'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  } catch (e) {
    debugPrint('Error resetting address table: $e');
    rethrow;
  }
}

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SiteDetailScreen(
          sitedetaildatabase: db,
          username: _usernameController.text,
        ),
      ),
    );
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _login,
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}