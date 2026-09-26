import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'images.dart';
import 'modeles.dart';
import 'notifs.dart';
import 'session.dart';

final _db = FirebaseFirestore.instance;

/// Envoie un lot d'écritures. Renvoie false si la connexion manque :
/// les données partiront toutes seules quand le réseau reviendra.
Future<bool> _envoyer(WriteBatch lot) async {
  try {
    await lot.commit().timeout(const Duration(seconds: 12));
    return true;
  } on TimeoutException {
    return false;
  }
}

Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _photosDocs(
    DocumentReference<Map<String, dynamic>> ref) async {
  final q = await ref.collection('photos').get();
  final docs = q.docs.toList()
    ..sort((a, b) => (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0));
  return docs;
}

Future<List<Uint8List>> chargerPhotos(Article a) async {
  final docs = await _photosDocs(a.ref);
  return docs
      .map((d) => (d.data()['data'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .map(base64Decode)
      .toList();
}

/// Crée ou modifie un article. [photos] vaut null si les photos n'ont pas changé.
Future<bool> enregistrer({
  required Editeur ed,
  Article? existant,
  required Map<String, dynamic> champs,
  List<Uint8List>? photos,
  int anciennes = 0,
}) async {
  final col = existant?.collection ?? (ed.estAdmin ? 'articles' : 'propositions');
  final ref = existant == null ? _db.collection(col).doc() : _db.collection(col).doc(existant.id);
  final data = Map<String, dynamic>.from(champs);
  if (photos != null) {
    data['nbPhotos'] = photos.length;
    data['vignette'] = photos.isEmpty ? '' : await compute(vignetteDe, photos.first);
  }
  final lot = _db.batch();
  if (existant == null) {
    data.addAll({
      'auteurId': ed.uid,
      'auteurNom': ed.nom,
      'date': FieldValue.serverTimestamp(),
      'notifie': false,
    });
    lot.set(ref, data);
  } else {
    lot.update(ref, data);
  }
  if (photos != null) {
    for (var i = 0; i < photos.length; i++) {
      lot.set(ref.collection('photos').doc('$i'), {'data': base64Encode(photos[i])});
    }
    for (var i = photos.length; i < anciennes; i++) {
      lot.delete(ref.collection('photos').doc('$i'));
    }
  }
  final ok = await _envoyer(lot);
  if (existant == null && col == 'articles') declencherNotification();
  return ok;
}

/// L'administrateur publie l'article proposé par un élève.
Future<bool> publierProposition(Article p) async {
  final src = _db.collection('propositions').doc(p.id);
  final dst = _db.collection('articles').doc(p.id);
  final snap = await src.get();
  final data = Map<String, dynamic>.from(snap.data() ?? {});
  data['date'] = FieldValue.serverTimestamp();
  data['notifie'] = false;
  final photos = await _photosDocs(src);
  final lot = _db.batch();
  lot.set(dst, data);
  for (final ph in photos) {
    lot.set(dst.collection('photos').doc(ph.id), ph.data());
    lot.delete(ph.reference);
  }
  lot.delete(src);
  final ok = await _envoyer(lot);
  declencherNotification();
  return ok;
}

Future<bool> supprimer(Article a) async {
  final photos = await _photosDocs(a.ref);
  final lot = _db.batch();
  for (final ph in photos) {
    lot.delete(ph.reference);
  }
  lot.delete(a.ref);
  return _envoyer(lot);
}

Future<bool> modifierChamp(Article a, String champ, Object valeur) async {
  final lot = _db.batch()..update(a.ref, {champ: valeur});
  return _envoyer(lot);
}
