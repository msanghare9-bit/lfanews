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
    this.directId = '',
  });

  final String directId;

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
      directId: s('directId'),
    );
  }
}

class Direct {
  Direct({
    required this.id,
    required this.titre,
    required this.equipeA,
    required this.equipeB,
    required this.scoreA,
    required this.scoreB,
    required this.enCours,
    required this.debut,
  });

  final String id;
  final String titre;
  final String equipeA;
  final String equipeB;
  final int scoreA;
  final int scoreB;
  final bool enCours;
  final DateTime debut;

  bool get estMatch => equipeA.isNotEmpty && equipeB.isNotEmpty;
  String get score => '$scoreA – $scoreB';

  factory Direct.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    int n(String k) => (d[k] as num?)?.toInt() ?? 0;
    return Direct(
      id: doc.id,
      titre: (d['titre'] ?? '').toString(),
      equipeA: (d['equipeA'] ?? '').toString(),
      equipeB: (d['equipeB'] ?? '').toString(),
      scoreA: n('scoreA'),
      scoreB: n('scoreB'),
      enCours: d['enCours'] == true,
      debut: (d['debut'] is Timestamp) ? (d['debut'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}

class MessageDirect {
  MessageDirect(this.id, this.texte, this.photo, this.date, this.auteurId, this.auteurNom);
  final String id;
  final String texte;
  final String photo;
  final DateTime date;
  final String auteurId;
  final String auteurNom;

  late final Uint8List? octets = photo.isEmpty ? null : base64Decode(photo);

  factory MessageDirect.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MessageDirect(
      doc.id,
      (d['texte'] ?? '').toString(),
      (d['photo'] ?? '').toString(),
      (d['date'] is Timestamp) ? (d['date'] as Timestamp).toDate() : DateTime.now(),
      (d['auteurId'] ?? '').toString(),
      (d['auteurNom'] ?? '').toString(),
    );
  }
}

class Membre {
  Membre(this.id, this.nom, this.role, this.classe, this.photo);
  final String id;
  final String nom;
  final String role;
  final String classe;
  final String photo;

  late final Uint8List? octets = photo.isEmpty ? null : base64Decode(photo);

  factory Membre.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    String s(String k) => (d[k] ?? '').toString();
    return Membre(doc.id, s('nom'), s('role'), s('classe'), s('photo'));
  }
}
