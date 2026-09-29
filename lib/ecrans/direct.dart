import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../direct_service.dart';
import '../images.dart';
import '../modeles.dart';
import '../session.dart';
import '../stats.dart';
import '../theme.dart';
import '../widgets.dart';
import 'article.dart';

class PageDirect extends StatefulWidget {
  const PageDirect({super.key, required this.directId, this.articleId});
  final String directId;
  final String? articleId;

  @override
  State<PageDirect> createState() => _PageDirectState();
}

class _PageDirectState extends State<PageDirect> {
  String get directId => widget.directId;
  String? get articleId => widget.articleId;

  @override
  void initState() {
    super.initState();
    compterVueDirect(directId);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: directs.doc(directId).snapshots(),
        builder: (context, s) {
          if (!s.hasData) {
            return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
          }
          if (!s.data!.exists) {
            return Scaffold(appBar: AppBar(), body: messageVide('Ce direct n’existe plus.'));
          }
          final d = Direct.fromDoc(s.data!);
          final equipe = ed != null && d.enCours;
          return Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (d.enCours) ...[
                    const Icon(Icons.circle, size: 10, color: rougeDirect),
                    const SizedBox(width: 6),
                  ],
                  Text(d.enCours ? 'En direct' : 'Fil en direct',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
              actions: [
                if (ed != null && ed.estAdmin && d.enCours) ...[
                  IconButton(
                    tooltip: 'Supprimer ce direct',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _supprimer(context, d),
                  ),
                  TextButton(onPressed: () => _terminer(context, ed, d), style: TextButton.styleFrom(foregroundColor: Colors.white), child: const Text('Terminer')),
                ],
                if (ed != null && ed.estAdmin && !d.enCours)
                  IconButton(
                    tooltip: 'Supprimer ce direct',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _supprimerArchive(context, d),
                  ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(d.titre, style: titre(26)),
                ),
                if (d.estMatch) _Score(direct: d, modifiable: equipe),
                if (ed != null)
                  StreamBuilder<Stat>(
                    stream: suivreStat('direct_${d.id}'),
                    builder: (context, sv) {
                      final n = sv.data?.vues ?? 0;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                        child: Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 16, color: gris),
                            const SizedBox(width: 5),
                            Text('$n personne${n > 1 ? 's ont' : ' a'} suivi ce direct (rédaction seulement)',
                                style: const TextStyle(fontSize: 13, color: gris)),
                          ],
                        ),
                      );
                    },
                  ),
                if (equipe) _Composer(editeur: ed, directId: d.id),
                _Fil(directId: d.id, editeur: ed, match: d.estMatch),
                if (articleId != null) Reactions(id: articleId!, equipe: ed != null),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _supprimerArchive(BuildContext context, Direct d) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce direct ?'),
        content: Text('« ${d.titre} » et tout son fil seront définitivement supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (oui != true) return;
    try {
      await supprimerDirectArchive(d.id);
      afficher('Direct supprimé.');
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      afficher('Échec : $e');
    }
  }

  Future<void> _supprimer(BuildContext context, Direct d) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce direct ?'),
        content: const Text('Le direct et toutes ses mises à jour seront définitivement supprimés, sans être publiés comme article.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (oui != true) return;
    try {
      await supprimerDirect(d.id);
      afficher('Direct supprimé.');
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      afficher('Échec : $e');
    }
  }

