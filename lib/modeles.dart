import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

const categories = [
  'Annonces',
  'Vie scolaire',
  'Sport',
  'Rencontre',
  'Actu Kébémer',
  'Culture générale',
  'Chronique',
  'Pour rire',
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
    this.video = '',
  });

  final String directId;
  final String video; // identifiant YouTube (facultatif)

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
  bool get estRencontre => categorie == 'Rencontre';
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
      video: s('video'),
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
    this.vues = 0,
  });

  final String id;
  final String titre;
  final String equipeA;
  final String equipeB;
  final int scoreA;
  final int scoreB;
  final bool enCours;
  final DateTime debut;
  final int vues;

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
      vues: n('vues'),
    );
  }
}

class MessageDirect {
  MessageDirect(this.id, this.texte, this.photo, this.date, this.auteurId, this.auteurNom, [this.reactions = const {}]);
  final String id;
  final String texte;
  final String photo;
  final DateTime date;
  final String auteurId;
  final String auteurNom;
  final Map<String, int> reactions;

  late final Uint8List? octets = photo.isEmpty ? null : base64Decode(photo);

  factory MessageDirect.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final brut = d['reactions'];
    return MessageDirect(
      doc.id,
      (d['texte'] ?? '').toString(),
      (d['photo'] ?? '').toString(),
      (d['date'] is Timestamp) ? (d['date'] as Timestamp).toDate() : DateTime.now(),
      (d['auteurId'] ?? '').toString(),
      (d['auteurNom'] ?? '').toString(),
      brut is Map ? brut.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)) : const {},
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

const niveaux = ['6e', '5e', '4e', '3e', '2nde', '1ère', 'Terminale'];

const _matieresBase = [
  'Mathématiques',
  'Français',
  'Anglais',
  'Arabe',
  'Histoire-Géographie',
  'SVT',
  'Éducation religieuse',
];

/// Niveaux à partir desquels on distingue une série.
const _niveauxAvecSerie = ['2nde', '1ère', 'Terminale'];
const series = ['L', 'S'];

/// Matières dont le contenu diffère selon la série ; les autres matières
/// sont communes aux deux séries, à partir de la Seconde.
const matieresDifferentesSelonSerie = {'Mathématiques', 'Physique-Chimie', 'SVT', 'Philosophie'};

/// Les matières proposées dépendent du niveau : la Philosophie n'existe
/// qu'en Terminale, et la Physique-Chimie n'est pas enseignée en 6e et 5e.
List<String> matieresPour(String niveau) {
  final liste = [..._matieresBase];
  if (niveau != '6e' && niveau != '5e') liste.add('Physique-Chimie');
  if (niveau == 'Terminale') liste.add('Philosophie');
  return liste;
}

/// Vrai si, pour ce niveau et cette matière, il faut choisir une série
/// avant de voir les cours (leur contenu diffère entre L et S).
bool matiereADeuxSeries(String niveau, String matiere) =>
    _niveauxAvecSerie.contains(niveau) && matieresDifferentesSelonSerie.contains(matiere);

/// Toutes les matières existant quelque part, pour les écrans qui n'ont pas
/// encore de niveau choisi (recherche, statistiques).
final matieres = {
  for (final n in niveaux) ...matieresPour(n),
}.toList();

class Cours {
  Cours({
    required this.id,
    required this.niveau,
    required this.matiere,
    required this.titre,
    required this.texte,
    required this.auteurNom,
    required this.date,
    this.exercices = const [],
    this.serie = '',
    this.pdfNom = '',
    this.nbMorceauxPdf = 0,
  });

  final String id;
  final String niveau;
  final String matiere;
  final String titre;
  final String texte;
  final String auteurNom;
  final DateTime date;
  final List<QR> exercices; // q = énoncé, r = corrigé
  final String serie; // 'L', 'S', ou vide si la matière est commune
  final String pdfNom;
  final int nbMorceauxPdf;
  bool get aUnPdf => nbMorceauxPdf > 0;

  factory Cours.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    String s(String k) => (d[k] ?? '').toString();
    return Cours(
      id: doc.id,
      niveau: s('niveau'),
      matiere: s('matiere'),
      titre: s('titre'),
      texte: s('texte'),
      auteurNom: s('auteurNom'),
      date: (d['date'] is Timestamp) ? (d['date'] as Timestamp).toDate() : DateTime.now(),
      exercices: d['exercices'] is List
          ? (d['exercices'] as List)
              .whereType<Map>()
              .map((e) => QR((e['q'] ?? '').toString(), (e['r'] ?? '').toString()))
              .toList()
          : <QR>[],
      serie: s('serie'),
      pdfNom: s('pdfNom'),
      nbMorceauxPdf: (d['nbMorceauxPdf'] as num?)?.toInt() ?? 0,
    );
  }
}

class PersonnelLfa {
  PersonnelLfa(this.id, this.nom, this.role, this.categorie, this.photo);
  final String id;
  final String nom;
  final String role;
  final String categorie;
  final String photo;

  late final Uint8List? octets = photo.isEmpty ? null : base64Decode(photo);

  factory PersonnelLfa.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    String s(String k) => (d[k] ?? '').toString();
    return PersonnelLfa(doc.id, s('nom'), s('role'), s('categorie'), s('photo'));
  }
}

class Emission {
  Emission({
    required this.id,
    required this.titre,
    required this.debut,
    required this.duree,
    required this.nbMorceaux,
    required this.format,
    required this.couverture,
    required this.vues,
    required this.reactions,
    required this.auteurNom,
  });

  final String id;
  final String titre;
  final DateTime debut;
  final int duree; // secondes
  final int nbMorceaux;
  final String format;
  final String couverture;
  final int vues;
  final Map<String, int> reactions;
  final String auteurNom;

  DateTime get fin => debut.add(Duration(seconds: duree));
  late final Uint8List? octetsCouverture = couverture.isEmpty ? null : base64Decode(couverture);

  factory Emission.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    int n(String k) => (d[k] as num?)?.toInt() ?? 0;
    final brut = d['reactions'];
    return Emission(
      id: doc.id,
      titre: (d['titre'] ?? '').toString(),
      debut: (d['debut'] is Timestamp) ? (d['debut'] as Timestamp).toDate() : DateTime.now(),
      duree: n('duree'),
      nbMorceaux: n('nbMorceaux'),
      format: (d['format'] ?? 'mp3').toString(),
      couverture: (d['couverture'] ?? '').toString(),
      vues: n('vues'),
      reactions: brut is Map ? brut.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)) : const {},
      auteurNom: (d['auteurNom'] ?? '').toString(),
    );
  }
}

class VideoLfa {
  VideoLfa({
    required this.id,
    required this.titre,
    required this.idVideo,
    required this.type,
    required this.description,
    required this.auteurNom,
    required this.date,
  });

  final String id;
  final String titre;
  final String idVideo;
  final String type;
  final String description;
  final String auteurNom;
  final DateTime date;

  factory VideoLfa.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    String s(String k) => (d[k] ?? '').toString();
    return VideoLfa(
      id: doc.id,
      titre: s('titre'),
      idVideo: s('idVideo'),
      type: s('type'),
      description: s('description'),
      auteurNom: s('auteurNom'),
      date: (d['date'] is Timestamp) ? (d['date'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}
