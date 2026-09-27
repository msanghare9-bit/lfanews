import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app.dart';
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) {
        Widget corps;
        String titreEcran = 'Cours';
        if (_niveau == null) {
          corps = _listeNiveaux();
        } else if (_matiere == null) {
          titreEcran = _niveau!;
          corps = _listeMatieres();
        } else {
          titreEcran = '$_matiere · $_niveau';
          corps = _listeCours();
        }
        return Scaffold(
          appBar: AppBar(
            leading: (_niveau == null)
                ? null
                : BackButton(onPressed: () => setState(() {
                    if (_matiere != null) {
                      _matiere = null;
                    } else {
                      _niveau = null;
                    }
                  })),
            title: Text(titreEcran, style: titre(20)),
          ),
          floatingActionButton: (ed?.peutCours ?? false) && _niveau != null && _matiere != null
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EditerCours(editeur: ed!, niveau: _niveau!, matiere: _matiere!))),
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

  Widget _listeNiveaux() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text('Choisissez votre niveau', style: TextStyle(fontSize: 15, color: gris)),
        const SizedBox(height: 12),
        for (final n in niveaux)
          _carte(n, Icons.school_outlined, () => setState(() => _niveau = n)),
      ],
    );
  }

  Widget _listeMatieres() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final m in matieres)
          _carte(m, _iconeMatiere(m), () => setState(() => _matiere = m)),
      ],
    );
  }

  Widget _listeCours() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cours
          .where('niveau', isEqualTo: _niveau)
          .where('matiere', isEqualTo: _matiere)
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
                      builder: (_) => EditerCours(editeur: ed!, niveau: cours.niveau, matiere: cours.matiere, existant: cours))),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
            children: [
              Text('${cours.matiere} · ${cours.niveau}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: vert)),
              const SizedBox(height: 8),
              Text(cours.titre, style: titre(26)),
              const SizedBox(height: 6),
              Text('${cours.auteurNom} · ${dateFr(cours.date)}', style: const TextStyle(fontSize: 13, color: gris)),
              const Divider(height: 28, color: bordure),
              Paragraphes(cours.texte),
            ],
          ),
        );
      },
    );
  }
}

class EditerCours extends StatefulWidget {
  const EditerCours({super.key, required this.editeur, required this.niveau, required this.matiere, this.existant});
  final Editeur editeur;
  final String niveau;
  final String matiere;
  final Cours? existant;

  @override
  State<EditerCours> createState() => _EditerCoursState();
}

class _EditerCoursState extends State<EditerCours> {
  late final _titre = TextEditingController(text: widget.existant?.titre ?? '');
  late final _texte = TextEditingController(text: widget.existant?.texte ?? '');
  bool _envoi = false;

  Future<void> _enregistrer() async {
    if (_titre.text.trim().isEmpty || _texte.text.trim().isEmpty) {
      afficher('Ajoutez un titre et le texte du cours.');
      return;
    }
    setState(() => _envoi = true);
    try {
      if (widget.existant == null) {
        await _cours.add({
          'niveau': widget.niveau,
          'matiere': widget.matiere,
          'titre': _titre.text.trim(),
          'texte': _texte.text.trim(),
          'auteurId': widget.editeur.uid,
          'auteurNom': widget.editeur.nom,
          'date': FieldValue.serverTimestamp(),
        });
      } else {
        await _cours.doc(widget.existant!.id).update({
          'titre': _titre.text.trim(),
          'texte': _texte.text.trim(),
        });
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
          Text('${widget.matiere} · ${widget.niveau}',
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
            minLines: 12,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Texte du cours', filled: true, fillColor: Colors.white),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _envoi ? null : _enregistrer,
            child: Text(_envoi ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}
