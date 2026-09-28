import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../actions_article.dart';
import '../modeles.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'article.dart';
import '../professeurs.dart';
import 'cours.dart' as ecours;
import 'direct.dart';
import 'emission.dart';
import 'redaction.dart';
import 'statistiques.dart';
import 'videos.dart';

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
    return ed.estAdmin ? _EspaceAdmin(ed: ed) : _EspaceMembre(ed: ed);
  }
}

class _EspaceMembre extends StatelessWidget {
  const _EspaceMembre({required this.ed});
  final Editeur ed;

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('propositions');
    final Query<Map<String, dynamic>> requete = col.where('auteurId', isEqualTo: ed.uid);
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
          Text(ed.role == 'professeur' ? 'Professeur' : 'Rédacteur du club', style: const TextStyle(color: gris)),
          const SizedBox(height: 18),
          if (ed.role != 'professeur')
            FilledButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => Redaction(editeur: ed))),
              icon: const Icon(Icons.add),
              label: const Text('Nouvel article'),
            ),
          if (ed.role != 'professeur') ...[
            const SizedBox(height: 26),
            const Text('Mes articles en attente de validation',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
                  return messageVide('Aucun article en attente. Vos articles validés apparaissent sur l’accueil.');
                }
                return Column(
                  children: [
                    for (final a in liste)
                      LigneArticle(
                        article: a,
                        etiquette: a.categorie,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => PageArticle(article: a))),
                      ),
                  ],
                );
              },
            ),
          ],
          if (ed.peutCours) _SectionMesCours(ed: ed),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Liste des cours d'un professeur, ou de tous pour l'administrateur.
class _SectionMesCours extends StatelessWidget {
  const _SectionMesCours({required this.ed});
  final Editeur ed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Text(ed.estAdmin ? 'Cours ajoutés' : 'Mes cours',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Touchez ⋮ pour modifier ou supprimer un cours.', style: TextStyle(fontSize: 13, color: gris)),
        const SizedBox(height: 6),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: (ed.estAdmin
                  ? FirebaseFirestore.instance.collection('cours')
                  : FirebaseFirestore.instance.collection('cours').where('auteurId', isEqualTo: ed.uid))
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return messageVide('Impossible de charger vos cours.');
            if (!snap.hasData) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            final mesCours = snap.data!.docs.map(Cours.fromDoc).toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            if (mesCours.isEmpty) {
              return messageVide('Aucun cours ajouté pour le moment.', icone: Icons.menu_book_outlined);
            }
            return Column(
              children: [
                for (final c in mesCours)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                        backgroundColor: vertPale, child: Icon(Icons.menu_book_outlined, color: vert)),
                    title: Text(c.titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    subtitle: Text(
                      c.serie.isEmpty
                          ? '${c.matiere} · ${c.niveau}${ed.estAdmin ? ' · ${c.auteurNom}' : ''}'
                          : '${c.matiere} · ${c.niveau} série ${c.serie}${ed.estAdmin ? ' · ${c.auteurNom}' : ''}',
                      style: const TextStyle(fontSize: 12, color: gris),
                    ),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecours.LectureCours(cours: c))),
                    trailing: (ed.estAdmin || c.auteurId == ed.uid)
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: gris),
                            onSelected: (v) async {
                              if (v == 'modifier') {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ecours.EditerCours(
                                        editeur: ed,
                                        niveau: c.niveau,
                                        matiere: c.matiere,
                                        serie: c.serie,
                                        existant: c)));
                              } else {
                                final oui = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Supprimer ce cours ?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                                    ],
                                  ),
                                );
                                if (oui == true) {
                                  await FirebaseFirestore.instance.collection('cours').doc(c.id).delete();
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                              PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                            ],
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EspaceAdmin extends StatefulWidget {
  const _EspaceAdmin({required this.ed});
  final Editeur ed;

  @override
  State<_EspaceAdmin> createState() => _EspaceAdminState();
}

class _EspaceAdminState extends State<_EspaceAdmin> with SingleTickerProviderStateMixin {
  late final _onglets = TabController(length: 3, vsync: this);
  Editeur get ed => widget.ed;

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        bottom: TabBar(
          controller: _onglets,
          labelColor: vert,
          unselectedLabelColor: gris,
          indicatorColor: vert,
          tabs: const [Tab(text: 'Responsable'), Tab(text: 'Rédacteurs'), Tab(text: 'Professeurs')],
        ),
      ),
      body: TabBarView(
        controller: _onglets,
        children: [
          _ongletResponsable(),
          _ongletRedacteurs(),
          _ongletProfesseurs(),
        ],
      ),
    );
  }

  Widget _ongletResponsable() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),
        Text('Bonjour ${ed.nom}', style: titre(22)),
        const SizedBox(height: 4),
        const Text('Responsable de la rédaction', style: TextStyle(color: gris)),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Redaction(editeur: ed))),
          icon: const Icon(Icons.add),
          label: const Text('Nouvel article'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LancerDirect(editeur: ed))),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
          icon: const Icon(Icons.sensors),
          label: const Text('Lancer un direct'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => NouvelleEmission(editeur: ed))),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2F5E44)),
          icon: const Icon(Icons.headphones),
          label: const Text('Programmer une émission'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditerVideo())),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF187A47)),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Ajouter une vidéo'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Statistiques())),
          icon: const Icon(Icons.bar_chart),
          label: const Text('Statistiques'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: vert,
            side: const BorderSide(color: vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 26),
        const Text('Articles publiés', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Touchez ⋮ pour modifier ou supprimer un article.', style: TextStyle(fontSize: 13, color: gris)),
        const SizedBox(height: 6),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('articles')
              .orderBy('date', descending: true)
              .limit(60)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return messageVide('Impossible de charger la liste.');
            if (!snap.hasData) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            final publies = snap.data!.docs.map(Article.fromDoc).toList();
            if (publies.isEmpty) return messageVide('Aucun article publié pour le moment.');
            return Column(
              children: [
                for (final a in publies)
                  Row(
                    children: [
                      Expanded(
                        child: LigneArticle(
                          article: a,
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PageArticle(article: a))),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: gris),
                        onSelected: (v) {
                          if (v == 'modifier') modifierArticle(context, ed, a);
                          if (v == 'supprimer') supprimerAvecConfirmation(context, a);
                        },
                        itemBuilder: (_) => [
                          if (a.directId.isEmpty) const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                          const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                        ],
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _ongletRedacteurs() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        const Text('Articles à valider', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Les articles proposés par les élèves du club apparaissent ici.',
            style: TextStyle(fontSize: 13, color: gris)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('propositions')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return messageVide('Impossible de charger la liste.');
            if (!snap.hasData) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            final liste = snap.data!.docs.map(Article.fromDoc).toList();
            if (liste.isEmpty) return messageVide('Aucun article en attente.');
            return Column(
              children: [
                for (final a in liste)
                  LigneArticle(
                    article: a,
                    etiquette: '${a.categorie} · par ${a.auteurNom}',
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PageArticle(article: a))),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _ongletProfesseurs() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        const ListeProfesseurs(),
        const SizedBox(height: 28),
        _SectionMesCours(ed: ed),
        const SizedBox(height: 8),
      ],
    );
  }
}
