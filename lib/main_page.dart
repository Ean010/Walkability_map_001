import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as latlong show LatLngBounds;
import 'profile.dart';
import 'models.dart' as models;
import 'settingsPage.dart';
import 'savedRoutes.dart';
//import 'crowd_indicator.dart';
import 'database_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'package:flutter/foundation.dart';

class MainPage extends StatefulWidget {
  final models.User? user;
  final String? hereMapsApiKey, bestTimeApiKeyPrivate, bestTimeApiKeyPublic;
  
  const MainPage({Key? key, this.user, this.hereMapsApiKey, this.bestTimeApiKeyPrivate, this.bestTimeApiKeyPublic}) : super(key: key);
  
  @override
  State<MainPage> createState() => _MapPageState();
  
}

class _MapPageState extends State<MainPage> {
  Timer? _debounce, _mapMoveDebounce;
  final _fromController = TextEditingController(), _toController = TextEditingController(), _routeNameController = TextEditingController();
  late ApiService _apiService;
  StreamSubscription<Position>? _positionStream;
  List<Map<String, String>> _suggestions = [];
  List<Map<String, dynamic>> _crowdData = [];

  // Add these two new state variables as discussed in the previous answer
  List<Polyline> _overpassFootways = [];
  bool _isOverpassLoading = false;
  Timer? _overpassDebounce; // Add this

  bool _isFromActive = true, _isExpanded = false, _showEtaPanel = false, _isNavigationMode = false,
         _isLocationLoading = true, _isRouting = false, _isCrowdLoading = false, _isRequestingPermission = false;

