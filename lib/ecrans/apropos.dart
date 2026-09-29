import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../images.dart';
import '../modeles.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

const _messageParDefaut =
    'Bienvenue sur LFA News, le journal du Lycée Franco-Arabe de Kébémer. Ici, vous trouverez les annonces '
    "de l'établissement, les dates importantes et la vie de nos élèves, racontée par l'équipe de rédaction "
    "du club. Bonne lecture, et n'hésitez pas à partager nos articles.";
const _signatureParDefaut = 'La rédaction de LFA News';

final _config = FirebaseFirestore.instance.collection('config').doc('accueil');
final _contact = FirebaseFirestore.instance.collection('config').doc('contact');
final _equipe = FirebaseFirestore.instance.collection('equipe');
final _personnel = FirebaseFirestore.instance.collection('personnel');

class Bienvenue {
  const Bienvenue(this.message, this.signature);
  final String message;
  final String signature;
}

Stream<Bienvenue> suivreBienvenue() => _config.snapshots().map((d) {
      final m = d.data();
      final msg = (m?['message'] ?? '').toString().trim();
      final sig = (m?['signature'] ?? '').toString().trim();
      return Bienvenue(msg.isEmpty ? _messageParDefaut : msg, msg.isEmpty ? _signatureParDefaut : sig);
    }).handleError((_) {});

/// Carte de bienvenue en haut de l'accueil. Chaque lecteur peut la fermer ;
/// elle réapparaît si le message change.
class CarteBienvenue extends StatefulWidget {
  const CarteBienvenue({super.key});

  @override
  State<CarteBienvenue> createState() => _CarteBienvenueState();
}

