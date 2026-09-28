import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../app.dart';
import '../emission_service.dart';
import '../images.dart';
import '../modeles.dart';
import '../session.dart';
import '../stats.dart';
import '../theme.dart';
import '../widgets.dart';

String _quand(DateTime d) => DateFormat("EEEE d MMMM 'à' HH:mm", 'fr_FR').format(d);
String _minSec(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

/// Bandeau de l'accueil : l'émission de la veille, du jour ou du lendemain.
class BandeauEmission extends StatelessWidget {
  const BandeauEmission({super.key, required this.emission, required this.onTap});
  final Emission emission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String texte;
    if (now.isBefore(emission.debut)) {
      texte = '${emission.titre} · ${DateFormat("EEEE 'à' HH:mm", 'fr_FR').format(emission.debut)}';
    } else if (now.isBefore(emission.fin)) {
      texte = '${emission.titre} · en cours, rejoignez-nous';
    } else {
      texte = '${emission.titre} · à réécouter';
    }
    return Container(
      decoration: const BoxDecoration(
        color: vertFonce,
        boxShadow: [BoxShadow(color: Color(0x33132619), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.headphones, size: 13, color: vertFonce),
                      SizedBox(width: 4),
                      Text('ÉMISSION',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vertFonce)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(texte,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ListeEmissions extends StatelessWidget {
  const ListeEmissions({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) {
        final admin = ed?.estAdmin ?? false;
        return Scaffold(
          appBar: AppBar(title: Text('Émissions', style: titre(22))),
          floatingActionButton: admin
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => NouvelleEmission(editeur: ed!))),
                  backgroundColor: vert,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Programmer une émission'),
                )
              : null,
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: emissions.orderBy('debut', descending: true).snapshots(),
            builder: (context, s) {
              if (s.hasError) return messageVide('Impossible de charger les émissions.');
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final liste = s.data!.docs.map(Emission.fromDoc).toList();
              if (liste.isEmpty) {
                return messageVide('La première émission arrive bientôt.', icone: Icons.headphones);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: bordure),
                itemBuilder: (context, i) {
                  final e = liste[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Photo(octets: e.octetsCouverture, sombre: true, icone: Icons.headphones),
                      ),
                    ),
                    title: Text(e.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    subtitle: Text(_quand(e.debut), style: const TextStyle(fontSize: 12, color: gris)),
                    trailing: admin
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: gris),
                            onPressed: () => _supprimer(context, e),
                          )
                        : const Icon(Icons.chevron_right, color: gris),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => PageEmission(emissionId: e.id))),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _supprimer(BuildContext context, Emission e) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cette émission ?'),
        content: Text('« ${e.titre} » sera définitivement supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (oui != true) return;
    try {
      await supprimerEmission(e.id);
      afficher('Émission supprimée.');
    } catch (err) {
      afficher('Échec : $err');
    }
  }
}

class PageEmission extends StatefulWidget {
  const PageEmission({super.key, required this.emissionId});
  final String emissionId;

  @override
  State<PageEmission> createState() => _PageEmissionState();
}

class _PageEmissionState extends State<PageEmission> {
  AudioPlayer? _lecteur;
  Timer? _horloge;
  bool _chargement = false;
  bool _enLecture = false;
  bool _synchro = false; // écoute au rythme du direct : pas de retour en arrière
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _horloge = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _horloge?.cancel();
    _lecteur?.dispose();
    super.dispose();
  }

  Future<void> _jouer(Emission e, {Duration depart = Duration.zero, bool synchro = false}) async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final octets = await chargerAudio(e);
      final l = _lecteur ??= AudioPlayer();
      await l.setAudioSource(SourceOctets(octets, typeAudio(e.format)));
      if (depart > Duration.zero) await l.seek(depart);
      l.playerStateStream.listen((st) {
        if (mounted) setState(() => _enLecture = st.playing && st.processingState != ProcessingState.completed);
      });
      compterEcoute(e.id);
      unawaited(l.play());
      if (mounted) setState(() => _synchro = synchro);
    } catch (err) {
      if (mounted) setState(() => _erreur = 'Impossible de lire l’émission : $err');
    }
    if (mounted) setState(() => _chargement = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: emissions.doc(widget.emissionId).snapshots(),
        builder: (context, s) {
          if (!s.hasData) {
            return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
          }
          if (!s.data!.exists) return Scaffold(appBar: AppBar(), body: messageVide('Cette émission n’existe plus.'));
          final e = Emission.fromDoc(s.data!);
          final now = DateTime.now();
          final avant = now.isBefore(e.debut);
          final pendant = !avant && now.isBefore(e.fin);
          final admin = ed?.estAdmin ?? false;
          return Scaffold(
            appBar: AppBar(title: const Text('Émission', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 200,
                    child: Photo(octets: e.octetsCouverture, sombre: true, icone: Icons.headphones),
                  ),
                ),
                const SizedBox(height: 18),
                Text(e.titre, style: titre(26)),
                const SizedBox(height: 6),
                Text(_quand(e.debut), style: const TextStyle(fontSize: 14, color: gris)),
                const SizedBox(height: 4),
                if (ed != null)
                  StreamBuilder<Stat>(
                    stream: suivreStat('emission_${e.id}'),
                    builder: (context, sv) {
                      final n = sv.data?.vues ?? 0;
                      return Row(
                        children: [
                          const Icon(Icons.headphones, size: 16, color: gris),
                          const SizedBox(width: 5),
                          Text('$n écoute${n > 1 ? 's' : ''} (rédaction seulement)',
                              style: const TextStyle(fontSize: 13, color: gris)),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 22),
                _zoneLecture(e, avant, pendant, admin, now),
                if (_erreur != null) ...[
                  const SizedBox(height: 10),
                  Text(_erreur!, style: const TextStyle(color: orangeUrgent, fontSize: 13)),
                ],
                const SizedBox(height: 26),
                const Divider(height: 1, color: bordure),
                const SizedBox(height: 16),
                const Text('Cette émission vous a plu ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _ReactionsEmission(emission: e),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _zoneLecture(Emission e, bool avant, bool pendant, bool admin, DateTime now) {
    if (_lecteur != null && (_enLecture || _lecteur!.audioSource != null) && !_chargement && _erreur == null) {
      return _controles();
    }
    if (_chargement) {
      return const Column(
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 8),
          Text('Chargement de l’émission…', style: TextStyle(color: gris)),
        ],
      );
    }
    if (avant) {
      final reste = e.debut.difference(now);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: vertPale, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                const Text('L’émission commence dans', style: TextStyle(color: gris)),
                const SizedBox(height: 6),
                Text(_minSec(reste), style: titre(38, couleur: vert)),
              ],
            ),
          ),
          if (admin) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _jouer(e),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Écouter en avant-première'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: vert),
            ),
          ],
        ],
      );
    }
    if (pendant) {
      final depart = now.difference(e.debut);
      return FilledButton.icon(
        onPressed: () => _jouer(e, depart: depart, synchro: true),
        icon: const Icon(Icons.headphones),
        label: Text('Rejoindre l’émission (à ${_minSec(depart)})'),
      );
    }
    return FilledButton.icon(
      onPressed: () => _jouer(e),
      icon: const Icon(Icons.play_arrow),
      label: const Text('Écouter l’émission'),
    );
  }

  Widget _controles() {
    final l = _lecteur!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: vertPale, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          StreamBuilder<Duration?>(
            stream: l.durationStream,
            builder: (context, sd) {
              final total = sd.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: l.positionStream,
                builder: (context, sp) {
                  final pos = sp.data ?? Duration.zero;
                  final max = total.inMilliseconds.toDouble();
                  return Column(
                    children: [
                      Slider(
                        value: max <= 0 ? 0 : pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                        max: max <= 0 ? 1 : max,
                        activeColor: vert,
                        onChanged: _synchro ? null : (v) => l.seek(Duration(milliseconds: v.round())),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(_minSec(pos), style: const TextStyle(fontSize: 12, color: gris))),
                          Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Text(_minSec(total), style: const TextStyle(fontSize: 12, color: gris))),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            iconSize: 56,
            color: vert,
            icon: Icon(_enLecture ? Icons.pause_circle_filled : Icons.play_circle_fill),
            onPressed: () => _enLecture ? l.pause() : l.play(),
          ),
          if (_synchro)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('Vous écoutez l’émission en même temps que tout le monde.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: gris)),
            ),
        ],
      ),
    );
  }
}

