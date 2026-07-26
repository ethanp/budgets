-- Category envelopes removed; clients compute rolling 30-day spend instead.
-- DROP TABLE also removes the relation from the powersync publication.
DROP TABLE IF EXISTS category_budgets;
