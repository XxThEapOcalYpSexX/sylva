# SYLVA 7 — architecture et mise en route

## Livré dans cette archive

Application locale compatible avec les données SYLVA 6 : accueil avec prénom, graphique des heures par jour, états « Facturé » et « Payé », barre de navigation plus compacte. `supabase-schema.sql` est une **base de travail** pour la migration multi-entreprises, pas un backend déjà déployé ni audité.

## Important avant la mise à jour

1. Dans SYLVA, exporter une sauvegarde JSON et la conserver dans Fichiers/iCloud.
2. Remplacer les fichiers de GitHub Pages après décompression (ne pas envoyer le ZIP directement).
3. Vérifier le déploiement GitHub Actions et actualiser Safari.
4. Ne pas supprimer les données du site ni désinstaller la PWA sans sauvegarde.

## Phase suivante : authentification réelle

- Créer un projet Supabase ; garder l'URL et la clé **anon/publishable** pour la configuration du client. **Ne jamais exposer la clé service_role.**
- Exécuter et tester le schéma dans un environnement de test. Les politiques RLS doivent être revues et testées (notamment la création de comptes, l'affectation à une entreprise, les transferts et la protection des données inter-entreprises).
- Activer la connexion par code/lien e-mail ; prévoir un prestataire SMS avant la connexion par téléphone.
- Développer un backend de confiance (Edge Functions) pour invitations, création des profils et des entreprises, changements de rôles et audit. Ne jamais donner au navigateur les droits de créer un administrateur.
- Mettre en place un import JSON explicite et validé des données locales, puis un mécanisme de synchronisation avec résolution des conflits.
- Mettre les photos dans un bucket privé avec des règles d'accès par entreprise, et non dans le dépôt public.
- Pour les rappels automatiques : Web Push sur PWA iOS installée, autorisation utilisateur, gestion des abonnements push et fonction planifiée côté serveur ; en attendant, utiliser l'application Rappels d'Apple.
- Générer les rapports PDF dans une version ultérieure.

## Règles métier

- Ouvrier : ses journées du mois civil courant uniquement, et uniquement les chantiers attribués ; ne peut pas modifier un chantier clôturé.
- Patron : ouvriers, machines, entretiens, chantiers et statuts de son entreprise uniquement ; corrections des anciens mois.
- Administrateur global : toutes les entreprises, avec traçabilité des actions sensibles.
- Statuts : à venir → en cours → terminé → facturé → payé, avec possibilité de correction contrôlée par patron/admin.
- Solde quotidien : minutes travaillées − 540 ; la journée de nuit est affectée à la date de début.
- Volumes : stères = longueur × largeur × hauteur ; conversion indicative m³ = stères × 0,63 uniquement pour les produits autorisés.

## Ce qui n'est pas encore activé

Connexion réelle, comptes patrons/ouvriers, synchronisation multi-iPhone, verrouillages côté serveur, gestion complète des machines/entretiens, photos, carte interactive, notifications push et PDF. **Ne pas utiliser la version locale comme un système multi-entreprises en production.**
