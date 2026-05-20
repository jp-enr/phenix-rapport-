-- =====================================================================
-- COLONNES type_reserve + entreprise_vt_id sur la table reserves
-- =====================================================================
-- Objectif : permettre la "remontée" des réserves entre visites :
--   - type_reserve : 'VC' ou 'VT' (à quel type de visite la réserve appartient)
--   - entreprise_vt_id : pour les réserves de VT, l'entreprise concernée
--     → une réserve ouverte sur une VT remonte automatiquement sur la
--       prochaine VT de LA MÊME entreprise sur le même chantier.
--
-- Sans ces colonnes, le filtre de remontée échoue et les réserves
-- ne remontent pas d'une VT à l'autre.
--
-- ⚠ EXÉCUTION : copier-coller dans l'éditeur SQL Supabase, puis Run.
-- Idempotent (IF NOT EXISTS). Sans risque, ré-exécutable.
-- =====================================================================

-- 1) Colonne type_reserve ('VC' par défaut pour l'existant)
ALTER TABLE public.reserves
  ADD COLUMN IF NOT EXISTS type_reserve text NOT NULL DEFAULT 'VC';

-- 2) Colonne entreprise_vt_id (FK vers intervenants, nullable)
ALTER TABLE public.reserves
  ADD COLUMN IF NOT EXISTS entreprise_vt_id uuid REFERENCES public.intervenants(id) ON DELETE SET NULL;

-- 3) Index pour accélérer la remontée des réserves par entreprise
CREATE INDEX IF NOT EXISTS idx_reserves_type_entreprise
  ON public.reserves (chantier_id, type_reserve, entreprise_vt_id);

-- 4) Backfill : pour les réserves VT existantes sans entreprise_vt_id,
--    on récupère l'entreprise depuis la visite mère (si dispo)
UPDATE public.reserves r
SET entreprise_vt_id = v.entreprise_id,
    type_reserve = COALESCE(NULLIF(r.type_reserve, ''), v.type_visite, 'VC')
FROM public.visites v
WHERE r.visite_id = v.id
  AND v.type_visite = 'VT'
  AND r.entreprise_vt_id IS NULL
  AND v.entreprise_id IS NOT NULL;

-- 5) Vérification
SELECT
  column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'reserves'
  AND column_name IN ('type_reserve', 'entreprise_vt_id')
ORDER BY column_name;
-- Résultat attendu : 2 lignes (entreprise_vt_id uuid, type_reserve text)
