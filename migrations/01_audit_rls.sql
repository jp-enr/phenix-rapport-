-- =====================================================================
-- AUDIT RLS — Phenix Rapports
-- =====================================================================
-- Objectif : voir l'état actuel des politiques de sécurité (Row Level Security)
-- sur les tables de l'application.
--
-- ⚠ EXÉCUTION : copier-coller ce fichier dans l'éditeur SQL de Supabase
-- (Dashboard → SQL Editor → New query → coller → Run)
-- Ne modifie rien, c'est juste un audit.
-- =====================================================================

-- 1) RLS est-il activé sur chaque table ?
SELECT
  schemaname,
  tablename,
  rowsecurity AS rls_active,
  CASE WHEN rowsecurity THEN '✓ Protégé' ELSE '⚠ EXPOSÉ' END AS statut
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('chantiers', 'intervenants', 'liens_chantier_intervenant',
                    'photos', 'reserves', 'visites')
ORDER BY tablename;

-- 2) Liste des politiques RLS existantes
SELECT
  schemaname,
  tablename,
  policyname,
  CASE
    WHEN cmd = 'r' THEN 'SELECT'
    WHEN cmd = 'a' THEN 'INSERT'
    WHEN cmd = 'w' THEN 'UPDATE'
    WHEN cmd = 'd' THEN 'DELETE'
    WHEN cmd = '*' THEN 'ALL'
    ELSE cmd::text
  END AS operation,
  roles,
  qual AS condition_using,
  with_check AS condition_with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd;

-- 3) Vérification rôle "anon" : peut-il accéder aux tables sensibles ?
-- (À exécuter manuellement avec l'API key anon pour vérifier)
-- Exemple : curl "https://svjdtykwnaaendgoqhrk.supabase.co/rest/v1/chantiers?select=*"
--          -H "apikey: <ANON_KEY>"
--          → doit retourner [] ou une erreur 401 si RLS bien configuré
