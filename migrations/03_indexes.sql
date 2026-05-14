-- =====================================================================
-- INDEXES — Phenix Rapports
-- =====================================================================
-- Objectif : accélérer les requêtes les plus fréquentes de l'app.
-- Sans index, PostgreSQL fait un "full table scan" → lent dès qu'il y a
-- quelques milliers de lignes. Avec index, accès en O(log n).
--
-- Mesure d'impact attendu :
--   - Liste des visites d'un chantier : 5-10x plus rapide
--   - Filtre par statut/date : ~10x plus rapide
--   - Photos d'une visite/réserve : ~5x plus rapide
--
-- ⚠ EXÉCUTION : copier-coller dans l'éditeur SQL Supabase, puis Run.
-- Idempotent (IF NOT EXISTS). Peut être ré-exécuté sans risque.
-- Durée : ~1 seconde par index sur une petite table.
-- =====================================================================

-- ---------------------------------------------------------------------
-- VISITES — requêtes fréquentes : par chantier, par type, par date, archive
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_visites_chantier_id     ON public.visites (chantier_id);
CREATE INDEX IF NOT EXISTS idx_visites_type_visite     ON public.visites (type_visite);
CREATE INDEX IF NOT EXISTS idx_visites_archivee        ON public.visites (archivee);
CREATE INDEX IF NOT EXISTS idx_visites_date_visite     ON public.visites (date_visite DESC);
CREATE INDEX IF NOT EXISTS idx_visites_entreprise_id   ON public.visites (entreprise_id);
-- Index composite pour la requête principale (liste des visites d'un chantier d'un type donné, triée par date)
CREATE INDEX IF NOT EXISTS idx_visites_chantier_type_date
  ON public.visites (chantier_id, type_visite, date_visite DESC);

-- ---------------------------------------------------------------------
-- RESERVES — requêtes fréquentes : par visite, par chantier, par statut, échéance
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_reserves_visite_id      ON public.reserves (visite_id);
CREATE INDEX IF NOT EXISTS idx_reserves_chantier_id    ON public.reserves (chantier_id);
CREATE INDEX IF NOT EXISTS idx_reserves_statut         ON public.reserves (statut);
CREATE INDEX IF NOT EXISTS idx_reserves_echeance       ON public.reserves (echeance);
CREATE INDEX IF NOT EXISTS idx_reserves_responsable_id ON public.reserves (responsable_id);
-- Index pour le dashboard "réserves en retard"
CREATE INDEX IF NOT EXISTS idx_reserves_statut_echeance
  ON public.reserves (statut, echeance) WHERE statut = 'Ouverte';

-- ---------------------------------------------------------------------
-- PHOTOS — requêtes fréquentes : par visite, par chantier, par réserve, par type d'attache
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_photos_visite_id        ON public.photos (visite_id);
CREATE INDEX IF NOT EXISTS idx_photos_chantier_id      ON public.photos (chantier_id);
CREATE INDEX IF NOT EXISTS idx_photos_reserve_id       ON public.photos (reserve_id);
CREATE INDEX IF NOT EXISTS idx_photos_attachee_a       ON public.photos (attachee_a);

-- ---------------------------------------------------------------------
-- LIENS_CHANTIER_INTERVENANT — requêtes fréquentes : par chantier, par intervenant
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_liens_chantier_id       ON public.liens_chantier_intervenant (chantier_id);
CREATE INDEX IF NOT EXISTS idx_liens_intervenant_id    ON public.liens_chantier_intervenant (intervenant_id);

-- ---------------------------------------------------------------------
-- INTERVENANTS — requêtes fréquentes : par archive, par membre Phenix, par email
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_intervenants_archive    ON public.intervenants (archive);
CREATE INDEX IF NOT EXISTS idx_intervenants_phenix     ON public.intervenants (membre_phenix_solar);
CREATE INDEX IF NOT EXISTS idx_intervenants_email      ON public.intervenants (lower(email));

-- ---------------------------------------------------------------------
-- CHANTIERS — requêtes fréquentes : par archive, par code (recherche)
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_chantiers_archive       ON public.chantiers (archive);
-- Index pour les recherches "ILIKE %...%" sur le code et le nom (utilise pg_trgm)
-- Active l'extension trgm si pas déjà fait :
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_chantiers_code_trgm     ON public.chantiers USING gin (code gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_chantiers_nom_trgm      ON public.chantiers USING gin (nom gin_trgm_ops);

-- ---------------------------------------------------------------------
-- VÉRIFICATION — liste les index créés avec leur taille
-- ---------------------------------------------------------------------
SELECT
  pi.schemaname,
  pi.tablename,
  pi.indexname,
  pg_size_pretty(pg_relation_size(pc.oid)) AS taille
FROM pg_indexes pi
JOIN pg_class pc ON pc.relname = pi.indexname
WHERE pi.schemaname = 'public'
  AND pi.indexname LIKE 'idx_%'
ORDER BY pi.tablename, pi.indexname;
