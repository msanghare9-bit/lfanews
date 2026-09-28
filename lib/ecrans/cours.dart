import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../app.dart';
import '../cours_service.dart';
import '../modeles.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

final _cours = FirebaseFirestore.instance.collection('cours');

class Cours0 extends StatefulWidget {
  const Cours0({super.key});

  @override
  State<Cours0> createState() => _Cours0State();
}

class _Cours0State extends State<Cours0> {
  String? _niveau;
  String? _matiere;
  String? _serie;

  bool get _attendSerie => _niveau != null && _matiere != null && matiereADeuxSeries(_niveau!, _matiere!);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) {
        Widget corps;
        String titreEcran = 'Cours';
        if (_niveau == null) {
          corps = _listeNiveaux(ed);
        } else if (_matiere == null) {
          titreEcran = _niveau!;
          corps = _listeMatieres(ed);
        } else if (_attendSerie && _serie == null) {
          titreEcran = '$_matiere · $_niveau';
          corps = _listeSeries();
        } else {
          titreEcran = _serie == null ? '$_matiere · $_niveau' : '$_matiere · $_niveau $_serie';
          corps = _listeCours();
        }
        return Scaffold(
          appBar: AppBar(
            leading: (_niveau == null)
                ? null
                : BackButton(onPressed: () => setState(() {
                    if (_serie != null) {
                      _serie = null;
                    } else if (_matiere != null) {
                      _matiere = null;
                    } else {
                      _niveau = null;
                    }
                  })),
            title: Text(titreEcran, style: titre(20)),
          ),
          floatingActionButton: (ed?.peutCours ?? false) &&
                  _niveau != null &&
                  _matiere != null &&
                  (!_attendSerie || _serie != null)
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EditerCours(
                          editeur: ed!, niveau: _niveau!, matiere: _matiere!, serie: _serie ?? ''))),
                  backgroundColor: vert,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un cours'),
                )
              : null,
          body: corps,
        );
      },
    );
  }

  Widget _listeNiveaux(Editeur? ed) {
    // Un professeur limité à certains niveaux ne voit que ceux-là,
    // et seulement dans cette page (l'accueil de LFA News reste ouvert à tous en lecture).
    final restreint = ed != null && ed.role == 'professeur' && ed.niveaux.isNotEmpty;
    final liste = restreint ? niveaux.where((n) => ed.niveaux.contains(n)).toList() : niveaux;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text('Choisissez votre niveau', style: TextStyle(fontSize: 15, color: gris)),
        const SizedBox(height: 12),
        for (final n in liste)
          _carte(n, Icons.school_outlined, () => setState(() => _niveau = n)),
      ],
    );
  }

  Widget _listeMatieres(Editeur? ed) {
    var liste = matieresPour(_niveau!);
    final restreint = ed != null && ed.role == 'professeur' && ed.matieres.isNotEmpty;
    if (restreint) liste = liste.where((m) => ed.matieres.contains(m)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final m in liste)
          _carte(m, _iconeMatiere(m), () => setState(() {
            _matiere = m;
            _serie = null;
          })),
      ],
    );
  }

  Widget _listeSeries() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text('Le contenu de cette matière diffère selon la série',
            style: TextStyle(fontSize: 15, color: gris)),
        const SizedBox(height: 12),
        for (final se in series)
          _carte('Série $se', Icons.workspace_premium_outlined, () => setState(() => _serie = se)),
      ],
    );
  }

  Widget _listeCours() {
    final serieRecherchee = _attendSerie ? _serie : '';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cours
          .where('niveau', isEqualTo: _niveau)
          .where('matiere', isEqualTo: _matiere)
          .where('serie', isEqualTo: serieRecherchee)
          .snapshots(),
      builder: (context, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final liste = s.data!.docs.map(Cours.fromDoc).toList()..sort((a, b) => b.date.compareTo(a.date));
        if (liste.isEmpty) {
          return messageVide('Aucun cours de $_matiere pour le niveau $_niveau pour le moment.');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: liste.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: bordure),
          itemBuilder: (context, i) {
            final c = liste[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              leading: const CircleAvatar(
                  backgroundColor: vertPale, child: Icon(Icons.menu_book_outlined, color: vert)),
              title: Text(c.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Text(dateFr(c.date), style: const TextStyle(fontSize: 12, color: gris)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LectureCours(cours: c))),
            );
          },
        );
      },
    );
  }

  Widget _carte(String texte, IconData icone, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: vertPale,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icone, color: vert),
              const SizedBox(width: 14),
              Expanded(child: Text(texte, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              const Icon(Icons.chevron_right, color: gris),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconeMatiere(String m) {
    switch (m) {
      case 'Mathématiques':
        return Icons.functions;
      case 'Français':
      case 'Anglais':
      case 'Arabe':
        return Icons.translate;
      case 'Histoire-Géographie':
        return Icons.public;
      case 'SVT':
        return Icons.eco_outlined;
      case 'Éducation religieuse':
        return Icons.mosque_outlined;
      case 'Philosophie':
        return Icons.psychology_outlined;
      case 'Physique-Chimie':
        return Icons.science_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }
}

class LectureCours extends StatelessWidget {
  const LectureCours({super.key, required this.cours});
  final Cours cours;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) {
        final peut = ed != null && (ed.estAdmin || (ed.peutCours && ed.nom == cours.auteurNom));
        return Scaffold(
          appBar: AppBar(
            actions: [
              if (peut)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EditerCours(
                          editeur: ed!, niveau: cours.niveau, matiere: cours.matiere, serie: cours.serie, existant: cours))),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
            children: [
              Text(cours.serie.isEmpty
                      ? '${cours.matiere} · ${cours.niveau}'
                      : '${cours.matiere} · ${cours.niveau} série ${cours.serie}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: vert)),
              const SizedBox(height: 8),
              Text(cours.titre, style: titre(26)),
              const SizedBox(height: 6),
              Text('${cours.auteurNom} · ${dateFr(cours.date)}', style: const TextStyle(fontSize: 13, color: gris)),
              const Divider(height: 28, color: bordure),
              if (cours.aUnPdf) ...[
                InkWell(
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => VisionneusePdf(cours: cours))),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: vertPale, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, color: vert, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Document du cours', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text(cours.pdfNom.isEmpty ? 'Ouvrir le PDF' : cours.pdfNom,
                                  style: const TextStyle(fontSize: 12, color: gris)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: gris),
                      ],
                    ),
                  ),
                ),
                if (cours.texte.trim().isNotEmpty) const SizedBox(height: 18),
              ],
              if (cours.texte.trim().isNotEmpty) Paragraphes(cours.texte),
              if (cours.exercices.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Exercices', style: titre(22, couleur: vert)),
                const SizedBox(height: 12),
                for (var i = 0; i < cours.exercices.length; i++)
                  _Exercice(numero: i + 1, exercice: cours.exercices[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Exercice extends StatefulWidget {
  const _Exercice({required this.numero, required this.exercice});
  final int numero;
  final QR exercice;

  @override
  State<_Exercice> createState() => _ExerciceState();
}

class _ExerciceState extends State<_Exercice> {
  bool _montre = false;

  @override
  Widget build(BuildContext context) {
    final aCorrige = widget.exercice.r.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vertPale,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exercice ${widget.numero}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: vert)),
          const SizedBox(height: 6),
          Text(widget.exercice.q, style: const TextStyle(fontSize: 16, height: 1.5)),
          if (aCorrige) ...[
            const SizedBox(height: 12),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _montre ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: OutlinedButton.icon(
                onPressed: () => setState(() => _montre = true),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Voir le corrigé'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: vert,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: vert),
                ),
              ),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: vertVif),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Corrigé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vert)),
                    const SizedBox(height: 4),
                    Text(widget.exercice.r, style: const TextStyle(fontSize: 15, height: 1.5)),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => setState(() => _montre = false),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                      child: const Text('Masquer le corrigé'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaireEx {
  _PaireEx([String q = '', String r = ''])
      : q = TextEditingController(text: q),
        r = TextEditingController(text: r);
  final TextEditingController q;
  final TextEditingController r;
}

class VisionneusePdf extends StatefulWidget {
  const VisionneusePdf({super.key, required this.cours});
  final Cours cours;

  @override
  State<VisionneusePdf> createState() => _VisionneusePdfState();
}

class _VisionneusePdfState extends State<VisionneusePdf> {
  late final Future<Uint8List> _pdf = chargerPdf(widget.cours);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cours.pdfNom.isEmpty ? widget.cours.titre : widget.cours.pdfNom,
          style: const TextStyle(fontSize: 16))),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (context, s) {
          if (s.hasError) {
            return messageVide('Impossible d’ouvrir ce document : ${s.error}');
          }
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          return SfPdfViewer.memory(s.data!);
        },
      ),
    );
  }
}

