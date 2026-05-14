=====================================================================
  MIGRATIONS — Phenix Rapports
=====================================================================

Ce dossier contient les scripts SQL et les instructions à appliquer
côté Supabase (pas dans l'app web).

Ordre d'exécution recommandé :

  1. 01_audit_rls.sql       → AUDIT (lecture seule, sans risque)
                              Lance-le d'abord pour voir l'état actuel.

  2. 02_apply_rls.sql       → APPLIQUE la sécurité RLS
                              ⚠ Modifie les politiques. Idempotent.

  3. 03_indexes.sql         → AJOUTE les index de performance
                              Sans risque, accélère les requêtes.

  4. 04_backups_instructions.txt → CHECKLIST manuelle (pas du SQL)
                              À lire et appliquer dans l'UI Supabase.

Comment exécuter un script SQL :

  → Dashboard Supabase → Sidebar → SQL Editor → New query
  → Copier-coller le contenu du fichier .sql
  → Cliquer "Run" (en bas à droite)

Tous les scripts SQL sont idempotents : tu peux les ré-exécuter sans
casser quoi que ce soit. Ils sont conçus pour ça.

=====================================================================