  final MapController _mapController = MapController();
  latlong.LatLng _currentPos = latlong.LatLng(37.7749, -122.4194);
  latlong.LatLng? _fromLoc, _toLoc;
  int? _routeETASeconds;
  double? _routeDistanceKm;
  List<latlong.LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(hereMapsApiKey: widget.hereMapsApiKey, bestTimeApiKeyPrivate: widget.bestTimeApiKeyPrivate, bestTimeApiKeyPublic: widget.bestTimeApiKeyPublic);
    _getCurrentLocation();
    _mapController.mapEventStream.listen((e) {
      if (e is MapEventMoveEnd) {
        _onMapMoved(); // For crowd data
        _onMapMoveEndForOverpass(); // For Overpass data - NEW
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCrowdDataForCurrentView();
      _fetchOverpassFootwaysForCurrentView(); // Initial call for Overpass data - NEW
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapMoveDebounce?.cancel();
    _overpassDebounce?.cancel(); // Cancel overpass debounce timer - NEW
    [_fromController, _toController, _routeNameController].forEach((c) => c.dispose());
    _positionStream?.cancel();
    super.dispose();
  }

  void _onMapMoved() {
    _mapMoveDebounce?.cancel();
    _mapMoveDebounce = Timer(const Duration(milliseconds: 500), _fetchCrowdDataForCurrentView);
  }

  // NEW METHOD: Debounced call for Overpass data
  void _onMapMoveEndForOverpass() {
    _overpassDebounce?.cancel();
    _overpassDebounce = Timer(const Duration(milliseconds: 700), () { // Slightly longer debounce
      _fetchOverpassFootwaysForCurrentView();
    });
  }


  Future<void> _fetchCrowdDataForCurrentView() async {
    if (!mounted || _mapController.camera.visibleBounds == null) return;
    final center = _mapController.camera.center;
    final zoom = _mapController.camera.zoom;
    final radiusMeters = zoom >= 16 ? 1000 : zoom >= 14 ? 2500 : zoom >= 12 ? 5000 : 10000;

    setState(() => _isCrowdLoading = true);
    try {
      final data = await _apiService.fetchCrowdDataForMap(centerLat: center.latitude, centerLng: center.longitude, radiusMeters: radiusMeters);
      if (mounted) setState(() { _crowdData = data; _isCrowdLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isCrowdLoading = false); _showSnackBar('Error loading crowd data: $e'); }
    }
  }

  // --- PLACE THE _fetchOverpassFootwaysForCurrentView() METHOD HERE ---
  // This is the entire block of code you provided in your question
  Future<void> _fetchOverpassFootwaysForCurrentView() async {
    if (!mounted || _mapController.camera.visibleBounds == null) return;

    final bounds = _mapController.camera.visibleBounds!;
    final double south = bounds.south;
    final double west = bounds.west;
    final double north = bounds.north;
    final double east = bounds.east;

    // A check to prevent overly broad or zoomed-out queries
    // Adjust these zoom levels as per your performance/data needs
    if (_mapController.camera.zoom < 14) { // Only fetch footways at zoom level 14 or higher
      if (mounted) setState(() { _overpassFootways = []; _isOverpassLoading = false; });
      return;
    }

    setState(() => _isOverpassLoading = true);

    // Overpass QL query to get footways (sidewalks/paths) within the current bounding box
    final query = '''
      [out:json];
      way["footway"~"^(footway|sidewalk)"]($south,$west,$north,$east);
      (._;>;);
      out skel qt;
    ''';
    // Using "~" for regex match to include both "footway" and "sidewalk" values
    // (._;>;); is shorthand for recursing up from ways to nodes and then printing all

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'];

        final Map<int, latlong.LatLng> nodes = {};
        for (var el in elements) {
          if (el['type'] == 'node') {
            nodes[el['id']] = latlong.LatLng(el['lat'], el['lon']);
          }
        }

        List<Polyline> lines = [];
        for (var el in elements) {
          if (el['type'] == 'way') {
            List<latlong.LatLng> points = [];
            for (var nodeId in el['nodes']) {
              if (nodes.containsKey(nodeId)) {
                points.add(nodes[nodeId]!);
              }
            }
            if (points.length >= 2) {
              lines.add(
                Polyline(
                  points: points,
                  color: Colors.purple, // Keep your distinct color
                  strokeWidth: 4.0,
                ),
              );
            }
          }
        }
        if (mounted) {
          setState(() {
            _overpassFootways = lines; // Update the list with new data
            _isOverpassLoading = false;
          });
        }
      } else {
        if (mounted) {
          print("Failed to load Overpass data: ${response.statusCode}, Body: ${response.body}");
          setState(() => _isOverpassLoading = false);
          _showSnackBar("Failed to load footways: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching Overpass data: $e");
        setState(() => _isOverpassLoading = false);
        _showSnackBar("Error fetching footways: $e");
      }
    }
  }
  // --- END OF _fetchOverpassFootwaysForCurrentView() METHOD --

  void _onSearchChanged(String q, bool isFrom) {
    _debounce?.cancel();
    setState(() => _isFromActive = isFrom);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (q.length >= 3) _fetchSuggestions(q);
      else if (mounted) setState(() => _suggestions = []);
    });
  }

  Future<void> _fetchSuggestions(String q) async {
    try {
      final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/search?q=$q&format=json&limit=5&addressdetails=1'), headers: {'User-Agent': 'flutter_app'});
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body) as List;
        setState(() => _suggestions = data.map<Map<String, String>>((i) => {'display_name': i['display_name'], 'lat': i['lat'], 'lon': i['lon']}).toList());
      }
    } catch (e) {
      if (mounted) _showSnackBar('Search error: $e');
    }
  }

  Widget _suggestionsList() => Container(
    margin: const EdgeInsets.only(top: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
    child: ListView.builder(
      shrinkWrap: true, physics: const ClampingScrollPhysics(), itemCount: _suggestions.length,
      itemBuilder: (_, i) {
        final s = _suggestions[i];
        return ListTile(
          leading: const Icon(Icons.location_on, size: 20),
          title: Text(s['display_name'] ?? '', style: const TextStyle(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
          dense: true,
          onTap: () {
            final lat = double.parse(s['lat']!), lon = double.parse(s['lon']!);
            setState(() {
              if (_isFromActive) { _fromController.text = s['display_name'] ?? ''; _fromLoc = latlong.LatLng(lat, lon); }
              else { _toController.text = s['display_name'] ?? ''; _toLoc = latlong.LatLng(lat, lon); }
              _suggestions = [];
            });
          },
        );
      },
    ),
  );

  void _handleRoute() {
    if (_fromLoc == null || _toLoc == null || _fromController.text.trim().isEmpty || _toController.text.trim().isEmpty) {
      setState(() { _routePoints.clear(); _showEtaPanel = false; _routeETASeconds = null; _routeDistanceKm = null; });
      _showSnackBar('Select both start and end points');
      return;
    }
    _calculateRoute(_fromLoc!, _toLoc!);
  }

  Future<bool> _checkPermissions() async {
    if (!mounted || _isRequestingPermission) return false;
    _isRequestingPermission = true;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) { _showSnackBar('Location permissions denied'); return false; }
      }
      if (perm == LocationPermission.deniedForever) { _showSnackBar('Permissions permanently denied. Please enable them in app settings.'); await openAppSettings(); return false; }
      return true;
    } catch (e) {
      _showSnackBar('Error: $e'); return false;
    } finally {
      _isRequestingPermission = false;
    }
  }

  void _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLocationLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { _showSnackBar('Enable location services'); setState(() => _isLocationLoading = false); return; }
      if (!await _checkPermissions()) { setState(() => _isLocationLoading = false); return; }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      _currentPos = latlong.LatLng(pos.latitude, pos.longitude);
      _mapController.move(_currentPos, 15);
      _fetchCrowdDataForCurrentView();
    } catch (e) {
      _showSnackBar('Loc error: $e');
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _calculateRoute(latlong.LatLng start, latlong.LatLng end) async {
    setState(() => _isRouting = true);
    try {
      final data = await _apiService.getPedestrianRoute(latlong.LatLng(start.latitude, start.longitude), latlong.LatLng(end.latitude, end.longitude));
      if (!mounted) return;
      if (data['points'] != null && data['points'].isNotEmpty) {
        _routePoints = List<latlong.LatLng>.from(data['points'].map((p) => latlong.LatLng(p.latitude, p.longitude)));
        _routeETASeconds = data['duration'];
        _routeDistanceKm = data['distance'];
        setState(() { _showEtaPanel = true; _isExpanded = false; _isRouting = false; });
        _zoomToFit([start, end, ..._routePoints]);
      } else {
        _showSnackBar('No route found');
        setState(() => _isRouting = false);
      }
    } catch (e) {
      if (mounted) { _showSnackBar('Route error: $e'); setState(() => _isRouting = false); }
    }
  }

  void _zoomToFit(List<latlong.LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude, minLon = points.first.longitude, maxLon = points.first.longitude;
    for (var p in points) {
      minLat = math.min(minLat, p.latitude); maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude); maxLon = math.max(maxLon, p.longitude);
    }
    final bounds = latlong.LatLngBounds(latlong.LatLng(minLat, minLon), latlong.LatLng(maxLat, maxLon));
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  void _showSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _buildMap() => Column(children: [
    if (widget.user != null && !_isNavigationMode)
      Padding(padding: const EdgeInsets.all(8.0), child: Text('Welcome, ${widget.user!.name}!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    Expanded(child: FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPos, initialZoom: 15.0,
        onMapEvent: (e) { if (e.source == MapEventSource.onDrag || e.source == MapEventSource.doubleTap || e.source == MapEventSource.scrollWheel) _onMapMoved(); },
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'flutter_app'),
        if (_routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 5.0)]),
        if (_crowdData.isNotEmpty) MarkerLayer(markers: _crowdData.map(_buildCrowdMarker).toList()),
        if (_overpassFootways.isNotEmpty) PolylineLayer(polylines: _overpassFootways), //
      MarkerLayer(markers: [_createMarker(_currentPos), if (_fromLoc != null) _createFromMarker(_fromLoc!), if (_toLoc != null) _createToMarker(_toLoc!)]),
    ]
    ))
  ]);

  Marker _buildCrowdMarker(Map<String, dynamic> data) {
    final point = latlong.LatLng(data['location']['lat'], data['location']['lon']);
    final level = data['crowd_level'] as int;
    final colors = [Colors.green.shade300, Colors.lightGreen, Colors.yellow.shade700, Colors.orange, Colors.red];
    final color = level >= 1 && level <= 5 ? colors[level - 1] : Colors.grey;
    
    return Marker(
      point: point, width: 30, height: 30,
      child: Tooltip(
        message: '${data['name']}\nCrowd Level: $level',
        child: GestureDetector(
          onTap: () => _showPlaceDetailsPopup(data),
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.8), border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]),
            child: Center(child: Text(level.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ),
        ),
      ),
    );
  }

  Marker _createMarker(latlong.LatLng p) => Marker(point: p, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.blue, size: 40));
  Marker _createFromMarker(latlong.LatLng p) => Marker(point: p, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 40));
  Marker _createToMarker(latlong.LatLng p) => Marker(point: p, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40));

  void _showPlaceDetailsPopup(Map<String, dynamic> data) {
    final level = data['crowd_level'] as int;
    final descriptions = ['Very quiet - few people around', 'Quiet - some people around', 'Moderate - average crowd levels', 'Busy - many people around', 'Very busy - crowded'];
    final description = level >= 1 && level <= 5 ? descriptions[level - 1] : 'Unknown crowd level';
    final colors = [Colors.green, Colors.lightGreen, Colors.yellow, Colors.orange, Colors.red];
    final color = level >= 1 && level <= 5 ? colors[level - 1] : Colors.grey;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['name'] ?? 'Unknown Place'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.people, color: color, size: 20), const SizedBox(width: 8), Text('Crowd Level: $level/5')]),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 10),
          Text('Location: ${data['location']['lat'].toStringAsFixed(4)}, ${data['location']['lon'].toStringAsFixed(4)}'),
          if (data['description'] != null) ...[const SizedBox(height: 10), Text('Description: ${data['description']}')],
        ]),
        actions: [TextButton(child: const Text('Close'), onPressed: () => Navigator.of(context).pop())],
      ),
    );
  }

  Future<void> _saveRoute() async {
    if (_routePoints.isEmpty) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save Route'),
        content: TextField(controller: _routeNameController, decoration: const InputDecoration(hintText: 'Route name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await databaseService.insertRoute(name: _routeNameController.text, points: _routePoints, userId: widget.user?.userID);
                if (!mounted) return;
                Navigator.pop(context);
                _showSnackBar('Route saved');
              } catch (e) {
                if (mounted) _showSnackBar('Save error: $e');
              }
            },
            child: const Text('Save')
          )
        ],
      ));
  }

  void _startNavigation() async {
    if (!await _checkPermissions()) return;
    setState(() { _isNavigationMode = true; _showEtaPanel = false; });
    _positionStream = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5))
      .listen((pos) {
        if (mounted) setState(() { _currentPos = latlong.LatLng(pos.latitude, pos.longitude); _mapController.move(_currentPos, _mapController.camera.zoom); });
      }, onError: (e) { if (mounted) { _showSnackBar('Navigation error: $e'); _exitNavigation(); } });
    _showSnackBar('Navigation started');
  }

  void _exitNavigation() {
    _positionStream?.cancel();
    _positionStream = null;
    if (mounted) setState(() { _isNavigationMode = false; _showEtaPanel = true; });
  }

  String _formatDuration(int s) { final m = (s / 60).round(); return m < 60 ? '$m min' : '${m ~/ 60}h ${m % 60}m'; }
  String _formatDistance(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  Widget _buildEtaPanel() {
    if (!_showEtaPanel || _routeETASeconds == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Estimated time: ${_formatDuration(_routeETASeconds!)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (_routeDistanceKm != null) Text('Distance: ${_formatDistance(_routeDistanceKm!)}', style: const TextStyle(fontSize: 14, color: Colors.grey))
        ]),
        Row(children: [
          TextButton(onPressed: () => setState(() { _showEtaPanel = false; _isExpanded = true; _routePoints.clear(); _routeETASeconds = null; _routeDistanceKm = null; }), child: const Text('Back')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _startNavigation, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text('Go'))
        ])
      ]),
    );
  }

  Widget _buildNavigationHeader() => _isNavigationMode ? Container(
    padding: const EdgeInsets.all(12), color: Colors.blue,
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Navigation Active', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      TextButton(onPressed: _exitNavigation, child: const Text('Exit', style: TextStyle(color: Colors.white)))
    ])) : const SizedBox.shrink();

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Column(children: [
      Row(children: [
        if (_isExpanded) IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _isExpanded = false)),
        Expanded(child: _buildTextField(_fromController, 'From', true)),
        if (!_isExpanded) IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _isExpanded = true))
      ]),
      if (_isFromActive && _suggestions.isNotEmpty) _suggestionsList(),
      if (_isExpanded) ...[
        const SizedBox(height: 8),
        _buildTextField(_toController, 'To', false),
        if (!_isFromActive && _suggestions.isNotEmpty) _suggestionsList(),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _handleRoute, child: const Text('Find Route', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
      ]
    ]),
  );

  TextField _buildTextField(TextEditingController c, String hint, bool isFrom) => TextField(
    controller: c, onChanged: (v) => _onSearchChanged(v, isFrom), onTap: () => setState(() => _isExpanded = true),
    decoration: InputDecoration(
      hintText: hint, prefixIcon: const Icon(Icons.location_on),
      suffixIcon: IconButton(
        icon: const Icon(Icons.my_location, size: 20),
        onPressed: () async {
          if (!isFrom) { _showSnackBar('Current location only as "From"'); return; }
          setState(() => _isLocationLoading = true);
          try {
            if (!await _checkPermissions() || !await Geolocator.isLocationServiceEnabled()) { _showSnackBar('Enable location services'); return; }
            final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
            final userLoc = latlong.LatLng(pos.latitude, pos.longitude);
            setState(() { _currentPos = userLoc; _fromController.text = 'Current Location'; _fromLoc = userLoc; _mapController.move(userLoc, 15); });
          } catch (e) { _showSnackBar('Location error: $e'); }
          finally { setState(() => _isLocationLoading = false); }
        },
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
  );

  Widget _buildBottomNav() => Container(
    height: 60, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.grey, width: 0.5))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _navItem(Icons.person, 'profile', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user: widget.user)))),
      _navItem(Icons.bookmark, 'saved routes', () => widget.user?.userID != null ? _showSavedRoutes(widget.user!.userID!) : _showSnackBar('Login to view saved routes')),
      _navItem(Icons.settings, 'settings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(user: widget.user))))
    ]),
  );

  Widget _navItem(IconData icon, String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 24), Text(label, style: const TextStyle(fontSize: 12))]),
  );

  void _showSavedRoutes(int userId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SavedRoutesPage(user: widget.user))).then((r) {
      if (r != null && r is models.AppRoute) {
        _showSnackBar('Route from ${r.startPoint} to ${r.endPoint}');
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [
      _buildNavigationHeader(),
      if (!_isNavigationMode) _buildSearchBar(),
      if (!_isNavigationMode) _buildEtaPanel(),
      Expanded(child: Stack(children: [
        _buildMap(),
        Positioned(right: 16, bottom: 16, child: Column(children: [
          FloatingActionButton(mini: true, backgroundColor: Colors.white, onPressed: _getCurrentLocation, child: const Icon(Icons.my_location, color: Colors.black)),
          const SizedBox(height: 8),
          FloatingActionButton(mini: true, backgroundColor: Colors.white, onPressed: _saveRoute, child: const Icon(Icons.save, color: Colors.black))
        ])),
        if (_isLocationLoading || _isCrowdLoading || _isRouting) const Center(child: CircularProgressIndicator())
      ])),
      if (!_isNavigationMode) _buildBottomNav()
    ])),
  );
}