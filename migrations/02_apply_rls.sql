-- =====================================================================
-- APPLIQUER RLS — Phenix Rapports (politique d'équipe)
-- =====================================================================
-- Modèle de sécurité retenu pour cette app :
--   ✅ Tout utilisateur authentifié (membre Phenix Solar avec compte)
--      peut LIRE / CRÉER / MODIFIER / SUPPRIMER toutes les données.
--   ❌ Personne d'autre (rôle anon, non connecté) ne peut accéder à rien.
--
-- Pourquoi cette politique ?
--   - C'est une app interne d'équipe (Phenix Solar). Tous les utilisateurs
--     authentifiés doivent voir TOUTES les données pour collaborer.
--   - Le seul risque est qu'un acteur externe (non connecté) accède
--     aux données → bloqué par RLS.
--
-- ⚠ Si plus tard tu veux une isolation PAR UTILISATEUR (chacun ne voit que ses
-- propres chantiers), il faudra remplacer les USING (true) par USING (created_by = auth.uid())
-- et ajouter une colonne created_by uuid à chaque table. Pas pour maintenant.
--
-- ⚠ EXÉCUTION : copier-coller dans l'éditeur SQL Supabase, puis Run.
-- Idempotent : peut être ré-exécuté sans casser. Les politiques sont
-- supprimées puis recréées proprement.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Activer RLS sur toutes les tables (sécurité par défaut)
-- ---------------------------------------------------------------------
ALTER TABLE public.chantiers                       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intervenants                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.liens_chantier_intervenant      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photos                          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reserves                        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visites                         ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- 2) Supprimer toutes les politiques existantes (pour reset propre)
-- ---------------------------------------------------------------------
DO $$
DECLARE pol record;
BEGIN
  FOR pol IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('chantiers','intervenants','liens_chantier_intervenant',
                        'photos','reserves','visites')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, pol.tablename);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 3) Créer une politique "team" sur chaque table :
--    - Tout utilisateur authentifié a tous les droits
--    - Le rôle anon n'a aucun droit
-- ---------------------------------------------------------------------

-- chantiers
CREATE POLICY "auth_full_access" ON public.chantiers
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- intervenants
CREATE POLICY "auth_full_access" ON public.intervenants
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- liens_chantier_intervenant
CREATE POLICY "auth_full_access" ON public.liens_chantier_intervenant
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- photos
CREATE POLICY "auth_full_access" ON public.photos
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- reserves
CREATE POLICY "auth_full_access" ON public.reserves
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- visites
CREATE POLICY "auth_full_access" ON public.visites
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ---------------------------------------------------------------------
-- 4) Vérification — relancer le script d'audit pour confirmer
-- ---------------------------------------------------------------------
SELECT
  tablename,
  rowsecurity AS rls_active,
  (SELECT count(*) FROM pg_policies p WHERE p.schemaname='public' AND p.tablename=t.tablename) AS nb_policies
FROM pg_tables t
WHERE schemaname = 'public'
  AND tablename IN ('chantiers','intervenants','liens_chantier_intervenant','photos','reserves','visites')
ORDER BY tablename;
-- Résultat attendu :
--   chantiers           | true | 1
--   intervenants        | true | 1
--   liens_chantier_int  | true | 1
--   photos              | true | 1
--   reserves            | true | 1
--   visites             | true | 1


-- =====================================================================
-- SUPABASE STORAGE — politique sur le bucket "rapports Photos"
-- =====================================================================
-- Les photos sont stockées dans le bucket "rapports Photos".
-- Par défaut, un bucket public est lisible par tous, écriture authentifiée.
-- Si tu veux RESTREINDRE la lecture aux utilisateurs authentifiés :
--   → Dashboard Supabase → Storage → bucket "rapports Photos" → décocher "Public"
--   → Puis créer ces policies dans Storage:
-- =====================================================================

-- Lecture des objets du bucket : authentifiés uniquement
-- (À exécuter dans le SQL editor une fois le bucket marqué non-public)
--
-- CREATE POLICY "auth_read_rapports_photos" ON storage.objects
--   FOR SELECT TO authenticated
--   USING (bucket_id = 'rapports Photos');
--
-- CREATE POLICY "auth_insert_rapports_photos" ON storage.objects
--   FOR INSERT TO authenticated
--   WITH CHECK (bucket_id = 'rapports Photos');
--
-- CREATE POLICY "auth_delete_rapports_photos" ON storage.objects
--   FOR DELETE TO authenticated
--   USING (bucket_id = 'rapports Photos');
--
-- ⚠ Si tu rends le bucket privé, il faut aussi modifier le code de l'app
-- pour utiliser getSignedUrl() au lieu de getPublicUrl() (changement plus profond).
-- À discuter avant de basculer.
