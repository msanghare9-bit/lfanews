import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app.dart';
import '../images.dart';
import '../modeles.dart';
import '../publication.dart';
import '../session.dart';
import '../theme.dart';
import 'videos.dart';

class _PaireQR {
  _PaireQR([String q = '', String r = ''])
      : q = TextEditingController(text: q),
        r = TextEditingController(text: r);
  final TextEditingController q;
  final TextEditingController r;
}

class Redaction extends StatefulWidget {
  const Redaction({super.key, required this.editeur, this.existant});
  final Editeur editeur;
  final Article? existant;

  @override
  State<Redaction> createState() => _RedactionState();
}

class _RedactionState extends State<Redaction> {
  static const _maxPhotos = 4;

  late String _categorie = widget.existant?.categorie ?? categories[1];
  late final _nomAuteur = TextEditingController(text: widget.existant?.auteurNom ?? widget.editeur.nom);
  late final _titre = TextEditingController(text: widget.existant?.titre ?? '');
  late final _texte = TextEditingController(text: widget.existant?.texte ?? '');
  late final _personne = TextEditingController(text: widget.existant?.personne ?? '');
  late final _fonction = TextEditingController(text: widget.existant?.fonction ?? '');
  late final _citation = TextEditingController(text: widget.existant?.citation ?? '');
  late final List<_PaireQR> _qr =
      (widget.existant?.qr ?? []).map((e) => _PaireQR(e.q, e.r)).toList();
  late final _video = TextEditingController(
      text: (widget.existant?.video ?? '').isEmpty ? '' : 'https://youtu.be/${widget.existant!.video}');
  late bool _epingle = widget.existant?.epingle ?? false;
  late bool _urgent = widget.existant?.urgent ?? false;

  List<Uint8List> _photos = [];
  int _anciennes = 0;
  bool _photosModifiees = false;
  bool _chargementPhotos = false;
  bool _envoi = false;

  bool get _admin => widget.editeur.estAdmin;
  bool get _interview => _categorie == 'Interview';
  bool get _portrait => _categorie == 'Portrait';
  bool get _rencontre => _categorie == 'Rencontre';
  bool get _avecPersonne => _interview || _portrait || _rencontre;
  bool get _avecQR => _interview || _rencontre;
  bool get _avecCitation => _portrait || _rencontre;

  @override
  void initState() {
    super.initState();
    if (_interview && _qr.isEmpty) _qr.add(_PaireQR());
    final ex = widget.existant;
    if (ex != null && ex.nbPhotos > 0) {
      _chargementPhotos = true;
      chargerPhotos(ex).then((p) {
        if (!mounted) return;
        setState(() {
          _photos = p;
          _anciennes = p.length;
          _chargementPhotos = false;
        });
      }).catchError((_) {
        if (mounted) setState(() => _chargementPhotos = false);
      });
    }
  }

  Future<void> _ajouterPhoto(ImageSource source) async {
    try {
      final b = await choisirPhoto(source);
      if (b == null) return;
      if (b.length > 650 * 1024) {
        afficher('Cette photo est trop lourde. Choisissez-en une autre.');
        return;
      }
      setState(() {
        _photos.add(b);
        _photosModifiees = true;
      });
    } catch (_) {
      afficher("Impossible d'ajouter la photo.");
    }
  }

  String? _verifier() {
    if (_nomAuteur.text.trim().isEmpty) return 'Indiquez votre nom : il sera affiché comme signature.';
    if (_titre.text.trim().isEmpty) return 'Ajoutez un titre.';
    if (_video.text.trim().isNotEmpty && idYoutube(_video.text) == null) {
      return 'Lien YouTube non reconnu. Copiez-le depuis le bouton Partager de YouTube.';
    }
    if (_avecPersonne && _personne.text.trim().isEmpty) {
      return 'Indiquez le nom de la personne.';
    }
    final qr = _qr.where((p) => p.q.text.trim().isNotEmpty).toList();
    if (_interview && qr.isEmpty) return 'Ajoutez au moins une question.';
    if (_rencontre && qr.isEmpty && _texte.text.trim().isEmpty) {
      return 'Ajoutez un texte de présentation ou au moins une question.';
    }
    if (!_interview && !_rencontre && _texte.text.trim().isEmpty) return 'Ajoutez le texte de l’article.';
    return null;
  }

