// models.dart - Database models based on the ERD diagram

// User Model
class User {
  final int? userID;
  final String name;
  final String email;
  final String password;
  final String? profilePhoto;

  User({
    this.userID,
    required this.name,
    required this.email,
    required this.password,
    this.profilePhoto,
  });

  User copyWith({
    int? userID,
    String? name,
    String? email,
    String? password,
    String? profilePhoto,
  }) {
    return User(
      userID: userID ?? this.userID,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      profilePhoto: profilePhoto ?? this.profilePhoto,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'name': name,
      'email': email,
      'password': password,
      'profile_photo': profilePhoto,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userID: map['userID'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
      profilePhoto: map['profile_photo'],
    );
  }
}

// Area Model
class Area {
  final int areaID;
  final String name;
  final String location;
  final int densityLevel;
  final String timestamp;

  Area({
    required this.areaID,
    required this.name,
    required this.location,
    required this.densityLevel,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'areaID': areaID,
      'name': name,
      'location': location,
      'densityLevel': densityLevel,
      'timeStamp': timestamp,
    };
  }

  factory Area.fromMap(Map<String, dynamic> map) {
    return Area(
      areaID: map['areaID'],
      name: map['name'],
      location: map['location'],
      densityLevel: map['densityLevel'],
      timestamp: map['timeStamp'],
    );
  }
}

// Route Model
class AppRoute {
  final int routeID;
  final String startPoint;
  final String endPoint;
  final double distance;
  
  final String? estimatedTime;

    AppRoute({
    required this.routeID,
    required this.startPoint,
    required this.endPoint,
    required this.distance,
    this.estimatedTime,
  });

  AppRoute copyWith({
    int? routeID,
    String? startPoint,
    String? endPoint,
    double? distance,
    String? estimatedTime,
  }) {
    return AppRoute(
      routeID: routeID ?? this.routeID,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      distance: distance ?? this.distance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routeID': routeID,
      'startPoint': startPoint,
      'endPoint': endPoint,
      'distance': distance,
      'estimatedTime': estimatedTime,
    };
  }

  factory AppRoute.fromMap(Map<String, dynamic> map) {
    return AppRoute(
      routeID: map['routeID'],
      startPoint: map['startPoint'],
      endPoint: map['endPoint'],
      distance: map['distance'],
      estimatedTime: map['estimatedTime'],
    );
  }
}

// CrowdReport Model
class CrowdReport {
  final int reportID;
  final int areaID;
  final String timestamp;
  final int densityLevel;

  CrowdReport({
    required this.reportID,
    required this.areaID,
    required this.timestamp,
    required this.densityLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'reportID': reportID,
      'areaID': areaID,
      'timeStamp': timestamp,
      'densityLevel': densityLevel,
    };
  }

  factory CrowdReport.fromMap(Map<String, dynamic> map) {
    return CrowdReport(
      reportID: map['reportID'],
      areaID: map['areaID'],
      timestamp: map['timeStamp'],
      densityLevel: map['densityLevel'],
    );
  }
}

// Junction table for User-Route (many-to-many relationship)
class UserRoute {
  final int userID;
  final int routeID;

  UserRoute({
    required this.userID,
    required this.routeID,
  });

  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'routeID': routeID,
    };
  }

  factory UserRoute.fromMap(Map<String, dynamic> map) {
    return UserRoute(
      userID: map['userID'],
      routeID: map['routeID'],
    );
  }
}

// Junction table for Area-Route (many-to-many relationship)
class AreaRoute {
  final int areaID;
  final int routeID;
  final String? bottleneckId;  // Optional bottleneck identifier from your ERD

  AreaRoute({
    required this.areaID,
    required this.routeID,
    this.bottleneckId,
  });

  Map<String, dynamic> toMap() {
    return {
      'areaID': areaID,
      'routeID': routeID,
      'bottleneck_id': bottleneckId,
    };
  }

  factory AreaRoute.fromMap(Map<String, dynamic> map) {
    return AreaRoute(
      areaID: map['areaID'],
      routeID: map['routeID'],
      bottleneckId: map['bottleneck_id'],
    );
  }
}