  Future<void> _terminer(BuildContext context, Editeur ed, Direct d) async {
    var categorie = d.estMatch ? 'Sport' : 'Vie scolaire';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Terminer le direct ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Le fil restera consultable comme un article dans la rubrique :'),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: categorie,
                isExpanded: true,
                items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => set(() => categorie = v ?? categorie),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await terminerDirect(ed, d, categorie);
      afficher('Direct terminé. Il est rangé dans la rubrique $categorie.');
    } catch (e) {
      afficher('Échec : $e');
    }
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.direct, required this.modifiable});
  final Direct direct;
  final bool modifiable;

  Widget _equipe(String nom, int score, String champ) {
    return Expanded(
      child: Column(
        children: [
          Text(nom,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('$score', style: titre(44, couleur: Colors.white)),
          if (modifiable)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Retirer un point',
                  onPressed: score > 0 ? () => changerScore(direct.id, champ, -1) : null,
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                ),
                IconButton(
                  tooltip: 'Ajouter un point',
                  onPressed: () => changerScore(direct.id, champ, 1),
                  icon: const Icon(Icons.add_circle, color: Colors.white, size: 30),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: vert, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _equipe(direct.equipeA, direct.scoreA, 'scoreA'),
          Padding(
            padding: const EdgeInsets.only(top: 34),
            child: Text('–', style: titre(30, couleur: Colors.white70)),
          ),
          _equipe(direct.equipeB, direct.scoreB, 'scoreB'),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.editeur, required this.directId});
  final Editeur editeur;
  final String directId;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _texte = TextEditingController();
  Uint8List? _photo;
  bool _envoi = false;

  Future<void> _choisir() async {
    final b = await choisirPhoto(ImageSource.camera);
    if (b != null) setState(() => _photo = b);
  }

  Future<void> _envoyer() async {
    final t = _texte.text.trim();
    if (t.isEmpty && _photo == null) return;
    setState(() => _envoi = true);
    try {
      await publierMessage(widget.editeur, widget.directId, t, _photo);
      _texte.clear();
      _photo = null;
    } catch (e) {
      afficher('Échec de l’envoi : $e');
    }
    if (mounted) setState(() => _envoi = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: vertPale, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _texte,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Que se passe-t-il ?'),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_photo!, height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () => setState(() => _photo = null),
                    child: const CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Prendre une photo',
                onPressed: _envoi ? null : _choisir,
                icon: const Icon(Icons.photo_camera_outlined, color: vert),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _envoi ? null : _envoyer,
                style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
                child: Text(_envoi ? 'Envoi…' : 'Publier'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fil extends StatelessWidget {
  const _Fil({required this.directId, required this.editeur, required this.match});
  final String directId;
  final Editeur? editeur;
  final bool match;

  @override
  Widget build(BuildContext context) {
    final heure = DateFormat('HH:mm');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: directs.doc(directId).collection('messages').orderBy('date', descending: true).snapshots(),
      builder: (context, s) {
        if (!s.hasData) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        final messages = s.data!.docs.map(MessageDirect.fromDoc).toList();
        if (messages.isEmpty) return messageVide('Le direct commence dans un instant.');
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              for (final m in messages)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: bordure))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(heure.format(m.date),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: rougeDirect, fontSize: 14)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m.texte.isNotEmpty)
                              Text(m.texte, style: const TextStyle(fontSize: 16, height: 1.45)),
                            if (m.octets != null) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(m.octets!, fit: BoxFit.cover, width: double.infinity),
                              ),
                            ],
                            const SizedBox(height: 8),
                            _ReactionsMessage(directId: directId, message: m, match: match),
                            const SizedBox(height: 4),
                            Text(m.auteurNom, style: const TextStyle(fontSize: 12, color: gris)),
                          ],
                        ),
                      ),
                      if (editeur != null && (editeur!.estAdmin || editeur!.uid == m.auteurId))
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline, size: 20, color: gris),
                          onPressed: () => supprimerMessage(directId, m.id),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class LancerDirect extends StatefulWidget {
  const LancerDirect({super.key, required this.editeur});
  final Editeur editeur;

  @override
  State<LancerDirect> createState() => _LancerDirectState();
}

class _LancerDirectState extends State<LancerDirect> {
  final _titre = TextEditingController();
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _match = false;

  Future<void> _lancer() async {
    final t = _titre.text.trim();
    if (t.isEmpty) {
      afficher('Donnez un titre au direct.');
      return;
    }
    if (_match && (_a.text.trim().isEmpty || _b.text.trim().isEmpty)) {
      afficher('Indiquez les deux équipes.');
      return;
    }
    final id = await lancerDirect(
        widget.editeur, t, _match ? _a.text.trim() : '', _match ? _b.text.trim() : '');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PageDirect(directId: id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: rougeDirect,
        foregroundColor: Colors.white,
        surfaceTintColor: rougeDirect,
        title: const Text('Lancer un direct', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Titre', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _titre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ex. : Finale du tournoi inter-classes'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _match,
            onChanged: (v) => setState(() => _match = v),
            title: const Text('C’est un match (afficher un score)'),
          ),
          if (_match) ...[
            TextField(controller: _a, decoration: const InputDecoration(labelText: 'Équipe 1')),
            const SizedBox(height: 10),
            TextField(controller: _b, decoration: const InputDecoration(labelText: 'Équipe 2')),
          ],
          const SizedBox(height: 12),
          const Text(
            'Une notification sera envoyée à tous les lecteurs. Les membres de la rédaction pourront publier des mises à jour jusqu’à ce que vous terminiez le direct.',
            style: TextStyle(fontSize: 13, color: gris, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _lancer,
            style: FilledButton.styleFrom(backgroundColor: rougeDirect),
            child: const Text('Lancer le direct'),
          ),
        ],
      ),
    );
  }
}

class _ReactionsMessage extends StatefulWidget {
  const _ReactionsMessage({required this.directId, required this.message, required this.match});
  final String directId;
  final MessageDirect message;
  final bool match;

  @override
  State<_ReactionsMessage> createState() => _ReactionsMessageState();
}

class _ReactionsMessageState extends State<_ReactionsMessage> {
  String? _choix;

  static const _emojisMatch = ['👏', '🔥', '😂', '❤️'];
  static const _emojisEvenement = ['👏', '❤️', '🎉', '🙏'];

  @override
  void initState() {
    super.initState();
    maReactionMessage(widget.message.id).then((v) {
      if (mounted) setState(() => _choix = v);
    });
  }

  void _toucher(String e) {
    final apres = _choix == e ? null : e;
    reagirMessage(widget.directId, widget.message.id, _choix, apres);
    setState(() => _choix = apres);
  }

  @override
  Widget build(BuildContext context) {
    final emojis = widget.match ? _emojisMatch : _emojisEvenement;
    return Wrap(
      spacing: 6,
      children: [
        for (final e in emojis)
          InkWell(
            onTap: () => _toucher(e),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: _choix == e ? vertPale : Colors.transparent,
                border: Border.all(color: _choix == e ? vert : bordureChamp),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e, style: const TextStyle(fontSize: 14)),
                  if ((widget.message.reactions[e] ?? 0) > 0) ...[
                    const SizedBox(width: 4),
                    Text('${widget.message.reactions[e]}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vert)),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
