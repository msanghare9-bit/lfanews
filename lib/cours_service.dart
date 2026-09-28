import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'modeles.dart';

final _cours = FirebaseFirestore.instance.collection('cours');

const tailleMaxPdfOctets = 3 * 1024 * 1024; // 3 Mo
const _tailleMorceauPdf = 700000; // caractères base64 par morceau

/// Enregistre le PDF d'un cours, en le découpant comme pour l'émission audio.
Future<void> enregistrerPdf(String coursId, Uint8List pdf, String nom) async {
  final b64 = base64Encode(pdf);
  final n = (b64.length / _tailleMorceauPdf).ceil();
  final lot = FirebaseFirestore.instance.batch();
  lot.update(_cours.doc(coursId), {'pdfNom': nom, 'nbMorceauxPdf': n});
  for (var i = 0; i < n; i++) {
    lot.set(_cours.doc(coursId).collection('pdf').doc('$i'),
        {'data': b64.substring(i * _tailleMorceauPdf, min((i + 1) * _tailleMorceauPdf, b64.length))});
  }
  await lot.commit().timeout(const Duration(seconds: 60), onTimeout: () {});
}

/// Retire le PDF d'un cours (par exemple pour le remplacer).
Future<void> retirerPdf(String coursId, int ancienNbMorceaux) async {
  final lot = FirebaseFirestore.instance.batch();
  lot.update(_cours.doc(coursId), {'pdfNom': '', 'nbMorceauxPdf': 0});
  for (var i = 0; i < ancienNbMorceaux; i++) {
    lot.delete(_cours.doc(coursId).collection('pdf').doc('$i'));
  }
  await lot.commit().timeout(const Duration(seconds: 30), onTimeout: () {});
}

final Map<String, Uint8List> _cachePdf = {};

Future<Uint8List> chargerPdf(Cours c) async {
  final deja = _cachePdf[c.id];
  if (deja != null) return deja;
  final q = await _cours.doc(c.id).collection('pdf').get();
  final docs = q.docs.toList()..sort((a, b) => (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0));
  if (docs.length < c.nbMorceauxPdf) {
    throw Exception('Document incomplet, réessayez dans un instant.');
  }
  final sb = StringBuffer();
  for (final d in docs) {
    sb.write((d.data()['data'] ?? '').toString());
  }
  final octets = base64Decode(sb.toString());
  _cachePdf[c.id] = octets;
  return octets;
}
