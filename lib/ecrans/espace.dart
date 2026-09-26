import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../modeles.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'article.dart';
import 'redaction.dart';

class EspaceRedaction extends StatelessWidget {
  const EspaceRedaction({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) => ed == null ? const Connexion() : _Espace(ed: ed),
    );
  }
}

class Connexion extends StatefulWidget {
  const Connexion({super.key});

  @override
  State<Connexion> createState() => _ConnexionState();
}

class _ConnexionState extends State<Connexion> {
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  bool _chargement = false;
  String? _erreur;

  Future<void> _connecter() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: _email.text.trim(), password: _mdp.text);
      final ed = await Session.chargerEditeur(cred.user!.uid);
      if (ed == null) {
        await FirebaseAuth.instance.signOut();
        _erreur = "Ce compte n'a pas accès à la rédaction. Demandez au responsable du club.";
      } else {
        Session.instance.editeur.value = ed;
      }
    } on FirebaseAuthException catch (e) {
      _erreur = (e.code == 'network-request-failed')
          ? 'Pas de connexion internet.'
          : 'Adresse e-mail ou mot de passe incorrect.';
    } catch (_) {
      _erreur = 'La connexion a échoué. Réessayez.';
    }
    if (mounted) setState(() => _chargement = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rédaction', style: titre(22))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Cet espace est réservé à l'équipe de rédaction du club. Connectez-vous avec le compte que vous a donné le responsable.",
            style: TextStyle(fontSize: 15, height: 1.5, color: gris),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Adresse e-mail'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mdp,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
            onSubmitted: (_) => _connecter(),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 12),
            Text(_erreur!, style: const TextStyle(color: orangeUrgent, fontSize: 14)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _chargement ? null : _connecter,
            child: Text(_chargement ? 'Connexion…' : 'Se connecter'),
          ),
        ],
      ),
    );
  }
}

class _Espace extends StatelessWidget {
  const _Espace({required this.ed});
  final Editeur ed;

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('propositions');
    final Query<Map<String, dynamic>> requete =
        ed.estAdmin ? col.orderBy('date', descending: true) : col.where('auteurId', isEqualTo: ed.uid);
    return Scaffold(
      appBar: AppBar(
        title: Text('Rédaction', style: titre(22)),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 4),
          Text('Bonjour ${ed.nom}', style: titre(22)),
          const SizedBox(height: 4),
          Text(ed.estAdmin ? 'Responsable de la rédaction' : 'Rédacteur du club',
              style: const TextStyle(color: gris)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => Redaction(editeur: ed))),
            icon: const Icon(Icons.add),
            label: const Text('Nouvel article'),
          ),
          const SizedBox(height: 26),
          Text(ed.estAdmin ? 'Articles à valider' : 'Mes articles en attente de validation',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: requete.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return messageVide('Impossible de charger la liste.');
              if (!snap.hasData) {
                return const Padding(
                    padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              final liste = snap.data!.docs.map(Article.fromDoc).toList()
                ..sort((x, y) => y.date.compareTo(x.date));
              if (liste.isEmpty) {
                return messageVide(ed.estAdmin
                    ? 'Aucun article en attente.'
                    : 'Aucun article en attente. Vos articles validés apparaissent sur l’accueil.');
              }
              return Column(
                children: [
                  for (final a in liste)
                    LigneArticle(
                      article: a,
                      etiquette: ed.estAdmin ? '${a.categorie} · par ${a.auteurNom}' : a.categorie,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => PageArticle(article: a))),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
