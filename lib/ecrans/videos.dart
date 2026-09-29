import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../app.dart';
import '../modeles.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

const typesVideo = ['Émission', 'Rencontre', 'Reportage', 'Autre'];

final _videos = FirebaseFirestore.instance.collection('videos');

/// Extrait l'identifiant d'une vidéo YouTube depuis un lien (ou renvoie null).
String? idYoutube(String lien) {
  final texte = lien.trim();
  if (texte.isEmpty) return null;
  final brut = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (brut.hasMatch(texte)) return texte;
  final uri = Uri.tryParse(texte.contains('://') ? texte : 'https://$texte');
  if (uri == null) return null;
  final hote = uri.host.toLowerCase().replaceFirst('www.', '').replaceFirst('m.', '');
  String? id;
  if (hote == 'youtu.be') {
    id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  } else if (hote == 'youtube.com' || hote == 'youtube-nocookie.com' || hote == 'music.youtube.com') {
    if (uri.queryParameters['v'] != null) {
      id = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 &&
        const ['embed', 'shorts', 'live', 'v'].contains(uri.pathSegments.first)) {
      id = uri.pathSegments[1];
    }
  }
  return (id != null && brut.hasMatch(id)) ? id : null;
}

/// Affiche d'abord la vignette : la vidéo ne se charge (et ne consomme des données)
/// que lorsque le lecteur appuie sur lecture.
class LecteurVideo extends StatefulWidget {
  const LecteurVideo({super.key, required this.idVideo});
  final String idVideo;

  @override
  State<LecteurVideo> createState() => _LecteurVideoState();
}

class _LecteurVideoState extends State<LecteurVideo> {
  YoutubePlayerController? _controleur;

  void _lancer() {
    setState(() {
      _controleur = YoutubePlayerController.fromVideoId(
        videoId: widget.idVideo,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true),
      );
    });
  }

  @override
  void dispose() {
    _controleur?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controleur;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: c != null
            ? YoutubePlayer(controller: c, aspectRatio: 16 / 9)
            : GestureDetector(
                onTap: _lancer,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://img.youtube.com/vi/${widget.idVideo}/hqdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: vertFonce),
                      loadingBuilder: (context, child, p) => p == null ? child : Container(color: vertFonce),
                    ),
                    Container(color: const Color(0x33000000)),
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(color: Color(0xE6FFFFFF), shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, size: 42, color: vert),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class ListeVideos extends StatefulWidget {
  const ListeVideos({super.key});

  @override
  State<ListeVideos> createState() => _ListeVideosState();
}

class _ListeVideosState extends State<ListeVideos> {
  String? _type;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) {
        final admin = ed?.estAdmin ?? false;
        return Scaffold(
          appBar: AppBar(title: Text('Vidéos', style: titre(22, couleur: Colors.white))),
          floatingActionButton: admin
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditerVideo())),
                  backgroundColor: vert,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une vidéo'),
                )
              : null,
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _videos.orderBy('date', descending: true).snapshots(),
            builder: (context, s) {
              if (s.hasError) return messageVide('Impossible de charger les vidéos.');
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final toutes = s.data!.docs.map(VideoLfa.fromDoc).toList();
              final liste = _type == null ? toutes : toutes.where((v) => v.type == _type).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _puce('Toutes', null),
                        for (final t in typesVideo) _puce(t, t),
                      ],
                    ),
                  ),
                  if (liste.isEmpty)
                    messageVide('Aucune vidéo pour le moment.', icone: Icons.play_circle_outline),
                  for (final v in liste) _carte(context, v, admin),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _puce(String texte, String? valeur) {
    final choisi = _type == valeur;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texte),
        selected: choisi,
        showCheckmark: false,
        onSelected: (_) => setState(() => _type = valeur),
        selectedColor: vert,
        backgroundColor: Colors.white,
        side: BorderSide(color: choisi ? vert : bordureChamp),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: choisi ? Colors.white : encre, fontWeight: choisi ? FontWeight.w700 : FontWeight.w400),
      ),
    );
  }

  Widget _carte(BuildContext context, VideoLfa v, bool admin) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PageVideo(video: v))),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://img.youtube.com/vi/${v.idVideo}/hqdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: vertFonce),
                      loadingBuilder: (context, child, p) => p == null ? child : Container(color: vertFonce),
                    ),
                    Container(color: const Color(0x26000000)),
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(color: Color(0xE6FFFFFF), shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, size: 34, color: vert),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vert)),
                      const SizedBox(height: 2),
                      Text(v.titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25)),
                      const SizedBox(height: 3),
                      Text(dateFr(v.date), style: const TextStyle(fontSize: 12, color: gris)),
                    ],
                  ),
                ),
                if (admin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: gris),
                    onSelected: (a) {
                      if (a == 'modifier') {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditerVideo(video: v)));
                      } else {
                        _supprimer(context, v);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                      PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _supprimer(BuildContext context, VideoLfa v) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cette vidéo ?'),
        content: Text('« ${v.titre} » sera retirée de LFA News. Elle reste sur YouTube.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (oui != true) return;
    try {
      await _videos.doc(v.id).delete();
      afficher('Vidéo supprimée.');
    } catch (e) {
      afficher('Échec : $e');
    }
  }
}

