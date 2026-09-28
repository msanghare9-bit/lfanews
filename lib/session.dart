import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class Editeur {
  const Editeur(this.uid, this.nom, this.role, {this.niveaux = const [], this.matieres = const []});
  final String uid;
  final String nom;
  final String role;
  /// Pour un professeur : les niveaux et matières qu'il a le droit d'ajouter.
  /// Vides pour l'administrateur, qui n'a pas cette limite.
  final List<String> niveaux;
  final List<String> matieres;
  bool get estAdmin => role == 'admin';
  bool get peutCours => role == 'admin' || role == 'professeur';
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
      List<String> lst(String champ) =>
          (m[champ] is List) ? (m[champ] as List).map((e) => e.toString()).toList() : <String>[];
      return Editeur(
        uid,
        (m['nom'] ?? '').toString(),
        (m['role'] ?? 'eleve').toString(),
        niveaux: lst('niveaux'),
        matieres: lst('matieres'),
      );
    } catch (_) {
      return null;
    }
  }
}
