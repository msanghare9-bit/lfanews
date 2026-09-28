import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modeles.dart';
import 'notifs.dart';
import 'session.dart';

final _db = FirebaseFirestore.instance;
final emissions = _db.collection('emissions');

/// Limites pour rester dans la formule gratuite de Firebase.
const dureeMaxSecondes = 310; // 5 minutes, avec un peu de marge
const tailleMaxOctets = 3 * 1024 * 1024; // 3 Mo
const _tailleMorceau = 700000; // caractères base64 par morceau (limite Firestore : 1 Mo)

String typeAudio(String format) {
  switch (format.toLowerCase()) {
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
    case 'mp4':
    case 'aac':
      return 'audio/mp4';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
    case 'opus':
    case 'oga':
      return 'audio/ogg';
    default:
      return 'audio/mpeg';
  }
}

/// Permet à just_audio de lire un fichier qui est en mémoire.
class SourceOctets extends StreamAudioSource {
  SourceOctets(this.octets, this.type);
  final Uint8List octets;
  final String type;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= octets.length;
    return StreamAudioResponse(
      sourceLength: octets.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(octets.sublist(start, end)),
      contentType: type,
    );
  }
}

/// Durée du fichier, ou null s'il n'est pas lisible.
Future<Duration?> dureeDe(Uint8List octets, String format) async {
  final lecteur = AudioPlayer();
  try {
    await lecteur.setAudioSource(SourceOctets(octets, typeAudio(format)));
    return lecteur.duration;
  } catch (_) {
    return null;
  } finally {
    await lecteur.dispose();
  }
}

/// Publie une émission. Renvoie false si la connexion manque : l'envoi se terminera au retour du réseau.
Future<bool> creerEmission({
  required Editeur ed,
  required String titre,
  required DateTime debut,
  required Uint8List audio,
  required String format,
  required int duree,
  String couverture = '',
}) async {
  final b64 = base64Encode(audio);
  final ref = emissions.doc();
  final lot = _db.batch();
  final n = (b64.length / _tailleMorceau).ceil();
  lot.set(ref, {
    'titre': titre,
    'debut': Timestamp.fromDate(debut),
    'duree': duree,
    'nbMorceaux': n,
    'format': format,
    'couverture': couverture,
    'auteurId': ed.uid,
    'auteurNom': ed.nom,
    'notifie': false,
  });
  for (var i = 0; i < n; i++) {
    lot.set(ref.collection('morceaux').doc('$i'),
        {'data': b64.substring(i * _tailleMorceau, min((i + 1) * _tailleMorceau, b64.length))});
  }
  var ok = true;
  await lot.commit().timeout(const Duration(seconds: 90), onTimeout: () => ok = false);
  if (ok) declencherNotification();
  return ok;
}

Future<void> supprimerEmission(String id) async {
  final q = await emissions.doc(id).collection('morceaux').get();
  final lot = _db.batch();
  for (final m in q.docs) {
    lot.delete(m.reference);
  }
  lot.delete(emissions.doc(id));
  await lot.commit().timeout(const Duration(seconds: 20), onTimeout: () {});
}

final Map<String, Uint8List> _cache = {};

/// Reconstitue le fichier audio à partir de ses morceaux (gardé en mémoire ensuite).
Future<Uint8List> chargerAudio(Emission e) async {
  final deja = _cache[e.id];
  if (deja != null) return deja;
  final q = await emissions.doc(e.id).collection('morceaux').get();
  final docs = q.docs.toList()..sort((a, b) => (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0));
  if (docs.length < e.nbMorceaux) {
    throw Exception('Émission incomplète, réessayez dans un instant.');
  }
  final sb = StringBuffer();
  for (final d in docs) {
    sb.write((d.data()['data'] ?? '').toString());
  }
  final octets = base64Decode(sb.toString());
  _cache[e.id] = octets;
  return octets;
}

/// Une seule écoute comptée par téléphone.
Future<void> compterEcoute(String id) async {
  if (FirebaseAuth.instance.currentUser != null) return;
  try {
    final p = await SharedPreferences.getInstance();
    final deja = p.getStringList('emissions_ecoutees') ?? <String>[];
    if (deja.contains(id)) return;
    deja.add(id);
    await p.setStringList('emissions_ecoutees', deja);
    unawaited(_db
        .collection('stats')
        .doc('emission_$id')
        .set({'vues': FieldValue.increment(1)}, SetOptions(merge: true))
        .catchError((_) {}));
  } catch (_) {}
}

Future<String?> maReactionEmission(String id) async {
  final p = await SharedPreferences.getInstance();
  return p.getString('reaction_emi_$id');
}

Future<void> reagirEmission(String id, String? avant, String? apres) async {
  if (avant == apres) return;
  try {
    final p = await SharedPreferences.getInstance();
    if (apres == null) {
      await p.remove('reaction_emi_$id');
    } else {
      await p.setString('reaction_emi_$id', apres);
    }
  } catch (_) {}
  final maj = <String, dynamic>{};
  if (avant != null) maj['reactions.$avant'] = FieldValue.increment(-1);
  if (apres != null) maj['reactions.$apres'] = FieldValue.increment(1);
  if (maj.isNotEmpty) unawaited(emissions.doc(id).update(maj).catchError((_) {}));
}