class PageVideo extends StatelessWidget {
  const PageVideo({super.key, required this.video});
  final VideoLfa video;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        children: [
          LecteurVideo(idVideo: video.idVideo),
          const SizedBox(height: 16),
          Text(video.type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: vert)),
          const SizedBox(height: 6),
          Text(video.titre, style: titre(24)),
          const SizedBox(height: 6),
          Text('${video.auteurNom.isEmpty ? 'LFA News' : video.auteurNom} · ${dateFr(video.date)}',
              style: const TextStyle(fontSize: 13, color: gris)),
          if (video.description.isNotEmpty) ...[
            const Divider(height: 28, color: bordure),
            Paragraphes(video.description),
          ],
        ],
      ),
    );
  }
}

class EditerVideo extends StatefulWidget {
  const EditerVideo({super.key, this.video});
  final VideoLfa? video;

  @override
  State<EditerVideo> createState() => _EditerVideoState();
}

class _EditerVideoState extends State<EditerVideo> {
  late final _titre = TextEditingController(text: widget.video?.titre ?? '');
  late final _lien = TextEditingController(text: widget.video == null ? '' : 'https://youtu.be/${widget.video!.idVideo}');
  late final _description = TextEditingController(text: widget.video?.description ?? '');
  late String _type = widget.video?.type ?? typesVideo.first;
  bool _envoi = false;

  Future<void> _enregistrer() async {
    final id = idYoutube(_lien.text);
    if (_titre.text.trim().isEmpty) {
      afficher('Donnez un titre à la vidéo.');
      return;
    }
    if (id == null) {
      afficher('Lien YouTube non reconnu. Copiez le lien depuis le bouton Partager de YouTube.');
      return;
    }
    setState(() => _envoi = true);
    final ed = Session.instance.editeur.value;
    final data = <String, dynamic>{
      'titre': _titre.text.trim(),
      'idVideo': id,
      'type': _type,
      'description': _description.text.trim(),
    };
    try {
      if (widget.video == null) {
        data['date'] = FieldValue.serverTimestamp();
        data['auteurNom'] = ed?.nom ?? '';
        unawaited(_videos.add(data).then((_) {}).catchError((e) => afficher('Échec : $e')));
      } else {
        unawaited(_videos.doc(widget.video!.id).update(data).catchError((e) => afficher('Échec : $e')));
      }
      afficher(widget.video == null ? 'Vidéo ajoutée.' : 'Vidéo modifiée.');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      afficher('Échec : $e');
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vertPale,
      appBar: AppBar(
        backgroundColor: vert,
        foregroundColor: Colors.white,
        surfaceTintColor: vert,
        title: Text(widget.video == null ? 'Ajouter une vidéo' : 'Modifier la vidéo',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Titre', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _titre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ex. : Le journal de la semaine'),
          ),
          const SizedBox(height: 16),
          const Text('Type', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: [for (final t in typesVideo) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 16),
          const Text('Lien YouTube', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _lien,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'https://youtu.be/…'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mettez d’abord la vidéo sur YouTube en mode « non répertoriée », puis collez ici le lien du bouton Partager.',
            style: TextStyle(fontSize: 12, color: gris, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Text('Description (facultative)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'De quoi parle cette vidéo ?'),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _envoi ? null : _enregistrer,
            child: Text(_envoi ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}
