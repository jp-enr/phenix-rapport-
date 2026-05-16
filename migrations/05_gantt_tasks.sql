-- =====================================================================
-- TABLE gantt_tasks — Planning chantier (lots et jalons)
-- =====================================================================
-- Objectif : permettre la planification de macro-phases d'un chantier
-- sous forme de Gantt drag-and-drop.
--
-- Deux types de tâches :
--   - 'lot'   : période sur plusieurs jours (date_debut ≠ date_fin)
--               ex: "Pose structures", "Câblage électrique"
--   - 'jalon' : un seul jour (date_debut = date_fin)
--               ex: "Réception COFRAC", "Mise en service"
--
-- ⚠ EXÉCUTION : copier-coller dans l'éditeur SQL Supabase, puis Run.
-- Idempotent (IF NOT EXISTS). Peut être ré-exécuté sans risque.
-- =====================================================================

-- 1) Création de la table
CREATE TABLE IF NOT EXISTS public.gantt_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chantier_id uuid NOT NULL REFERENCES public.chantiers(id) ON DELETE CASCADE,
  nom text NOT NULL,
  type text NOT NULL DEFAULT 'lot' CHECK (type IN ('lot', 'jalon')),
  date_debut date NOT NULL,
  date_fin date NOT NULL, -- pour un jalon, date_fin = date_debut
  progression smallint NOT NULL DEFAULT 0 CHECK (progression BETWEEN 0 AND 100),
  couleur text DEFAULT '#0D4484', -- couleur de la barre dans le Gantt
  ordre smallint DEFAULT 0, -- pour trier l'affichage
  description text, -- description optionnelle
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2) Index pour les requêtes fréquentes (par chantier, tri par ordre)
CREATE INDEX IF NOT EXISTS idx_gantt_tasks_chantier
  ON public.gantt_tasks (chantier_id, ordre, date_debut);

-- 3) Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION public.gantt_tasks_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_gantt_tasks_update ON public.gantt_tasks;
CREATE TRIGGER trg_gantt_tasks_update
  BEFORE UPDATE ON public.gantt_tasks
  FOR EACH ROW EXECUTE FUNCTION public.gantt_tasks_update_timestamp();

-- 4) RLS (sécurité) : même politique que les autres tables (auth full access)
ALTER TABLE public.gantt_tasks ENABLE ROW LEVEL SECURITY;

-- Supprimer toute policy existante (idempotent)
DROP POLICY IF EXISTS "auth_full_access" ON public.gantt_tasks;

-- Créer la politique
CREATE POLICY "auth_full_access" ON public.gantt_tasks
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 5) Vérification
SELECT
  schemaname,
  tablename,
  rowsecurity AS rls_active
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'gantt_tasks';
-- Résultat attendu : 1 ligne avec rls_active = true
