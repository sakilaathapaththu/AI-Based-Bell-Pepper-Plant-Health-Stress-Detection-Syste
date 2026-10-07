import 'package:flutter/material.dart';
import 'package:bell_pepper_app/app.dart';
import 'package:bell_pepper_app/config/firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initialize();
  runApp(const PepperCareApp());
}
