import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'modeles.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets.dart';

const _emailProfesseurs = 'professeur@lfanews.com';

final _profsListe = FirebaseFirestore.instance.collection('profs_liste');
final _config = FirebaseFirestore.instance.collection('config');

String _slug(String nom) {
  const accents = 'àâäáãåèêëéìîïíòôöóõùûüúçñ';
  const sans = 'aaaaaaeeeeiiiiooooouuuucn';
  var t = nom.toLowerCase().trim();
  for (var i = 0; i < accents.length; i++) {
    t = t.replaceAll(accents[i], sans[i]);
  }
  t = t.replaceAll(RegExp(r"[^a-z0-9\s-]"), '').replaceAll(RegExp(r'\s+'), '-');
  return t.isEmpty ? 'professeur-${DateTime.now().millisecondsSinceEpoch}' : t;
}

/// Crée un compte d'authentification sans déconnecter l'administrateur :
/// une application Firebase secondaire, ouverte le temps de créer le compte
/// puis refermée aussitôt.
Future<String> creerCompteAuthentification(String email, String motDePasse) async {
  final app = await Firebase.initializeApp(
    name: 'creation_${DateTime.now().microsecondsSinceEpoch}',
    options: firebaseOptions,
  );
  try {
    final auth = FirebaseAuth.instanceFor(app: app);
    final cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: motDePasse);
    await auth.signOut();
    return cred.user!.uid;
  } finally {
    await app.delete();
  }
}

String messageErreurAuth(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'Ce compte existe déjà.';
    case 'weak-password':
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    case 'network-request-failed':
      return 'Pas de connexion internet.';
    default:
      return 'Échec (${e.code}).';
  }
}

