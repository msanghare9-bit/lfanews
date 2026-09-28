import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'modeles.dart';
import 'theme.dart';
import 'widgets.dart';

final _editeurs = FirebaseFirestore.instance.collection('editeurs');

class Professeur {
  Professeur(this.uid, this.nom, this.niveaux, this.matieres);
  final String uid;
  final String nom;
  final List<String> niveaux;
  final List<String> matieres;

  factory Professeur.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    List<String> lst(String c) => (d[c] is List) ? (d[c] as List).map((e) => e.toString()).toList() : <String>[];
    return Professeur(doc.id, (d['nom'] ?? '').toString(), lst('niveaux'), lst('matieres'));
  }
}

/// Crée un compte d'authentification sans déconnecter l'administrateur :
/// on utilise une application Firebase secondaire, le temps de créer le
/// compte, puis on la referme aussitôt.
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
      return 'Cette adresse e-mail est déjà utilisée par un autre compte.';
    case 'invalid-email':
      return 'Adresse e-mail non valide.';
    case 'weak-password':
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    case 'network-request-failed':
      return 'Pas de connexion internet.';
    default:
      return 'La création du compte a échoué (${e.code}).';
  }
}

class ListeProfesseurs extends StatelessWidget {
  const ListeProfesseurs({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _editeurs.where('role', isEqualTo: 'professeur').snapshots(),
      builder: (context, s) {
        if (s.hasError) return messageVide('Impossible de charger la liste des professeurs.');
        if (!s.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        final liste = s.data!.docs.map(Professeur.fromDoc).toList()..sort((a, b) => a.nom.compareTo(b.nom));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Professeurs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AjouterProfesseur())),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Ajouter'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
                ),
              ],
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
                    PopupMenuItem(value: 'retirer', child: Text('Retirer l’accès')),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _retirer(BuildContext context, Professeur p) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Retirer l’accès de ${p.nom} ?'),
        content: const Text('Son compte ne pourra plus se connecter à la rédaction. Ses cours déjà publiés restent en ligne.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (oui != true) return;
    try {
      await _editeurs.doc(p.uid).delete();
      afficher('Accès retiré.');
    } catch (e) {
      afficher('Échec : $e');
    }
  }
}

class AjouterProfesseur extends StatefulWidget {
  const AjouterProfesseur({super.key, this.existant});
  final Professeur? existant;

  @override
  State<AjouterProfesseur> createState() => _AjouterProfesseurState();
}

class _AjouterProfesseurState extends State<AjouterProfesseur> {
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
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
    if (!_modification && (_email.text.trim().isEmpty || _motDePasse.text.length < 6)) {
      afficher('Adresse e-mail et mot de passe (6 caractères minimum) sont nécessaires.');
      return;
    }
    setState(() => _envoi = true);
    try {
      final data = {
        'nom': _nom.text.trim(),
        'role': 'professeur',
        'niveaux': _niveauxChoisis.toList(),
        'matieres': _matieresChoisies.toList(),
      };
      if (_modification) {
        await _editeurs.doc(widget.existant!.uid).update(data);
        afficher('Modifications enregistrées.');
      } else {
        final uid = await creerCompteAuthentification(_email.text, _motDePasse.text);
        await _editeurs.doc(uid).set(data);
        afficher('Compte créé. Communiquez l’adresse et le mot de passe au professeur.');
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      afficher(messageErreurAuth(e));
      if (mounted) setState(() => _envoi = false);
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
          if (!_modification) ...[
            const SizedBox(height: 16),
            const Text('Adresse e-mail', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'exemple@lfanews.com'),
            ),
            const SizedBox(height: 16),
            const Text('Mot de passe', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(controller: _motDePasse, decoration: const InputDecoration(hintText: '6 caractères au moins')),
          ],
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
            child: Text(_envoi ? 'Enregistrement…' : (_modification ? 'Enregistrer' : 'Créer le compte')),
          ),
        ],
      ),
    );
  }
}
