import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // --- UNIFIED UI THEME COLORS (from HomeScreen) ---
  static const Color _primaryColor = Color(0xFF6A1B9A); // Deep Purple
  static const Color _deleteColor = Color(0xFFD32F2F); // Strong Red
  static const Color _starColor = Color(0xFFFFC107);   // Amber/Gold
  static const Color _scaffoldBgColor = Color(0xFFF8F9FA); // Cleaner off-white

  List<Map<String, dynamic>> contacts = [];
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  int? primaryContactId;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // Logic for loading contacts remains the same
  Future<void> _loadContacts() async {
    final data = await DBHelper.getContacts();
    if (data.length == 1) {
      final singleContact = data.first;
      final singleContactId = singleContact['id'];
      if (singleContact['is_primary'] != 1) {
        await DBHelper.setPrimaryContact(singleContactId);
      }
      if (mounted) {
        setState(() {
          contacts = data;
          primaryContactId = singleContactId;
        });
      }
    } else {
      final primaryContact = await DBHelper.getPrimaryContact();
      if (mounted) {
        setState(() {
          contacts = data;
          primaryContactId = primaryContact?['id'];
        });
      }
    }
  }

  Future<void> _addContact() async {
    if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
      await DBHelper.insertContact(nameController.text, phoneController.text);
      nameController.clear();
      phoneController.clear();
      if (mounted) Navigator.pop(context);
      _loadContacts();
    }
  }

  Future<void> _deleteContact(int id) async {
    await DBHelper.deleteContact(id);
    _loadContacts();
  }

  Future<void> _callNumber(String phone) async {
    String cleanPhone = phone.replaceAll(' ', '');
    final status = await Permission.phone.request();

    if (status.isGranted) {
      try {
        bool? res = await FlutterPhoneDirectCaller.callNumber(cleanPhone);
        if (res == null || !res) {
          final Uri telUri = Uri(scheme: 'tel', path: cleanPhone);
          if (await canLaunchUrl(telUri)) {
            await launchUrl(telUri);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not launch dialer')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error making call: $e')));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phone permission denied')));
      }
      if (status.isPermanentlyDenied) openAppSettings();
    }
  }

  Future<void> _setPrimaryContact(int id) async {
    await DBHelper.setPrimaryContact(id);
    _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBgColor, // THEME: Updated background color
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
        backgroundColor: _primaryColor, // THEME: Use primary color
        foregroundColor: Colors.white,
        elevation: 1.0,
      ),
      body: contacts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contact_phone_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No contacts added yet',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the "+" button to add one.',
              style: TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          final isPrimary = primaryContactId == contact['id'];
          return Card(
            elevation: isPrimary ? 4.0 : 2.0, // More shadow for primary
            margin:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            // --- UI/UX IMPROVEMENT: Add a border to the primary contact card ---
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isPrimary
                  ? const BorderSide(color: _primaryColor, width: 2.0)
                  : BorderSide.none,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              onTap: () => _callNumber(contact['phone'].toString()),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: _primaryColor, // THEME: Use primary color
                child: Text(
                  contact['name'][0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(contact['name'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(contact['phone'],
                  style:
                  TextStyle(fontSize: 14, color: Colors.grey[600])),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isPrimary ? Icons.star : Icons.star_border,
                      // THEME: Use themed star color
                      color: isPrimary ? _starColor : Colors.grey,
                      size: 30,
                    ),
                    onPressed: () => _setPrimaryContact(contact['id']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: _deleteColor), // THEME: Use themed delete color
                    onPressed: () => _deleteContact(contact['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor, // THEME: Use primary color
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          showModalBottomSheet(
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            context: context,
            builder: (context) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Contact Name',
                        // --- UI/UX IMPROVEMENT: Themed text fields ---
                        prefixIcon: const Icon(Icons.person, color: Colors.grey),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: _primaryColor, width: 2.0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone, color: Colors.grey),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: _primaryColor, width: 2.0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _addContact,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor, // THEME: Use primary color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add Contact',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}