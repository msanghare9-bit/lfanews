import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

const categories = [
  'Annonces',
  'Vie scolaire',
  'Examens',
  'Clubs',
  'Sport',
  'Culture',
  'Interview',
  'Portrait',
];

class QR {
  QR(this.q, this.r);
  final String q;
  final String r;
  Map<String, dynamic> toMap() => {'q': q, 'r': r};
}

class Article {
  Article({
    required this.id,
    required this.collection,
    required this.titre,
    required this.texte,
    required this.categorie,
    required this.vignette,
    required this.nbPhotos,
    required this.auteurId,
    required this.auteurNom,
    required this.date,
    required this.epingle,
    required this.urgent,
    required this.personne,
    required this.fonction,
    required this.citation,
    required this.qr,
  });

  final String id;
  final String collection; // 'articles' ou 'propositions'
  final String titre;
  final String texte;
  final String categorie;
  final String vignette;
  final int nbPhotos;
  final String auteurId;
  final String auteurNom;
  final DateTime date;
  final bool epingle;
  final bool urgent;
  final String personne;
  final String fonction;
  final String citation;
  final List<QR> qr;

  late final Uint8List? octets = vignette.isEmpty ? null : base64Decode(vignette);

  bool get estInterview => categorie == 'Interview';
  bool get estPortrait => categorie == 'Portrait';
  bool get estProposition => collection == 'propositions';

  DocumentReference<Map<String, dynamic>> get ref =>
      FirebaseFirestore.instance.collection(collection).doc(id);

  factory Article.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    String s(String k) => (d[k] ?? '').toString();
    final brut = d['qr'];
    return Article(
      id: doc.id,
      collection: doc.reference.parent.id,
      titre: s('titre'),
      texte: s('texte'),
      categorie: d['categorie'] == null ? 'Annonces' : s('categorie'),
      vignette: s('vignette'),
      nbPhotos: (d['nbPhotos'] is int) ? d['nbPhotos'] as int : 0,
      auteurId: s('auteurId'),
      auteurNom: s('auteurNom'),
      date: (d['date'] is Timestamp) ? (d['date'] as Timestamp).toDate() : DateTime.now(),
      epingle: d['epingle'] == true,
      urgent: d['urgent'] == true,
      personne: s('personne'),
      fonction: s('fonction'),
      citation: s('citation'),
      qr: brut is List
          ? brut
              .whereType<Map>()
              .map((e) => QR((e['q'] ?? '').toString(), (e['r'] ?? '').toString()))
              .toList()
          : <QR>[],
    );
  }
}
