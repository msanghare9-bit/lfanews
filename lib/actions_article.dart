import 'package:flutter/material.dart';

import 'app.dart';
import 'direct_service.dart';
import 'ecrans/redaction.dart';
import 'modeles.dart';
import 'publication.dart';
import 'session.dart';
import 'theme.dart';

/// Feuille d'actions rapides sur un article publié (administrateur seulement).
Future<void> menuActionsArticle(BuildContext context, Editeur ed, Article a) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(a.titre,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (a.directId.isEmpty)
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: vert),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(c);
                modifierArticle(context, ed, a);
              },
            ),
          ListTile(
            leading: Icon(a.epingle ? Icons.push_pin : Icons.push_pin_outlined, color: vert),
            title: Text(a.epingle ? 'Retirer de la une' : 'Mettre à la une'),
            onTap: () async {
              Navigator.pop(c);
              await modifierChamp(a, 'epingle', !a.epingle);
              afficher(a.epingle ? "L'article n'est plus à la une." : "L'article est maintenant à la une.");
            },
          ),
          ListTile(
            leading: Icon(Icons.campaign_outlined, color: a.urgent ? orangeUrgent : vert),
            title: Text(a.urgent ? 'Retirer le bandeau urgent' : 'Marquer comme urgent'),
            onTap: () async {
              Navigator.pop(c);
              await modifierChamp(a, 'urgent', !a.urgent);
              afficher(a.urgent ? 'Bandeau urgent retiré.' : "L'article est affiché dans le bandeau urgent.");
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: orangeUrgent),
            title: const Text('Supprimer', style: TextStyle(color: orangeUrgent)),
            onTap: () {
              Navigator.pop(c);
              supprimerAvecConfirmation(context, a);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void modifierArticle(BuildContext context, Editeur ed, Article a) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => Redaction(editeur: ed, existant: a)));
}

Future<bool> supprimerAvecConfirmation(BuildContext context, Article a) async {
  final oui = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Supprimer cet article ?'),
      content: Text('« ${a.titre} » sera définitivement supprimé.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
      ],
    ),
  );
  if (oui != true) return false;
  try {
    if (a.directId.isNotEmpty) await supprimerDirect(a.directId);
    await supprimer(a);
    afficher('Article supprimé.');
    return true;
  } catch (e) {
    afficher('Échec de la suppression : $e');
    return false;
  }
}
