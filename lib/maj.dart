import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

const _depot = 'msanghare9-bit/lfanews';

class InfoMiseAJour {
  const InfoMiseAJour(this.version, this.lien);
  final String version;
  final String lien;
}

List<int> _decouper(String v) {
  final chiffres = v.split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  while (chiffres.length < 3) {
    chiffres.add(0);
  }
  return chiffres;
}

bool _estPlusRecente(String distante, String locale) {
  final d = _decouper(distante);
  final l = _decouper(locale);
  for (var i = 0; i < 3; i++) {
    if (d[i] != l[i]) return d[i] > l[i];
  }
  return false;
}

/// Vérifie s'il existe une version plus récente sur GitHub. Renvoie null si
/// l'application est à jour, sans connexion, ou en cas d'erreur.
Future<InfoMiseAJour?> verifierMiseAJour() async {
  try {
    final actuelle = (await PackageInfo.fromPlatform()).version;
    final r = await http
        .get(
          Uri.parse('https://api.github.com/repos/$_depot/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final tag = (j['tag_name'] ?? '').toString().replaceFirst('v', '');
    final assets = (j['assets'] as List?) ?? [];
    if (tag.isEmpty || assets.isEmpty) return null;
    final apk = assets.firstWhere(
      (a) => (a['name'] ?? '').toString().endsWith('.apk'),
      orElse: () => null,
    );
    if (apk == null) return null;
    if (!_estPlusRecente(tag, actuelle)) return null;
    return InfoMiseAJour(tag, apk['browser_download_url'].toString());
  } catch (_) {
    return null;
  }
}

class BandeauMiseAJour extends StatefulWidget {
  const BandeauMiseAJour({super.key});

  @override
  State<BandeauMiseAJour> createState() => _BandeauMiseAJourState();
}

class _BandeauMiseAJourState extends State<BandeauMiseAJour> {
  late final Future<InfoMiseAJour?> _info = verifierMiseAJour();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InfoMiseAJour?>(
      future: _info,
      builder: (context, s) {
        final info = s.data;
        if (info == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: vert, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.system_update_alt, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouvelle version disponible (${info.version})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    const Text('Téléchargez-la, puis installez-la par-dessus.',
                        style: TextStyle(color: Color(0xFFD6EDDD), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => launchUrl(Uri.parse(info.lien), mode: LaunchMode.externalApplication),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: vert,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Télécharger'),
              ),
            ],
          ),
        );
      },
    );
  }
}
