import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'ecrans/accueil.dart';
import 'firebase_options.dart';
import 'notifs.dart';
import 'session.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  await initializeDateFormatting('fr_FR');
  Session.instance.demarrer();
  runApp(const LfaNewsApp());
  initNotifications();
}

class LfaNewsApp extends StatelessWidget {
  const LfaNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LFANEWS',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: lfaTheme(),
      home: const Accueil(),
    );
  }
}