class _CarteBienvenueState extends State<CarteBienvenue> {
  late final Stream<Bienvenue> _flux = suivreBienvenue();
  String? _fermee;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _fermee = p.getString('bienvenue_fermee') ?? '');
    });
  }

  Future<void> _fermer(String message) async {
    setState(() => _fermee = message.hashCode.toString());
    final p = await SharedPreferences.getInstance();
    await p.setString('bienvenue_fermee', message.hashCode.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (_fermee == null) return const SizedBox.shrink();
    return StreamBuilder<Bienvenue>(
      stream: _flux,
      initialData: const Bienvenue(_messageParDefaut, _signatureParDefaut),
      builder: (context, s) {
        final b = s.data!;
        if (_fermee == b.message.hashCode.toString()) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
          decoration: BoxDecoration(color: vertPale, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Bienvenue', style: titre(20, couleur: vert))),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close, size: 20, color: gris),
                    onPressed: () => _fermer(b.message),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.message, style: const TextStyle(fontSize: 15, height: 1.5)),
                    if (b.signature.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(b.signature,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: vert)),
                    ],
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

class PageAPropos extends StatefulWidget {
  const PageAPropos({super.key});

  @override
  State<PageAPropos> createState() => _PageAProposState();
}

class _PageAProposState extends State<PageAPropos> with SingleTickerProviderStateMixin {
  late final _onglets = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Editeur?>(
      valueListenable: Session.instance.editeur,
      builder: (context, ed, _) {
        final admin = ed?.estAdmin ?? false;
        return Scaffold(
          appBar: AppBar(
            title: Text('À propos', style: titre(22, couleur: Colors.white)),
            bottom: TabBar(
              controller: _onglets,
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFFBFE0CC),
              indicatorColor: Colors.white,
              tabs: const [Tab(text: 'La rédaction'), Tab(text: 'Établissement')],
            ),
          ),
          floatingActionButton: admin
              ? AnimatedBuilder(
                  animation: _onglets,
                  builder: (context, _) => FloatingActionButton.extended(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _onglets.index == 0 ? const EditerMembre() : const EditerPersonnel())),
                    backgroundColor: vert,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(_onglets.index == 0 ? 'Ajouter un membre' : 'Ajouter une fiche'),
                  ),
                )
              : null,
          body: TabBarView(
            controller: _onglets,
            children: [
              _ongletRedaction(admin),
              _ongletEtablissement(admin),
            ],
          ),
        );
      },
    );
  }

  Widget _ongletRedaction(bool admin) {
    return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              const Center(child: LogoLfa(taille: 96)),
              const SizedBox(height: 12),
              Center(child: Text('LFA NEWS', style: titre(30, couleur: vert))),
              const SizedBox(height: 4),
              const Center(
                child: Text('Le journal du Lycée Franco-Arabe de Kébémer',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: gris)),
              ),
              const SizedBox(height: 24),
              StreamBuilder<Bienvenue>(
                stream: suivreBienvenue(),
                initialData: const Bienvenue(_messageParDefaut, _signatureParDefaut),
                builder: (context, s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Le mot de bienvenue',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        if (admin)
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => EditerBienvenue(actuel: s.data!))),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Modifier'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s.data!.message, style: const TextStyle(fontSize: 15, height: 1.55)),
                    const SizedBox(height: 8),
                    Text(s.data!.signature,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: vert)),
                  ],
                ),
              ),
              const Divider(height: 40, color: bordure),
              _BlocContact(admin: admin),
              const Divider(height: 40, color: bordure),
              const Text("L'équipe de la rédaction", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _equipe.orderBy('ordre').snapshots(),
                builder: (context, s) {
                  if (!s.hasData) {
                    return const Padding(
                        padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                  }
                  final membres = s.data!.docs.map(Membre.fromDoc).toList();
                  if (membres.isEmpty) {
                    return const Text("La présentation de l'équipe arrive bientôt.",
                        style: TextStyle(color: gris));
                  }
                  return Column(
                    children: [
                      for (final m in membres)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: Photo(octets: m.octets, icone: Icons.person_outline),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(m.role,
                                        style: const TextStyle(
                                            fontSize: 14, color: vert, fontWeight: FontWeight.w700)),
                                    if (m.classe.isNotEmpty)
                                      Text(m.classe, style: const TextStyle(fontSize: 13, color: gris)),
                                  ],
                                ),
                              ),
                              if (admin)
                                IconButton(
                                  tooltip: 'Modifier',
                                  icon: const Icon(Icons.edit_outlined, color: gris),
                                  onPressed: () => Navigator.of(context)
                                      .push(MaterialPageRoute(builder: (_) => EditerMembre(membre: m))),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
  }

  Widget _ongletEtablissement(bool admin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _personnel.orderBy('ordre').snapshots(),
      builder: (context, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final gens = s.data!.docs.map(PersonnelLfa.fromDoc).toList();
        if (gens.isEmpty) {
          return messageVide("La présentation de l'équipe administrative et pédagogique arrive bientôt.");
        }
        final categories = <String, List<PersonnelLfa>>{};
        for (final p in gens) {
          categories.putIfAbsent(p.categorie.isEmpty ? 'Autres' : p.categorie, () => []).add(p);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            for (final e in categories.entries) ...[
              Text(e.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: vert)),
              const SizedBox(height: 8),
              for (final p in e.value)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      ClipOval(
                        child: SizedBox(width: 56, height: 56, child: Photo(octets: p.octets, icone: Icons.person_outline)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nom, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            Text(p.role, style: const TextStyle(fontSize: 13, color: gris)),
                          ],
                        ),
                      ),
                      if (admin)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: gris),
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => EditerPersonnel(personne: p))),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
            ],
          ],
        );
      },
    );
  }
}

class EditerBienvenue extends StatefulWidget {
  const EditerBienvenue({super.key, required this.actuel});
  final Bienvenue actuel;

  @override
  State<EditerBienvenue> createState() => _EditerBienvenueState();
}

class _EditerBienvenueState extends State<EditerBienvenue> {
  late final _message = TextEditingController(text: widget.actuel.message);
  late final _signature = TextEditingController(text: widget.actuel.signature);

  void _enregistrer() {
    unawaited(_config
        .set({'message': _message.text.trim(), 'signature': _signature.text.trim()})
        .catchError((e) => afficher('Échec : $e')));
    afficher('Message de bienvenue enregistré.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message de bienvenue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _message,
            minLines: 6,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _signature, decoration: const InputDecoration(labelText: 'Signature')),
          const SizedBox(height: 20),
          FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}

class EditerMembre extends StatefulWidget {
  const EditerMembre({super.key, this.membre});
  final Membre? membre;

