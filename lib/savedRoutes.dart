import 'package:flutter/material.dart';
import 'models.dart' as models;
import 'database_service.dart';

class SavedRoutesPage extends StatefulWidget {
  final models.User? user;
  const SavedRoutesPage({super.key, this.user});

  @override
  State<SavedRoutesPage> createState() => _SavedRoutesPageState();
}

class _SavedRoutesPageState extends State<SavedRoutesPage> {
  List<models.AppRoute> _savedRoutes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSavedRoutes();
  }

  Future<void> _fetchSavedRoutes() async {
    if (widget.user?.userID == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      _savedRoutes = await databaseService.getSavedRoutesByUser(widget.user!.userID!);
    } catch (e) {
      debugPrint('Error fetching saved routes: $e');
      if (mounted) _showSnackBar('Failed to load saved routes: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteRoute(int routeID) async {
    if (widget.user?.userID == null) return;
    try {
      await databaseService.deleteSavedRoute(routeID);
      if (mounted) _showSnackBar('Route deleted successfully');
      await _fetchSavedRoutes(); // Refresh the list
    } catch (e) {
      debugPrint('Error deleting route: $e');
      if (mounted) _showSnackBar('Failed to delete route: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Routes', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.user == null
              ? const Center(child: Text('Please login to view saved routes'))
              : _savedRoutes.isEmpty
                  ? const Center(child: Text('No saved routes found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _savedRoutes.length,
                      itemBuilder: (context, index) => _buildRouteItem(_savedRoutes[index]),
                    ),
    );
  }

  Widget _buildRouteItem(models.AppRoute route) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Route ${route.routeID}',
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRoute(route.routeID),
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('From: ${route.startPoint}'),
            const SizedBox(height: 4),
            Text('To: ${route.endPoint}'),
            const SizedBox(height: 4),
            Text('Distance: ${route.distance.toStringAsFixed(1)} km'),
            if (route.estimatedTime != null) Text('Estimated Time: ${route.estimatedTime!}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showRouteDialog(route),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteDialog(models.AppRoute route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Route ${route.routeID} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${route.startPoint}'),
            Text('To: ${route.endPoint}'),
            Text('Distance: ${route.distance.toStringAsFixed(1)} km'),
            if (route.estimatedTime != null) Text('Estimated Time: ${route.estimatedTime!}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, route); // Return route to the previous screen
            },
            child: const Text('Show on Map'),
          ),
        ],
      ),
    );
  }
}