import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'ecrans/article.dart';
import 'modeles.dart';

Future<void> initNotifications() async {
  try {
    final m = FirebaseMessaging.instance;
    await m.requestPermission();
    FirebaseMessaging.onMessageOpenedApp.listen(_ouvrir);
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      messengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(n.body ?? n.title ?? 'Nouvel article'),
        action: SnackBarAction(label: 'Lire', onPressed: () => _ouvrir(msg)),
      ));
    });
    final initial = await m.getInitialMessage();
    if (initial != null) _ouvrir(initial);
    await m.subscribeToTopic('tous');
  } catch (_) {
    // Sans connexion, l'abonnement sera retenté au prochain lancement.
  }
}

Future<void> _ouvrir(RemoteMessage msg) async {
  final id = msg.data['articleId'];
  if (id is! String || id.isEmpty) return;
  try {
    final d = await FirebaseFirestore.instance.collection('articles').doc(id).get();
    if (!d.exists) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => PageArticle(article: Article.fromDoc(d))),
    );
  } catch (_) {}
}

/// Demande à GitHub d'envoyer tout de suite les notifications en attente.
Future<void> declencherNotification() async {
  try {
    final d = await FirebaseFirestore.instance.collection('config').doc('github').get();
    final token = d.data()?['token'];
    if (token is! String || token.isEmpty) return;
    await http.post(
      Uri.parse('https://api.github.com/repos/msanghare9-bit/lfanews/actions/workflows/notifier.yml/dispatches'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
      },
      body: jsonEncode({'ref': 'main'}),
    );
  } catch (_) {}
}