/// Le compte partagé de tous les professeurs : un seul e-mail, un seul mot
/// de passe, communiqué à toute l'équipe pédagogique.
class CompteProfesseurs extends StatelessWidget {
  const CompteProfesseurs({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _config.doc('compte_professeurs').snapshots(),
      builder: (context, s) {
        final existe = s.data?.data()?['existe'] == true;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: vertPale, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Compte partagé des professeurs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              if (existe) ...[
                const Text('Un seul compte, à donner à toute l’équipe pédagogique :',
                    style: TextStyle(fontSize: 13, color: gris)),
                const SizedBox(height: 4),
                const SelectableText(_emailProfesseurs, style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'Chaque professeur touche son nom une fois connecté, parmi ceux que vous avez ajoutés ci-dessous.',
                  style: TextStyle(fontSize: 12, color: gris),
                ),
              ] else ...[
                const Text(
                  'Créez un compte unique, avec un seul mot de passe que vous donnerez à tous les professeurs.',
                  style: TextStyle(fontSize: 13, color: gris),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _creer(context),
                  child: const Text('Créer le compte partagé'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _creer(BuildContext context) async {
    final controleur = TextEditingController();
    final motDePasse = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mot de passe du compte partagé'),
        content: TextField(
          controller: controleur,
          decoration: const InputDecoration(hintText: '6 caractères au moins'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, controleur.text), child: const Text('Créer')),
        ],
      ),
    );
    if (motDePasse == null || motDePasse.length < 6) {
      if (motDePasse != null) afficher('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    try {
      final uid = await creerCompteAuthentification(_emailProfesseurs, motDePasse);
      await FirebaseFirestore.instance.collection('editeurs').doc(uid).set({'nom': 'Professeurs', 'role': 'professeur'});
      await _config.doc('compte_professeurs').set({'existe': true});
      afficher('Compte créé. Adresse : $_emailProfesseurs');
    } on FirebaseAuthException catch (e) {
      afficher(messageErreurAuth(e));
    } catch (e) {
      afficher('Échec : $e');
    }
  }
}

/// La liste des noms de professeurs, chacun avec ses niveaux et matières.
class ListeProfesseurs extends StatelessWidget {
  const ListeProfesseurs({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _profsListe.snapshots(),
      builder: (context, s) {
        if (s.hasError) return messageVide('Impossible de charger la liste des professeurs.');
        if (!s.hasData) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        final liste = s.data!.docs
            .map((d) => ProfNomme(
                  d.id,
                  (d.data()['nom'] ?? '').toString(),
                  ((d.data()['niveaux'] as List?) ?? []).map((e) => e.toString()).toList(),
                  ((d.data()['matieres'] as List?) ?? []).map((e) => e.toString()).toList(),
                ))
            .toList()
          ..sort((a, b) => a.nom.compareTo(b.nom));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Noms des professeurs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text('Chaque professeur touchera son nom une fois connecté avec le compte partagé.',
                style: TextStyle(fontSize: 13, color: gris)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AjouterProfesseur())),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Ajouter un professeur'),
              ),
            ),
            const SizedBox(height: 8),
            if (liste.isEmpty)
              messageVide('Aucun professeur ajouté pour le moment.', icone: Icons.person_outline),
            for (final p in liste)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: vertPale, child: Icon(Icons.person, color: vert)),
                title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: Text(
                  p.niveaux.isEmpty && p.matieres.isEmpty
                      ? 'Tous niveaux, toutes matières'
                      : '${p.matieres.join(', ')} · ${p.niveaux.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: gris),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: gris),
                  onSelected: (v) {
                    if (v == 'modifier') {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => AjouterProfesseur(existant: p)));
                    } else {
                      _retirer(context, p);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'modifier', child: Text('Modifier ses niveaux et matières')),
                    PopupMenuItem(value: 'retirer', child: Text('Retirer')),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _retirer(BuildContext context, ProfNomme p) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Retirer ${p.nom} ?'),
        content: const Text('Ce nom n’apparaîtra plus dans la liste. Ses cours déjà publiés restent en ligne.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (oui != true) return;
    try {
      await _profsListe.doc(p.id).delete();
      afficher('Nom retiré.');
    } catch (e) {
      afficher('Échec : $e');
    }
  }
}

class AjouterProfesseur extends StatefulWidget {
  const AjouterProfesseur({super.key, this.existant});
  final ProfNomme? existant;

  @override
  State<AjouterProfesseur> createState() => _AjouterProfesseurState();
}

class _AjouterProfesseurState extends State<AjouterProfesseur> {
  final _nom = TextEditingController();
  final Set<String> _niveauxChoisis = {};
  final Set<String> _matieresChoisies = {};
  bool _envoi = false;

  bool get _modification => widget.existant != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    if (e != null) {
      _nom.text = e.nom;
      _niveauxChoisis.addAll(e.niveaux);
      _matieresChoisies.addAll(e.matieres);
    }
  }

  Future<void> _enregistrer() async {
    if (_nom.text.trim().isEmpty) {
      afficher('Indiquez le nom du professeur.');
      return;
    }
    setState(() => _envoi = true);
    try {
      final data = {
        'nom': _nom.text.trim(),
        'niveaux': _niveauxChoisis.toList(),
        'matieres': _matieresChoisies.toList(),
      };
      final id = widget.existant?.id ?? _slug(_nom.text);
      await _profsListe.doc(id).set(data);
      afficher(_modification ? 'Modifications enregistrées.' : 'Professeur ajouté.');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      afficher('Échec : $e');
      if (mounted) setState(() => _envoi = false);
    }
  }

  Widget _puce(String texte, bool choisi, VoidCallback onTap) {
    return FilterChip(
      label: Text(texte),
      selected: choisi,
      onSelected: (_) => onTap(),
      selectedColor: vert,
      backgroundColor: Colors.white,
      side: BorderSide(color: choisi ? vert : bordureChamp),
      showCheckmark: false,
      labelStyle: TextStyle(color: choisi ? Colors.white : encre, fontWeight: choisi ? FontWeight.w700 : FontWeight.w400),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vertPale,
      appBar: AppBar(
        backgroundColor: vert,
        foregroundColor: Colors.white,
        surfaceTintColor: vert,
        title: Text(_modification ? 'Modifier le professeur' : 'Ajouter un professeur',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Nom', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(controller: _nom, textCapitalization: TextCapitalization.words),
          const SizedBox(height: 18),
          const Text('Niveaux autorisés', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Ne rien cocher pour autoriser tous les niveaux.', style: TextStyle(fontSize: 12, color: gris)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in niveaux)
                _puce(n, _niveauxChoisis.contains(n), () => setState(() {
                      if (!_niveauxChoisis.remove(n)) _niveauxChoisis.add(n);
                    })),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Matières autorisées', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Ne rien cocher pour autoriser toutes les matières.', style: TextStyle(fontSize: 12, color: gris)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in matieres)
                _puce(m, _matieresChoisies.contains(m), () => setState(() {
                      if (!_matieresChoisies.remove(m)) _matieresChoisies.add(m);
                    })),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _envoi ? null : _enregistrer,
            child: Text(_envoi ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}

/// Écran où le professeur, une fois connecté avec le compte partagé,
/// touche son propre nom pour la durée de sa session.
class ChoixProfesseur extends StatelessWidget {
  const ChoixProfesseur({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Qui êtes-vous ?', style: titre(22)),
        const SizedBox(height: 6),
        const Text('Touchez votre nom pour retrouver vos cours et vos niveaux.',
            style: TextStyle(fontSize: 14, color: gris)),
        const SizedBox(height: 18),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _profsListe.orderBy('nom').snapshots(),
          builder: (context, s) {
            if (!s.hasData) {
              return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
            }
            final liste = s.data!.docs
                .map((d) => ProfNomme(
                      d.id,
                      (d.data()['nom'] ?? '').toString(),
                      ((d.data()['niveaux'] as List?) ?? []).map((e) => e.toString()).toList(),
                      ((d.data()['matieres'] as List?) ?? []).map((e) => e.toString()).toList(),
                    ))
                .toList();
            if (liste.isEmpty) {
              return messageVide('Aucun nom n’a encore été ajouté par le responsable.', icone: Icons.person_outline);
            }
            return Column(
              children: [
                for (final p in liste)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: vertPale,
                      child: Text(initiales(p.nom), style: const TextStyle(color: vert, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right, color: gris),
                    onTap: () => Session.instance.profActif.value = p,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