  @override
  State<EditerMembre> createState() => _EditerMembreState();
}

class _EditerMembreState extends State<EditerMembre> {
  late final _nom = TextEditingController(text: widget.membre?.nom ?? '');
  late final _role = TextEditingController(text: widget.membre?.role ?? '');
  late final _classe = TextEditingController(text: widget.membre?.classe ?? '');
  late String _photo = widget.membre?.photo ?? '';
  late Uint8List? _apercu = widget.membre?.octets;

  Future<void> _choisir(ImageSource source) async {
    final b = await choisirPhoto(source);
    if (b == null) return;
    final petite = await compute(reduire, (b, 320));
    setState(() {
      _photo = petite;
      _apercu = b;
    });
  }

  void _enregistrer() {
    if (_nom.text.trim().isEmpty || _role.text.trim().isEmpty) {
      afficher('Indiquez au moins le nom et le rôle.');
      return;
    }
    final data = {
      'nom': _nom.text.trim(),
      'role': _role.text.trim(),
      'classe': _classe.text.trim(),
      'photo': _photo,
    };
    final m = widget.membre;
    if (m == null) {
      unawaited(_equipe.add({...data, 'ordre': DateTime.now().millisecondsSinceEpoch})
          .then((_) {})
          .catchError((e) => afficher('Échec : $e')));
    } else {
      unawaited(_equipe.doc(m.id).update(data).catchError((e) => afficher('Échec : $e')));
    }
    afficher('Équipe mise à jour.');
    Navigator.of(context).pop();
  }

