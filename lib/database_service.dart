import 'database_service_interface.dart';
import 'database_service_stub.dart'
    if (dart.library.io) 'database_service_mobile.dart'
    if (dart.library.html) 'database_service_web.dart';

export 'database_service_interface.dart';

/// A global instance of the database service.
///
/// The actual implementation is determined at compile time through conditional imports.
/// It will be [MobileDatabaseService] on mobile and [WebDatabaseService] on the web.
final AppDatabaseService databaseService = getDatabaseService();