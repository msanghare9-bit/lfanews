import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'ecrans/accueil.dart';
import 'firebase_options.dart';
import 'notifs.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets.dart';

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
      home: const Ouverture(),
    );
  }
}

/// Écran d'ouverture : le logo et le nom du lycée, une seconde.
class Ouverture extends StatefulWidget {
  const Ouverture({super.key});

  @override
  State<Ouverture> createState() => _OuvertureState();
}

class _OuvertureState extends State<Ouverture> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Accueil(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoLfa(taille: 120),
            const SizedBox(height: 18),
            Text('LFA NEWS', style: titre(34, couleur: vert)),
            const SizedBox(height: 6),
            const Text('Lycée Franco-Arabe de Kébémer', style: TextStyle(fontSize: 16, color: gris)),
          ],
        ),
      ),
    );
  }
}
