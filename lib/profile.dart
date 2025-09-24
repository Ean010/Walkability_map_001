import 'package:flutter/material.dart';
import 'models.dart';
import 'database_service.dart';

class ProfilePage extends StatefulWidget {
  final User? user;
  final Function(User)? onUserUpdated;

  const ProfilePage({Key? key, this.user, this.onUserUpdated}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    // Initialize _currentUser only if widget.user is not null
    if (widget.user != null) {
      _currentUser = widget.user!;
      _nameController.text = _currentUser.name;
      _emailController.text = _currentUser.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (widget.user == null) return;

    setState(() => _isLoading = true);

    try {
      final updatedUser = _currentUser.copyWith(
        name: _nameController.text,
        email: _emailController.text,
      );

      final updatedUserResult = await databaseService.updateUser(updatedUser);

      setState(() {
        _currentUser = updatedUserResult;
        _isEditing = false;
      });
      widget.onUserUpdated?.call(updatedUserResult);
      _showSnackBar('Profile updated successfully');
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false); // Ensure isLoading is reset
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing ? (_isLoading ? null : _updateProfile) : () => setState(() => _isEditing = true),
          ),
        ],
      ),
      body: widget.user == null
          ? const Center(child: Text('Please login to view profile'))
          : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade200,
            child: _currentUser.profilePhoto != null
                ? ClipOval(
                    child: Image.network(
                      _currentUser.profilePhoto!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.person, size: 60, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _buildInfoField('Name', _nameController, _currentUser.name),
          const SizedBox(height: 16),
          _buildInfoField('Email', _emailController, _currentUser.email,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, TextEditingController controller, String currentValue,
      {TextInputType keyboardType = TextInputType.text}) {
    return _isEditing
        ? TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            keyboardType: keyboardType,
          )
        : ListTile(
            title: Text(label),
            subtitle: Text(currentValue),
          );
  }
}