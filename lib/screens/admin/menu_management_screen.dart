import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  File? _selectedImage;
  bool isUploading = false;

  // Pick an image from the gallery.
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Upload the image to Firebase Storage and return its URL.
  Future<String> uploadImage(File imageFile) async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference storageRef =
        FirebaseStorage.instance.ref().child('menuImages/$fileName');
    UploadTask uploadTask = storageRef.putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  // Add a new menu item.
  Future<void> addMenuItem() async {
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) return;

    String imageUrl = "";
    if (_selectedImage != null) {
      setState(() {
        isUploading = true;
      });
      imageUrl = await uploadImage(_selectedImage!);
      setState(() {
        isUploading = false;
      });
    }

    await FirebaseFirestore.instance.collection('menuItems').add({
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'available': true,
    });

    nameController.clear();
    priceController.clear();
    setState(() {
      _selectedImage = null;
    });
  }

  // Delete a menu item.
  Future<void> deleteItem(String docId) async {
    await FirebaseFirestore.instance.collection('menuItems').doc(docId).delete();
  }

  // Toggle the availability of a menu item.
  Future<void> toggleAvailability(String docId, bool current) async {
    await FirebaseFirestore.instance
        .collection('menuItems')
        .doc(docId)
        .update({'available': !current});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Menu"),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Glassmorphism card for adding a new menu item.
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white.withOpacity(0.85),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        "Add New Menu Item",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Item Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Price",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _selectedImage == null
                          ? OutlinedButton.icon(
                              onPressed: pickImage,
                              icon: const Icon(Icons.image),
                              label: const Text("Upload Image"),
                            )
                          : Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _selectedImage!,
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedImage = null;
                                    });
                                  },
                                  child: const Text("Change Image"),
                                ),
                              ],
                            ),
                      const SizedBox(height: 16),
                      isUploading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: addMenuItem,
                              child: const Text("Add Item"),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(
                thickness: 2,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                "Existing Items",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // List of existing items.
              StreamBuilder(
                stream: FirebaseFirestore.instance.collection('menuItems').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!.docs;
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Colors.white70,
                      thickness: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final data = item.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: data['imageUrl'] != null &&
                                (data['imageUrl'] as String).isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  data['imageUrl'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.fastfood, size: 40),
                        title: Text(
                          "${data['name']} (₹${data['price']})",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        subtitle: Text(
                          data['available'] ? "Available" : "Unavailable",
                          style: GoogleFonts.poppins(color: Colors.white70),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => deleteItem(item.id),
                            ),
                            IconButton(
                              icon: Icon(
                                data['available'] ? Icons.visibility_off : Icons.visibility,
                                color: Colors.blueAccent,
                              ),
                              onPressed: () =>
                                  toggleAvailability(item.id, data['available']),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
