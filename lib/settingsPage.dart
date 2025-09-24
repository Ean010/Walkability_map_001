import 'package:flutter/material.dart';
import 'models.dart';

class SettingsPage extends StatefulWidget {
  final User? user;
  const SettingsPage({Key? key, this.user}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          _buildSettingsItem('help', Icons.help_outline, _showHelpDialog),
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
          _buildSettingsItem('about', Icons.info_outline, _showAboutDialog),
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
          _buildSettingsItem('notifications', Icons.notifications_outlined, _navigateToNotifications),
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      leading: Icon(icon, size: 24),
      onTap: onTap,
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help'),
        content: const Text('This is the help section. Here you can find information about how to use the app.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Crowd Navigator'),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 8),
            Text('An app to help you navigate through crowded areas.'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _navigateToNotifications() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationSettingsPage()));
  }
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _pushNotifications = true;
  bool _crowdAlerts = true;
  bool _routeUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('notifications', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Push Notifications'),
            value: _pushNotifications,
            onChanged: (value) => setState(() {
              _pushNotifications = value;
              if (!value) _crowdAlerts = _routeUpdates = false;
            }),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Crowd Alerts'),
            value: _crowdAlerts && _pushNotifications,
            onChanged: _pushNotifications ? (value) => setState(() => _crowdAlerts = value) : null,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Route Updates'),
            value: _routeUpdates && _pushNotifications,
            onChanged: _pushNotifications ? (value) => setState(() => _routeUpdates = value) : null,
          ),
        ],
      ),
    );
  }
}