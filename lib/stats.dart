import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _stats = FirebaseFirestore.instance.collection('stats');
final _reactions = FirebaseFirestore.instance.collection('reactions');
final _compteurs = FirebaseFirestore.instance.collection('compteurs').doc('app');

class Stat {
  const Stat(this.vues, this.lectures, [this.jaimepas = 0]);
  final int vues;
  final int lectures;
  final int jaimepas;
  int get taux => vues == 0 ? 0 : (lectures * 100 / vues).round();
}

int _n(Map<String, dynamic>? d, String k) => (d?[k] as num?)?.toInt() ?? 0;

Stat statDe(Map<String, dynamic>? d) => Stat(_n(d, 'vues'), _n(d, 'lectures'), _n(d, 'jaimepas'));

/// Chaque téléphone compte une seule fois par article.
/// Les membres de la rédaction ne sont pas comptés.
Future<void> _compter(String id, String champ, String cle) async {
  if (FirebaseAuth.instance.currentUser != null) return;
  try {
    final p = await SharedPreferences.getInstance();
    final deja = p.getStringList(cle) ?? <String>[];
    if (deja.contains(id)) return;
    deja.add(id);
    await p.setStringList(cle, deja);
    _ajouter(_stats, id, champ, 1);
  } catch (_) {}
}

void _ajouter(CollectionReference<Map<String, dynamic>> col, String id, String champ, int delta) {
  unawaited(col
      .doc(id)
      .set({champ: FieldValue.increment(delta)}, SetOptions(merge: true))
      .catchError((_) {}));
}

Future<void> compterVue(String id) => _compter(id, 'vues', 'articles_vus');
Future<void> compterLecture(String id) => _compter(id, 'lectures', 'articles_lus');

Stream<Stat> suivreStat(String id) => _stats.doc(id).snapshots().map((d) => statDe(d.data()));

Stream<int> suivreJaime(String id) =>
    _reactions.doc(id).snapshots().map((d) => _n(d.data(), 'jaime'));

/// Réaction enregistrée sur ce téléphone : 'aime', 'aimepas' ou null.
Future<String?> maReaction(String id) async {
  final p = await SharedPreferences.getInstance();
  return p.getString('reaction_$id');
}

Future<void> reagir(String id, String? avant, String? apres) async {
  if (avant == apres) return;
  try {
    final p = await SharedPreferences.getInstance();
    if (apres == null) {
      await p.remove('reaction_$id');
    } else {
      await p.setString('reaction_$id', apres);
    }
  } catch (_) {}
  if (avant == 'aime') _ajouter(_reactions, id, 'jaime', -1);
  if (avant == 'aimepas') _ajouter(_stats, id, 'jaimepas', -1);
  if (apres == 'aime') _ajouter(_reactions, id, 'jaime', 1);
  if (apres == 'aimepas') _ajouter(_stats, id, 'jaimepas', 1);
}

/// Toutes les statistiques, pour l'écran de la rédaction.
Future<(Map<String, Stat>, Map<String, int>)> chargerToutesStats() async {
  final s = await _stats.get();
  final r = await _reactions.get();
  return (
    {for (final d in s.docs) d.id: statDe(d.data())},
    {for (final d in r.docs) d.id: _n(d.data(), 'jaime')},
  );
}

/// Compte ce téléphone une seule fois, au tout premier lancement.
Future<void> compterInstallation() async {
  if (FirebaseAuth.instance.currentUser != null) return;
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('installation_comptee') ?? false) return;
    await p.setBool('installation_comptee', true);
    unawaited(_compteurs
        .set({'installations': FieldValue.increment(1)}, SetOptions(merge: true))
        .catchError((_) {}));
  } catch (_) {}
}

Future<int> nombreInstallations() async {
  try {
    final d = await _compteurs.get();
    return _n(d.data(), 'installations');
  } catch (_) {
    return 0;
  }
}
