import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'database_service_interface.dart';

class WebDatabaseService implements AppDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> init() async {
    // No initialization required for Firestore web
  }

  @override
  Future<User> createUser(User user) async {
    final docUser = _firestore.collection('users').doc(user.email);
    await docUser.set(user.toMap());
    return user;
  }

  @override
  Future<User?> getUser(String email, String password) async {
    final docUser = await _firestore.collection('users').doc(email).get();
    if (docUser.exists) {
      final user = User.fromMap(docUser.data()!);
      if (user.password == password) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<User?> getUserByEmail(String email) async {
    final docUser = await _firestore.collection('users').doc(email).get();
    if (docUser.exists) {
      return User.fromMap(docUser.data()!);
    }
    return null;
  }

  @override
  Future<User> updateUser(User user) async {
    final docUser = _firestore.collection('users').doc(user.email);
    await docUser.update(user.toMap());
    return user;
  }

  @override
  Future<int> insertRoute({
    required String name,
    required List<LatLng> points,
    int? userId,
  }) async {
    await _firestore.collection('routes').add({
      'name': name,
      'points': points.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
    });
    // Firestore uses string IDs, so we lose the integer ID from sqflite.
    // This is a limitation of the current design.
    if (userId != null) {
      await insertUserRoute(userId, 0); // Placeholder ID
    }
    return 0; // Placeholder ID
  }

  @override
  Future<AppRoute?> getRouteById(int routeId) async {
    // This is not directly translatable as Firestore uses string IDs.
    // This would require a different approach, e.g., querying by a unique field.
    return null;
  }

  @override
  Future<List<AppRoute>> getSavedRoutesByUser(int userId) async {
    // This requires a more complex query that is not directly supported by this model.
    return [];
  }

  @override
  Future<void> deleteSavedRoute(int routeId) async {
    // Not implemented
  }

  @override
  Future<void> insertUserRoute(int userId, int routeId) async {
    // Not implemented
  }

  @override
  Future<List<Area>> getAreas() async {
    final snapshot = await _firestore.collection('areas').get();
    return snapshot.docs.map((doc) => Area.fromMap(doc.data())).toList();
  }

  @override
  Future<List<AppRoute>> getAreaRoutes(int areaId) async {
    // This requires a more complex query.
    return [];
  }

  @override
  Future<void> insertCrowdReport(CrowdReport report) async {
    await _firestore.collection('crowd_reports').add(report.toMap());
  }

  @override
  Future<List<CrowdReport>> getCrowdReports(int areaId) async {
    final snapshot = await _firestore
        .collection('crowd_reports')
        .where('area_id', isEqualTo: areaId)
        .get();
    return snapshot.docs.map((doc) => CrowdReport.fromMap(doc.data())).toList();
  }
}

AppDatabaseService getDatabaseService() => WebDatabaseService();
