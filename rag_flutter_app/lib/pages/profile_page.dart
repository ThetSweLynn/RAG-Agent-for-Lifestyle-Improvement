import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/globals.dart'; // Import the shared isDarkMode variable

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  String? _profileImageUrl; // Stores the selected profile image path
  String? _selectedGender; // Stores the selected gender
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          _nameController.text = userDoc['name'] ?? '';
          _ageController.text = userDoc['age']?.toString() ?? '';
          _weightController.text = userDoc['weight']?.toString() ?? '';
          _heightController.text = userDoc['height']?.toString() ?? '';
          _profileImageUrl = userDoc['profileImage'];
          _selectedGender = userDoc['gender'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'age': int.parse(_ageController.text.trim()),
        'weight': double.parse(_weightController.text.trim()),
        'height': double.parse(_heightController.text.trim()),
        'gender': _selectedGender,
        'profileImage': _profileImageUrl,
        'last_updated': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('leaderboard').doc(user.uid).update({
        'displayName': _nameController.text.trim(),
        'photoURL' : _profileImageUrl,
        'last_updated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile Updated Successfully!')),
      );

      setState(() {
        _isSubmitting = false;
      });
    } catch (e) {
      print("Error updating profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _chooseProfileImage() async {
    final double screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Choose Profile Image'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(6, (index) {
                String imagePath = 'assets/profile_pic${index + 1}.png';
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _profileImageUrl = imagePath;
                    });
                    Navigator.of(context).pop();
                  },
                  child: CircleAvatar(
                    radius: screenWidth * 0.1, // 10% of screen width
                    backgroundImage: AssetImage(imagePath),
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool darkMode, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: darkMode ? Colors.white70 : Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: darkMode ? Colors.white24 : Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: darkMode ? Colors.white24 : Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: darkMode ? Colors.tealAccent : Colors.teal),
        ),
        prefixIcon: Icon(icon, color: darkMode ? Colors.white70 : Colors.black),
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: darkMode ? Colors.white : Colors.black),
      validator: (value) => value!.isEmpty ? 'Please enter your $label' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        return Scaffold(
          backgroundColor: darkMode ? Colors.grey[900] : Colors.white,
          appBar: AppBar(
            title: Text('Profile'),
            backgroundColor: darkMode ? Colors.grey[900] : Colors.white,
            iconTheme: IconThemeData(color: darkMode ? Colors.grey : Colors.black),
            titleTextStyle: TextStyle(
              color: darkMode ? Colors.white : Colors.black,
              fontSize: screenWidth * 0.05, // 5% of screen width
              fontWeight: FontWeight.w400,
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04), // 4% of screen width
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Profile Image Section
                          Center(
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: screenWidth * 0.2, // 20% of screen width
                                  backgroundImage: _profileImageUrl != null
                                      ? AssetImage(_profileImageUrl!)
                                      : AssetImage("assets/default_profile.png"),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _chooseProfileImage,
                                    child: CircleAvatar(
                                      radius: screenWidth * 0.05, // 5% of screen width
                                      backgroundColor: darkMode ? Colors.grey[700] : Colors.teal,
                                      child: Icon(Icons.edit, color: Colors.white, size: screenWidth * 0.05), // 5% of screen width
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.05), // 5% of screen height

                          // Name Field
                          _buildTextField(_nameController, 'Name', Icons.person, darkMode),
                          SizedBox(height: screenHeight * 0.02), // 2% of screen height

                          // Gender Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              labelStyle: TextStyle(
                                fontSize: screenWidth * 0.04, // 4% of screen width
                                color: darkMode ? Colors.white70 : Colors.black,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(screenWidth * 0.06), // 6% of screen width
                                borderSide: BorderSide(
                                  color: darkMode ? Colors.white24 : Colors.grey,
                                ),
                              ),
                              prefixIcon: Icon(Icons.person_outline, color: darkMode ? Colors.white70 : Colors.black),
                            ),
                            dropdownColor: darkMode ? Colors.grey[800] : Colors.grey[50],
                            items: ['Male', 'Female', 'Other']
                                .map((gender) => DropdownMenuItem(
                                      value: gender,
                                      child: Text(
                                        gender,
                                        style: TextStyle(color: darkMode ? Colors.white : Colors.black),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                            validator: (value) => value == null ? 'Please select your gender' : null,
                          ),
                          SizedBox(height: screenHeight * 0.02), // 2% of screen height

                          // Age Field
                          _buildTextField(_ageController, 'Age', Icons.calendar_today, darkMode, isNumber: true),
                          SizedBox(height: screenHeight * 0.02), // 2% of screen height

                          // Weight & Height Fields
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(_weightController, 'Weight (kg)', Icons.monitor_weight, darkMode, isNumber: true),
                              ),
                              SizedBox(width: screenWidth * 0.02), // 2% of screen width
                              Expanded(
                                child: _buildTextField(_heightController, 'Height (cm)', Icons.height, darkMode, isNumber: true),
                              ),
                            ],
                          ),
                          SizedBox(height: screenHeight * 0.05), // 5% of screen height

                          // Save Button
                          _isSubmitting
                              ? CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _updateProfile,
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: darkMode ? Colors.grey[700] : Colors.teal,
                                    fixedSize: Size(screenWidth * 0.8, screenHeight * 0.07), // 80% of screen width, 6% of screen height
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50), // 6% of screen width
                                    ),
                                  ),
                                  child: Text(
                                    'Save',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.045, // 4.5% of screen width
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}