import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class Editeur {
  const Editeur(this.uid, this.nom, this.role);
  final String uid;
  final String nom;
  final String role;
  bool get estAdmin => role == 'admin';
}

class Session {
  Session._();
  static final instance = Session._();

  final editeur = ValueNotifier<Editeur?>(null);

  void demarrer() {
    FirebaseAuth.instance.authStateChanges().listen((u) async {
      if (u == null) {
        editeur.value = null;
        return;
      }
      editeur.value = await chargerEditeur(u.uid);
    });
  }

  static Future<Editeur?> chargerEditeur(String uid) async {
    try {
      final d = await FirebaseFirestore.instance.collection('editeurs').doc(uid).get();
      if (!d.exists) return null;
      final m = d.data()!;
      return Editeur(uid, (m['nom'] ?? '').toString(), (m['role'] ?? 'eleve').toString());
    } catch (_) {
      return null;
    }
  }
}