class EditerCours extends StatefulWidget {
  const EditerCours(
      {super.key, required this.editeur, required this.niveau, required this.matiere, this.serie = '', this.existant});
  final Editeur editeur;
  final String niveau;
  final String matiere;
  final String serie;
  final Cours? existant;

  @override
  State<EditerCours> createState() => _EditerCoursState();
}

class _EditerCoursState extends State<EditerCours> {
  late final _titre = TextEditingController(text: widget.existant?.titre ?? '');
  late final _texte = TextEditingController(text: widget.existant?.texte ?? '');
  late final List<_PaireEx> _exercices =
      (widget.existant?.exercices ?? []).map((e) => _PaireEx(e.q, e.r)).toList();
  Uint8List? _nouveauPdf;
  String _nouveauPdfNom = '';
  bool _pdfRetire = false;
  bool _lecturePdf = false;
  bool _envoi = false;

  bool get _aDejaUnPdf => (widget.existant?.aUnPdf ?? false) && !_pdfRetire;

  Future<void> _choisirPdf() async {
    final f = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf'])
    ]);
    if (f == null) return;
    final taille = await f.length();
    if (taille > tailleMaxPdfOctets) {
      afficher('Ce document fait ${(taille / 1048576).toStringAsFixed(1)} Mo. Maximum : 3 Mo.');
      return;
    }
    setState(() => _lecturePdf = true);
    final octets = await f.readAsBytes();
    if (!mounted) return;
    setState(() {
      _nouveauPdf = octets;
      _nouveauPdfNom = f.name;
      _pdfRetire = false;
      _lecturePdf = false;
    });
  }

  List<Map<String, dynamic>> _exercicesEnMap() => _exercices
      .where((p) => p.q.text.trim().isNotEmpty)
      .map((p) => QR(p.q.text.trim(), p.r.text.trim()).toMap())
      .toList();

  Future<void> _enregistrer() async {
    if (_titre.text.trim().isEmpty) {
      afficher('Ajoutez un titre au cours.');
      return;
    }
    final aTexte = _texte.text.trim().isNotEmpty;
    final aUnPdfFinal = _nouveauPdf != null || _aDejaUnPdf;
    if (!aTexte && !aUnPdfFinal) {
      afficher('Ajoutez un texte, un PDF, ou les deux.');
      return;
    }
    setState(() => _envoi = true);
    try {
      String id;
      if (widget.existant == null) {
        final ref = await _cours.add({
          'niveau': widget.niveau,
          'matiere': widget.matiere,
          'serie': widget.serie,
          'titre': _titre.text.trim(),
          'texte': _texte.text.trim(),
          'exercices': _exercicesEnMap(),
          'auteurId': widget.editeur.uid,
          'auteurNom': widget.editeur.nom,
          'date': FieldValue.serverTimestamp(),
        });
        id = ref.id;
      } else {
        id = widget.existant!.id;
        await _cours.doc(id).update({
          'titre': _titre.text.trim(),
          'texte': _texte.text.trim(),
          'exercices': _exercicesEnMap(),
        });
      }
      if (_pdfRetire && widget.existant != null && widget.existant!.aUnPdf) {
        await retirerPdf(id, widget.existant!.nbMorceauxPdf);
      }
      if (_nouveauPdf != null) {
        if (widget.existant != null && widget.existant!.aUnPdf && !_pdfRetire) {
          await retirerPdf(id, widget.existant!.nbMorceauxPdf);
        }
        await enregistrerPdf(id, _nouveauPdf!, _nouveauPdfNom);
      }
      afficher(widget.existant == null ? 'Cours ajouté.' : 'Cours modifié.');
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == null);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      afficher('Échec : $e');
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _supprimer() async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce cours ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (oui != true) return;
    await _cours.doc(widget.existant!.id).delete();
    if (mounted) Navigator.of(context)..pop()..pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vertPale,
      appBar: AppBar(
        backgroundColor: vert,
        foregroundColor: Colors.white,
        surfaceTintColor: vert,
        title: Text(widget.existant == null ? 'Nouveau cours' : 'Modifier le cours'),
        actions: [
          if (widget.existant != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _supprimer),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.serie.isEmpty
                  ? '${widget.matiere} · ${widget.niveau}'
                  : '${widget.matiere} · ${widget.niveau} série ${widget.serie}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: vert)),
          const SizedBox(height: 14),
          TextField(
            controller: _titre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Titre du cours', filled: true, fillColor: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _texte,
            minLines: 8,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Texte du cours (facultatif si vous ajoutez un PDF)',
                filled: true,
                fillColor: Colors.white),
          ),
          const SizedBox(height: 18),
          const Text('Document PDF (facultatif)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('3 Mo au maximum. Vous pouvez ajouter un texte, un PDF, ou les deux.',
              style: TextStyle(fontSize: 12, color: gris)),
          const SizedBox(height: 8),
          if (_nouveauPdf != null || _aDejaUnPdf)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: vert),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _nouveauPdf != null ? _nouveauPdfNom : widget.existant!.pdfNom,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _nouveauPdf = null;
                      _nouveauPdfNom = '';
                      _pdfRetire = true;
                    }),
                    child: const Text('Retirer'),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _lecturePdf ? null : _choisirPdf,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_lecturePdf ? 'Vérification…' : 'Importer un PDF'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48), foregroundColor: vert, backgroundColor: Colors.white),
            ),
          const SizedBox(height: 22),
          const Text('Exercices (facultatif)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Le corrigé reste masqué : l’élève l’affiche en appuyant sur un bouton.',
              style: TextStyle(fontSize: 12, color: gris)),
          const SizedBox(height: 10),
          for (var i = 0; i < _exercices.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Exercice ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: vert)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Retirer cet exercice',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _exercices.removeAt(i)),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _exercices[i].q,
                    minLines: 2,
                    maxLines: null,
                    decoration: const InputDecoration(hintText: 'L’énoncé'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _exercices[i].r,
                    minLines: 2,
                    maxLines: null,
                    decoration: const InputDecoration(hintText: 'Le corrigé (facultatif)'),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _exercices.add(_PaireEx())),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un exercice'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _envoi ? null : _enregistrer,
            child: Text(_envoi ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}
