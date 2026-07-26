-- Align stay-chain table name with the Housing domain language.
-- Publication membership follows the table OID across rename.

ALTER TABLE IF EXISTS homebase_stays RENAME TO housing_stays;
