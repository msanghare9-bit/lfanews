import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../modeles.dart';
import '../publication.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'redaction.dart';

class PageArticle extends StatefulWidget {
  const PageArticle({super.key, required this.article});
  final Article article;

  @override
  State<PageArticle> createState() => _PageArticleState();
}

class _PageArticleState extends State<PageArticle> {
  late final Future<List<Uint8List>> _photos = chargerPhotos(widget.article);
  bool _occupe = false;

  Article get a => widget.article;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) {
        final admin = ed?.estAdmin ?? false;
        final auteur = ed != null && ed.uid == a.auteurId;
        return FutureBuilder<List<Uint8List>>(
          future: _photos,
          builder: (context, s) {
            final photos = s.data ?? const <Uint8List>[];
            final principale = photos.isNotEmpty ? photos.first : a.octets;
            final galerie = photos.length > 1 ? photos.sublist(1) : const <Uint8List>[];
            final surVert = a.estInterview;
            final barre = _barreBas(ed, admin, auteur);
            return Scaffold(
              appBar: AppBar(
                backgroundColor: surVert ? vert : Colors.white,
                foregroundColor: surVert ? Colors.white : encre,
                surfaceTintColor: surVert ? vert : Colors.white,
                title: a.estProposition
                    ? const Text('En attente de validation', style: TextStyle(fontSize: 16))
                    : null,
                actions: [
                  if (!a.estProposition)
                    IconButton(tooltip: 'Partager', icon: const Icon(Icons.share_outlined), onPressed: _partager),
                  if (a.estProposition && (admin || auteur))
                    IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: () => _modifier(ed!)),
                  if (!a.estProposition && admin) _menuAdmin(ed!),
                ],
              ),
              body: ListView(
                children: [
                  if (a.estInterview)
                    _interview(principale)
                  else if (a.estPortrait)
                    _portrait(principale)
                  else
                    _standard(principale),
                  if (galerie.isNotEmpty) _galerie(photos),
                  const SizedBox(height: 24),
                ],
              ),
              bottomNavigationBar: barre == null ? null : SafeArea(child: barre),
            );
          },
        );
      },
    );
  }

  // ---------- Mises en page ----------

  Widget _standard(Uint8List? principale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 4 / 3, child: Photo(octets: principale, sombre: true)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.categorie, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: vert)),
              const SizedBox(height: 8),
              Text(a.titre, style: titre(28)),
              const SizedBox(height: 14),
              _auteur(),
              const Divider(height: 28, color: bordure),
              Paragraphes(a.texte),
            ],
          ),
        ),
      ],
    );
  }

  Widget _interview(Uint8List? principale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: vert,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Row(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipOval(child: Photo(octets: principale, sombre: true, icone: Icons.person_outline)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.personne, style: titre(22, couleur: Colors.white)),
                    const SizedBox(height: 4),
                    Text(a.fonction, style: const TextStyle(fontSize: 14, color: Color(0xFFD6EDDD))),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('INTERVIEW',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: vert)),
              const SizedBox(height: 8),
              Text(a.titre, style: titre(25)),
              const SizedBox(height: 8),
              Text('Propos recueillis par ${a.auteurNom}, ${dateFr(a.date)}',
                  style: const TextStyle(fontSize: 13, color: gris)),
              const SizedBox(height: 16),
              Paragraphes(a.texte),
              for (final e in a.qr)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.q,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, height: 1.4, color: vert)),
                      const SizedBox(height: 6),
                      Text(e.r, style: const TextStyle(fontSize: 16, height: 1.6)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _portrait(Uint8List? principale) {
    final blocs = a.texte.split(RegExp(r'\n\s*\n')).map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
    final debut = blocs.isEmpty ? '' : blocs.first;
    final suite = blocs.length > 1 ? blocs.sublist(1).join('\n\n') : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 400,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Photo(octets: principale, sombre: true, icone: Icons.person_outline),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: voile,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('PORTRAIT',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFF8FD3A8))),
                      const SizedBox(height: 4),
                      Text(a.personne, style: titre(32, couleur: Colors.white)),
                      if (a.fonction.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(a.fonction, style: const TextStyle(fontSize: 15, color: Color(0xFFD6EDDD))),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.titre, style: titre(22)),
              const SizedBox(height: 6),
              Text('Par ${a.auteurNom}, ${dateFr(a.date)}', style: const TextStyle(fontSize: 13, color: gris)),
              const SizedBox(height: 16),
              Paragraphes(debut),
              if (a.citation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Column(
                    children: [
                      Text('“', style: titre(64, couleur: vertVif).copyWith(height: 0.9)),
                      Text(a.citation,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 21,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: vert)),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              Paragraphes(suite),
            ],
          ),
        ),
      ],
    );
  }

  Widget _auteur() {
    return Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: vert,
          child: Text(initiales(a.auteurNom),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.auteurNom.isEmpty ? 'LFANEWS' : a.auteurNom,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(dateFr(a.date), style: const TextStyle(fontSize: 12, color: gris)),
          ],
        ),
      ],
    );
  }

  Widget _galerie(List<Uint8List> photos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Visionneuse(photos: photos, depart: i))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 120, child: Photo(octets: photos[i])),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Actions ----------

  Widget? _barreBas(Editeur? ed, bool admin, bool auteur) {
    final padding = const EdgeInsets.fromLTRB(20, 10, 20, 12);
    if (!a.estProposition) {
      return Padding(
        padding: padding,
        child: FilledButton.icon(
          onPressed: _partager,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Partager'),
        ),
      );
    }
    if (admin) {
      return Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _occupe ? null : () => _supprimer('Refuser cet article ?', 'Article refusé.'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Refuser'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _occupe ? null : _publier,
                child: const Text('Publier'),
              ),
            ),
          ],
        ),
      );
    }
    if (auteur) {
      return Padding(
        padding: padding,
        child: OutlinedButton(
          onPressed: _occupe ? null : () => _supprimer('Supprimer votre article ?', 'Article supprimé.'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Text('Supprimer'),
        ),
      );
    }
    return null;
  }

  Widget _menuAdmin(Editeur ed) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        switch (v) {
          case 'modifier':
            _modifier(ed);
          case 'une':
            await modifierChamp(a, 'epingle', !a.epingle);
            afficher(a.epingle ? "L'article n'est plus à la une." : "L'article est maintenant à la une.");
            if (mounted) Navigator.of(context).pop();
          case 'urgent':
            await modifierChamp(a, 'urgent', !a.urgent);
            afficher(a.urgent ? 'Bandeau urgent retiré.' : 'Article affiché dans le bandeau urgent.');
            if (mounted) Navigator.of(context).pop();
          case 'supprimer':
            _supprimer('Supprimer définitivement cet article ?', 'Article supprimé.');
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
        PopupMenuItem(value: 'une', child: Text(a.epingle ? 'Retirer de la une' : 'Mettre à la une')),
        PopupMenuItem(value: 'urgent', child: Text(a.urgent ? 'Retirer le bandeau urgent' : 'Marquer comme urgent')),
        const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
      ],
    );
  }

  void _partager() {
    final extrait = a.texte.length > 280 ? '${a.texte.substring(0, 280)}…' : a.texte;
    SharePlus.instance.share(ShareParams(
      text: '${a.titre}\n\n$extrait\n\nÀ lire sur LFANEWS, Lycée Franco-Arabe de Kébémer',
    ));
  }

  void _modifier(Editeur ed) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Redaction(editeur: ed, existant: a)));
  }

  Future<void> _publier() async {
    setState(() => _occupe = true);
    try {
      final ok = await publierProposition(a);
      afficher(ok ? 'Article publié.' : 'Publication enregistrée : elle partira dès que la connexion revient.');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      afficher('Échec de la publication : $e');
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _supprimer(String question, String confirmation) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(question),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (oui != true) return;
    setState(() => _occupe = true);
    try {
      await supprimer(a);
      afficher(confirmation);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      afficher('Échec : $e');
      if (mounted) setState(() => _occupe = false);
    }
  }
}

class Visionneuse extends StatelessWidget {
  const Visionneuse({super.key, required this.photos, required this.depart});
  final List<Uint8List> photos;
  final int depart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, surfaceTintColor: Colors.black),
      body: PageView.builder(
        controller: PageController(initialPage: depart),
        itemCount: photos.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(child: Image.memory(photos[i], fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
