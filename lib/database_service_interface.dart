import 'models.dart';
import 'package:latlong2/latlong.dart';

abstract class AppDatabaseService {
  Future<void> init();
  Future<User> createUser(User user);
  Future<User?> getUser(String email, String password);
  Future<User?> getUserByEmail(String email);
  Future<User> updateUser(User user);
  Future<int> insertRoute({
    required String name,
    required List<LatLng> points,
    int? userId,
  });
  Future<AppRoute?> getRouteById(int routeId);
  Future<List<AppRoute>> getSavedRoutesByUser(int userId);
  Future<void> deleteSavedRoute(int routeId);
  Future<void> insertUserRoute(int userId, int routeId);

  Future<List<Area>> getAreas();
  Future<List<AppRoute>> getAreaRoutes(int areaId);

  Future<void> insertCrowdReport(CrowdReport report);
  Future<List<CrowdReport>> getCrowdReports(int areaId);
}
