// lib/screens/main_app/search_screen.dart
import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _locationController = TextEditingController();
  List<dynamic> _providers = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _searchProviders(String region) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _providers = [];
    });

    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString(AppConstants.authTokenKey);

    if (authToken == null || authToken.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.searchProviders),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'region': region}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _providers = data['providers'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to load providers. Status: ${response.statusCode}';
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to the server: $error';
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Enter location (e.g., Westlands)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _locationController.clear();
                    setState(() {
                      _providers = [];
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _searchProviders(value);
                }
              },
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                if (_locationController.text.isNotEmpty) {
                                  _searchProviders(_locationController.text);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Expanded(
                        child: _providers.isEmpty
                            ? const Center(
                                child: Text('Search for providers by location'))
                            : ListView.builder(
                                itemCount: _providers.length,
                                itemBuilder: (context, index) {
                                  final provider = _providers[index];
                                  return Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.grey,
                                        child: Icon(Icons.person,
                                            color: Colors.white),
                                      ),
                                      title: Text(provider['name'] ??
                                          'Unknown Provider'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Distance: ${provider['distance'] ?? 'N/A'} km'),
                                          Text(
                                              'Available: ${provider['available'] ?? false ? 'Yes' : 'No'}'),
                                        ],
                                      ),
                                      onTap: () {
                                        // Navigate to provider details (future implementation)
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
          ],
        ),
      ),
    );
  }
}