  Future<void> _retirer() async {
    final m = widget.membre;
    if (m == null) return;
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Retirer ${m.nom} de l’équipe ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (oui != true) return;
    unawaited(_equipe.doc(m.id).delete().catchError((e) => afficher('Échec : $e')));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.membre == null ? 'Nouveau membre' : 'Modifier le membre'),
        actions: [
          if (widget.membre != null)
            IconButton(tooltip: 'Retirer', icon: const Icon(Icons.delete_outline), onPressed: _retirer),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ClipOval(
              child: SizedBox(width: 110, height: 110, child: Photo(octets: _apercu, icone: Icons.person_outline)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _choisir(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galerie'),
              ),
              TextButton.icon(
                onPressed: () => _choisir(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Appareil'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Prénom et nom')),
          const SizedBox(height: 12),
          TextField(
            controller: _role,
            decoration: const InputDecoration(
                labelText: 'Rôle', hintText: 'Rédactrice, photographe, relecteur, responsable…'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _classe, decoration: const InputDecoration(labelText: 'Classe (facultatif)')),
          const SizedBox(height: 20),
          FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}

class EditerPersonnel extends StatefulWidget {
  const EditerPersonnel({super.key, this.personne});
  final PersonnelLfa? personne;

  @override
  State<EditerPersonnel> createState() => _EditerPersonnelState();
}

class _EditerPersonnelState extends State<EditerPersonnel> {
  static const _categories = ['Direction', 'Administration', 'Professeurs', 'Autres'];

  late final _nom = TextEditingController(text: widget.personne?.nom ?? '');
  late final _role = TextEditingController(text: widget.personne?.role ?? '');
  late String _categorie =
      _categories.contains(widget.personne?.categorie) ? widget.personne!.categorie : _categories.first;
  late String _photo = widget.personne?.photo ?? '';
  late Uint8List? _apercu = widget.personne?.octets;

  Future<void> _choisir(ImageSource source) async {
    final b = await choisirPhoto(source);
    if (b == null) return;
    final petite = await compute(reduire, (b, 320));
    setState(() {
      _photo = petite;
      _apercu = b;
    });
  }

  void _enregistrer() {
    if (_nom.text.trim().isEmpty || _role.text.trim().isEmpty) {
      afficher('Indiquez au moins le nom et la fonction.');
      return;
    }
    final data = {
      'nom': _nom.text.trim(),
      'role': _role.text.trim(),
      'categorie': _categorie,
      'photo': _photo,
    };
    final m = widget.personne;
    if (m == null) {
      unawaited(_personnel
          .add({...data, 'ordre': DateTime.now().millisecondsSinceEpoch})
          .then((_) {})
          .catchError((e) => afficher('Échec : $e')));
    } else {
      unawaited(_personnel.doc(m.id).update(data).catchError((e) => afficher('Échec : $e')));
    }
    afficher('Fiche enregistrée.');
    Navigator.of(context).pop();
  }

  Future<void> _retirer() async {
    final m = widget.personne;
    if (m == null) return;
    final oui = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Retirer ${m.nom} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (oui != true) return;
    unawaited(_personnel.doc(m.id).delete().catchError((e) => afficher('Échec : $e')));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personne == null ? 'Nouvelle fiche' : 'Modifier la fiche'),
        actions: [
          if (widget.personne != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _retirer),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ClipOval(
              child: SizedBox(width: 110, height: 110, child: Photo(octets: _apercu, icone: Icons.person_outline)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _choisir(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galerie'),
              ),
              TextButton.icon(
                onPressed: () => _choisir(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Appareil'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _categorie,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _categorie = v ?? _categorie),
          ),
          const SizedBox(height: 12),
          TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Prénom et nom')),
          const SizedBox(height: 12),
          TextField(
            controller: _role,
            decoration: const InputDecoration(labelText: 'Fonction', hintText: 'Proviseur, surveillant général…'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}

class Contact {
  const Contact(this.telephone, this.email);
  final String telephone;
  final String email;
}

Stream<Contact> suivreContact() => _contact.snapshots().map((d) {
      final m = d.data();
      return Contact((m?['telephone'] ?? '').toString().trim(), (m?['email'] ?? '').toString().trim());
    }).handleError((_) {});

Future<void> _ouvrir(Uri uri) async {
  try {
    final ok = await launchUrl(uri);
    if (!ok) afficher("Impossible d'ouvrir ce lien sur ce téléphone.");
  } catch (_) {
    afficher("Impossible d'ouvrir ce lien sur ce téléphone.");
  }
}

class _BlocContact extends StatelessWidget {
  const _BlocContact({required this.admin});
  final bool admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Contact>(
      stream: suivreContact(),
      initialData: const Contact('', ''),
      builder: (context, s) {
        final c = s.data ?? const Contact('', '');
        final vide = c.telephone.isEmpty && c.email.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Nous contacter', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                if (admin)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => EditerContact(actuel: c))),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifier'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (vide)
              const Text('Les coordonnées de la rédaction seront bientôt disponibles.',
                  style: TextStyle(color: gris, height: 1.4))
            else ...[
              if (c.telephone.isNotEmpty)
                _ligneContact(Icons.phone_outlined, c.telephone, 'Appeler',
                    () => _ouvrir(Uri(scheme: 'tel', path: c.telephone.replaceAll(RegExp(r'[^0-9+]'), '')))),
              if (c.email.isNotEmpty)
                _ligneContact(Icons.mail_outline, c.email, 'Écrire un e-mail',
                    () => _ouvrir(Uri(scheme: 'mailto', path: c.email, queryParameters: {'subject': 'LFA News'}))),
            ],
          ],
        );
      },
    );
  }

  Widget _ligneContact(IconData icone, String valeur, String action, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: vertPale, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: vert, child: Icon(icone, color: Colors.white, size: 20)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(valeur, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(action, style: const TextStyle(fontSize: 12, color: gris)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: gris),
            ],
          ),
        ),
      ),
    );
  }
}

class EditerContact extends StatefulWidget {
  const EditerContact({super.key, required this.actuel});
  final Contact actuel;

  @override
  State<EditerContact> createState() => _EditerContactState();
}

class _EditerContactState extends State<EditerContact> {
  late final _tel = TextEditingController(text: widget.actuel.telephone);
  late final _mail = TextEditingController(text: widget.actuel.email);

  void _enregistrer() {
    unawaited(_contact
        .set({'telephone': _tel.text.trim(), 'email': _mail.text.trim()})
        .catchError((e) => afficher('Échec : $e')));
    afficher('Coordonnées enregistrées.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nous contacter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone', hintText: '+221 77 000 00 00'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mail,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Adresse e-mail'),
          ),
          const SizedBox(height: 8),
          const Text('Laissez un champ vide pour ne pas l’afficher.',
              style: TextStyle(fontSize: 12, color: gris)),
          const SizedBox(height: 20),
          FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