class _ReactionsEmission extends StatefulWidget {
  const _ReactionsEmission({required this.emission});
  final Emission emission;

  @override
  State<_ReactionsEmission> createState() => _ReactionsEmissionState();
}

class _ReactionsEmissionState extends State<_ReactionsEmission> {
  static const _emojis = ['👏', '❤️', '😂', '🔥'];
  String? _choix;

  @override
  void initState() {
    super.initState();
    maReactionEmission(widget.emission.id).then((v) {
      if (mounted) setState(() => _choix = v);
    });
  }

  void _toucher(String e) {
    final apres = _choix == e ? null : e;
    reagirEmission(widget.emission.id, _choix, apres);
    setState(() => _choix = apres);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final e in _emojis)
          InkWell(
            onTap: () => _toucher(e),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _choix == e ? vertPale : Colors.transparent,
                border: Border.all(color: _choix == e ? vert : bordureChamp),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e, style: const TextStyle(fontSize: 18)),
                  if ((widget.emission.reactions[e] ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    Text('${widget.emission.reactions[e]}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: vert)),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class NouvelleEmission extends StatefulWidget {
  const NouvelleEmission({super.key, required this.editeur});
  final Editeur editeur;

  @override
  State<NouvelleEmission> createState() => _NouvelleEmissionState();
}

class _NouvelleEmissionState extends State<NouvelleEmission> {
  final _titre = TextEditingController();
  late DateTime _debut = () {
    final n = DateTime.now().add(const Duration(hours: 1));
    return DateTime(n.year, n.month, n.day, n.hour);
  }();
  Uint8List? _audio;
  String _nomFichier = '';
  String _format = 'mp3';
  Duration? _duree;
  Uint8List? _couverture;
  String _couvertureB64 = '';
  bool _lecture = false;
  bool _envoi = false;

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _debut,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() => _debut = DateTime(d.year, d.month, d.day, _debut.hour, _debut.minute));
  }

  Future<void> _choisirHeure() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_debut));
    if (t == null) return;
    setState(() => _debut = DateTime(_debut.year, _debut.month, _debut.day, t.hour, t.minute));
  }

  Future<void> _choisirAudio() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final octets = f.bytes;
    if (octets == null) {
      afficher('Impossible de lire ce fichier.');
      return;
    }
    if (octets.length > tailleMaxOctets) {
      afficher('Ce fichier fait ${(octets.length / 1048576).toStringAsFixed(1)} Mo. Maximum : 3 Mo (environ 5 minutes de voix).');
      return;
    }
    final format = (f.extension ?? 'mp3').toLowerCase();
    setState(() => _lecture = true);
    final d = await dureeDe(octets, format);
    if (!mounted) return;
    setState(() => _lecture = false);
    if (d == null) {
      afficher('Ce fichier ne peut pas être lu. Essayez un fichier mp3, m4a ou un message vocal WhatsApp.');
      return;
    }
    if (d.inSeconds > dureeMaxSecondes) {
      afficher('Cette émission dure ${_minSec(d)}. Maximum : 5 minutes.');
      return;
    }
    setState(() {
      _audio = octets;
      _nomFichier = f.name;
      _format = format;
      _duree = d;
    });
  }

  Future<void> _choisirCouverture() async {
    final b = await choisirPhoto(ImageSource.gallery);
    if (b == null) return;
    final petite = await compute(reduire, (b, 640));
    setState(() {
      _couverture = b;
      _couvertureB64 = petite;
    });
  }

  Future<void> _publier() async {
    if (_titre.text.trim().isEmpty) {
      afficher('Donnez un titre à l’émission.');
      return;
    }
    if (_audio == null || _duree == null) {
      afficher('Choisissez le fichier audio.');
      return;
    }
    setState(() => _envoi = true);
    try {
      final ok = await creerEmission(
        ed: widget.editeur,
        titre: _titre.text.trim(),
        debut: _debut,
        audio: _audio!,
        format: _format,
        duree: _duree!.inSeconds,
        couverture: _couvertureB64,
      );
      afficher(ok
          ? 'Émission programmée. Une notification a été envoyée.'
          : 'Émission enregistrée : elle sera envoyée dès que la connexion revient. Gardez l’application ouverte.');
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
        title: const Text('Programmer une émission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text('Titre', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _titre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ex. : Le journal de la semaine'),
          ),
          const SizedBox(height: 16),
          const Text('Diffusion', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _choisirDate,
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('EEE d MMM', 'fr_FR').format(_debut)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48), foregroundColor: vert, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _choisirHeure,
                  icon: const Icon(Icons.schedule),
                  label: Text(DateFormat('HH:mm').format(_debut)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48), foregroundColor: vert, backgroundColor: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Fichier audio', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _lecture ? null : _choisirAudio,
            icon: const Icon(Icons.audio_file_outlined),
            label: Text(_lecture
                ? 'Vérification du fichier…'
                : (_audio == null ? 'Importer un fichier' : '$_nomFichier · ${_minSec(_duree!)}')),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50), foregroundColor: vert, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            '5 minutes et 3 Mo au maximum. Un message vocal WhatsApp ou un fichier mp3 ou m4a en qualité voix convient très bien.',
            style: TextStyle(fontSize: 12, color: gris, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Text('Image de couverture (facultative)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (_couverture != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(_couverture!, width: 84, height: 84, fit: BoxFit.cover),
                ),
              if (_couverture != null) const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _choisirCouverture,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_couverture == null ? 'Choisir une image' : 'Changer'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48), foregroundColor: vert, backgroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _envoi ? null : _publier,
            child: Text(_envoi ? 'Envoi en cours, patientez…' : 'Publier l’émission'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Une notification annoncera l’émission dès sa publication, avec le jour et l’heure de diffusion.',
            style: TextStyle(fontSize: 12, color: gris, height: 1.4),
          ),
        ],
      ),
    );
  }
}
