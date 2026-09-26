import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'images.dart';
import 'modeles.dart';
import 'notifs.dart';
import 'session.dart';

final _db = FirebaseFirestore.instance;
final directs = _db.collection('directs');

Stream<List<Direct>> directsEnCours() => directs
    .where('enCours', isEqualTo: true)
    .snapshots()
    .map((q) => q.docs.map(Direct.fromDoc).toList()..sort((a, b) => b.debut.compareTo(a.debut)));

Future<String> lancerDirect(Editeur ed, String titre, String equipeA, String equipeB) async {
  final ref = directs.doc();
  unawaited(ref.set({
    'titre': titre,
    'equipeA': equipeA,
    'equipeB': equipeB,
    'scoreA': 0,
    'scoreB': 0,
    'enCours': true,
    'debut': FieldValue.serverTimestamp(),
    'auteurId': ed.uid,
    'auteurNom': ed.nom,
    'notifie': false,
  }).then((_) => declencherNotification()).catchError((_) {}));
  return ref.id;
}

Future<void> publierMessage(Editeur ed, String directId, String texte, Uint8List? photo) async {
  final data = <String, dynamic>{
    'texte': texte,
    'photo': photo == null ? '' : await compute(reduire, (photo, 900)),
    'date': FieldValue.serverTimestamp(),
    'auteurId': ed.uid,
    'auteurNom': ed.nom,
  };
  await directs.doc(directId).collection('messages').add(data).timeout(
        const Duration(seconds: 12),
        onTimeout: () => directs.doc(directId).collection('messages').doc(),
      );
}

void changerScore(String directId, String champ, int delta) {
  unawaited(directs.doc(directId).update({champ: FieldValue.increment(delta)}).catchError((_) {}));
}

void supprimerMessage(String directId, String messageId) {
  unawaited(directs.doc(directId).collection('messages').doc(messageId).delete().catchError((_) {}));
}

/// Termine le direct et le range comme article dans la rubrique choisie.
Future<void> terminerDirect(Editeur ed, Direct d, String categorie) async {
  final q = await directs.doc(d.id).collection('messages').orderBy('date').get();
  final messages = q.docs.map(MessageDirect.fromDoc).toList();
  final heure = DateFormat('HH:mm');
  final lignes = <String>[
    if (d.estMatch) 'Score final : ${d.equipeA} ${d.scoreA} – ${d.scoreB} ${d.equipeB}',
    for (final m in messages)
      if (m.texte.isNotEmpty) '${heure.format(m.date)}  ${m.texte}',
  ];
  final photo = messages.lastWhere((m) => m.photo.isNotEmpty,
      orElse: () => MessageDirect('', '', '', DateTime.now(), '', ''));
  final lot = _db.batch();
  lot.update(directs.doc(d.id), {'enCours': false, 'fin': FieldValue.serverTimestamp()});
  lot.set(_db.collection('articles').doc(d.id), {
    'titre': d.titre,
    'texte': lignes.join('\n\n'),
    'categorie': categorie,
    'vignette': photo.photo.isEmpty ? '' : await compute(reduire, (photo.octets!, 480)),
    'nbPhotos': 0,
    'auteurId': ed.uid,
    'auteurNom': ed.nom,
    'date': FieldValue.serverTimestamp(),
    'epingle': false,
    'urgent': false,
    'notifie': true,
    'personne': '',
    'fonction': '',
    'citation': '',
    'qr': <Map<String, dynamic>>[],
    'directId': d.id,
  });
  await lot.commit().timeout(const Duration(seconds: 12), onTimeout: () {});
}