  Future<void> _enregistrer() async {
    final erreur = _verifier();
    if (erreur != null) {
      afficher(erreur);
      return;
    }
    setState(() => _envoi = true);
    final champs = <String, dynamic>{
      'auteurNom': _nomAuteur.text.trim(),
      'titre': _titre.text.trim(),
      'texte': _texte.text.trim(),
      'categorie': _categorie,
      'video': idYoutube(_video.text) ?? '',
      'personne': _avecPersonne ? _personne.text.trim() : '',
      'fonction': _avecPersonne ? _fonction.text.trim() : '',
      'citation': _avecCitation ? _citation.text.trim() : '',
      'qr': _avecQR
          ? _qr
              .where((p) => p.q.text.trim().isNotEmpty)
              .map((p) => QR(p.q.text.trim(), p.r.text.trim()).toMap())
              .toList()
          : <Map<String, dynamic>>[],
    };
    if (_admin) {
      champs['epingle'] = _epingle;
      champs['urgent'] = _urgent;
    } else if (widget.existant == null) {
      champs['epingle'] = false;
      champs['urgent'] = false;
    }
    try {
      final nouveau = widget.existant == null;
      final ok = await enregistrer(
        ed: widget.editeur,
        existant: widget.existant,
        champs: champs,
        photos: (nouveau || _photosModifiees) ? _photos : null,
        anciennes: _anciennes,
      );
      if (!ok) {
        afficher('Enregistré sur le téléphone. L’envoi se fera dès que la connexion revient.');
      } else if (!nouveau) {
        afficher('Modifications enregistrées.');
      } else if (_admin) {
        afficher('Article publié.');
      } else {
        afficher('Article envoyé. Il paraîtra après validation.');
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      afficher('Échec de l’enregistrement : $e');
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nouveau = widget.existant == null;
    final bouton = !nouveau
        ? 'Enregistrer'
        : (_admin ? 'Publier' : 'Envoyer pour validation');
    return Scaffold(
      backgroundColor: vertPale,
      appBar: AppBar(
        backgroundColor: vert,
        foregroundColor: Colors.white,
        surfaceTintColor: vert,
        title: Text(nouveau ? 'Nouvel article' : 'Modifier l’article',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _etiquette('Votre nom'),
          TextField(
            controller: _nomAuteur,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Prénom et nom, affichés comme signature de l’article'),
          ),
          _espace(),
          _etiquette('Rubrique'),
          DropdownButtonFormField<String>(
            initialValue: _categorie,
            items: [
              for (final c in [
                ...categories,
                if (!categories.contains(_categorie)) _categorie,
              ])
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() {
              _categorie = v ?? _categorie;
              if (_interview && _qr.isEmpty) _qr.add(_PaireQR());
            }),
          ),
          if (_avecPersonne) ...[
            _espace(),
            _etiquette(_interview ? 'Personne interviewée' : (_rencontre ? 'Personne rencontrée' : 'Personne présentée')),
            TextField(controller: _personne, decoration: const InputDecoration(hintText: 'Prénom et nom')),
            _espace(),
            _etiquette(_interview ? 'Sa fonction' : (_rencontre ? 'Sa fonction ou ce qui la rend remarquable' : 'Ce qui la rend remarquable, en une ligne')),
            TextField(
              controller: _fonction,
              decoration: InputDecoration(
                hintText: _interview
                    ? 'Ex. : professeur de SVT, ancien élève…'
                    : 'Ex. : major de la promotion 2026',
              ),
            ),
          ],
          _espace(),
          _etiquette('Titre'),
          TextField(
            controller: _titre,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _interview
                  ? 'Une phrase forte tirée de l’entretien'
                  : 'Ex. : Journée de salubrité au lycée',
            ),
          ),
          _espace(),
          _etiquette(_interview ? 'Introduction (facultative)' : (_rencontre ? 'Présentation de la personne (facultative si vous ajoutez des questions)' : (_portrait ? 'Texte du portrait' : 'Texte'))),
          TextField(
            controller: _texte,
            minLines: (_interview || _rencontre) ? 4 : 7,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Qui, quoi, quand, où ? Commencez par l’essentiel. Laissez une ligne vide entre deux paragraphes.',
            ),
          ),
          if (_avecCitation) ...[
            _espace(),
            _etiquette(_rencontre ? 'Citation mise en valeur (facultative)' : 'Citation mise en valeur'),
            TextField(
              controller: _citation,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(hintText: 'Une phrase marquante de la personne'),
            ),
          ],
          if (_avecQR) ...[
            _espace(),
            _etiquette(_rencontre ? 'Questions et réponses (facultatif)' : 'Questions et réponses'),
            for (var i = 0; i < _qr.length; i++) _carteQR(i),
            TextButton.icon(
              onPressed: () => setState(() => _qr.add(_PaireQR())),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une question'),
            ),
          ],
          _espace(),
          _etiquette(_photos.isEmpty ? 'Photos (la première sera la photo principale)' : 'Photos'),
          _zonePhotos(),
          _espace(),
          _etiquette('Vidéo YouTube (facultative)'),
          TextField(
            controller: _video,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Collez le lien de la vidéo'),
          ),
          if (_admin) ...[
            _espace(),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _epingle,
                    onChanged: (v) => setState(() => _epingle = v),
                    title: const Text('Mettre à la une'),
                    subtitle: const Text('Grande image en haut de l’accueil'),
                  ),
                  SwitchListTile(
                    value: _urgent,
                    onChanged: (v) => setState(() => _urgent = v),
                    title: const Text('Urgent'),
                    subtitle: const Text('Bandeau orange pendant 7 jours'),
                  ),
                ],
              ),
            ),
          ] else if (nouveau) ...[
            _espace(),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFE4EFE7), borderRadius: BorderRadius.circular(10)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: vert, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Votre article sera publié après validation par le responsable du club.',
                        style: TextStyle(fontSize: 14, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_envoi || _chargementPhotos) ? null : _enregistrer,
            child: Text(_envoi ? 'Envoi en cours…' : bouton),
          ),
        ],
      ),
    );
  }

  Widget _etiquette(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );

  Widget _espace() => const SizedBox(height: 16);

  Widget _carteQR(int i) {
    final p = _qr[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Question ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: vert)),
              const Spacer(),
              IconButton(
                tooltip: 'Retirer cette question',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _qr.removeAt(i)),
              ),
            ],
          ),
          TextField(controller: p.q, maxLines: null, decoration: const InputDecoration(hintText: 'La question')),
          const SizedBox(height: 8),
          TextField(
              controller: p.r, minLines: 2, maxLines: null, decoration: const InputDecoration(hintText: 'La réponse')),
        ],
      ),
    );
  }

  Widget _zonePhotos() {
    if (_chargementPhotos) {
      return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _photos.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_photos[i], width: 84, height: 84, fit: BoxFit.cover),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => setState(() {
                    _photos.removeAt(i);
                    _photosModifiees = true;
                  }),
                  child: const CircleAvatar(
                    radius: 13,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        if (_photos.length < _maxPhotos) ...[
          _boutonPhoto(Icons.photo_library_outlined, 'Galerie', () => _ajouterPhoto(ImageSource.gallery)),
          _boutonPhoto(Icons.photo_camera_outlined, 'Appareil', () => _ajouterPhoto(ImageSource.camera)),
        ],
      ],
    );
  }

  Widget _boutonPhoto(IconData icone, String texte, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: vert, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, color: vert),
            const SizedBox(height: 4),
            Text(texte, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vert)),
          ],
        ),
      ),
    );
  }
}
