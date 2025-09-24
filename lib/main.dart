import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'main_page.dart'; // Import the MainPage
import 'models.dart';
import 'database_service.dart';
import 'auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print("Starting dotenv load");
    await dotenv.load(fileName: ".env");
    print('BESTTIME_API_KEY: ${dotenv.env['BESTTIME_API_KEY']}');
    print('FOURSQUARE_API_KEY: ${dotenv.env['FOURSQUARE_API_KEY']}');
    print('GOOGLE_MAPS_API_KEY: ${dotenv.env['GOOGLE_MAPS_API_KEY']}');



    print("Starting Firebase init");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized");

    runApp(const MyApp());
  } catch (e) {
    print("Initialization error: $e");
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text("Initialization failed: $e")),
      ),
    ));
  }
}



class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigation App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
      routes: {
        // '/': (context) => const LoginPage(),
        '/map': (context) => const MainPage(user: null),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

