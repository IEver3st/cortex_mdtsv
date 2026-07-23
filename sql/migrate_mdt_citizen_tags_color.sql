-- Adds per-tag color for citizen tags (right-click palette in MDT UI).
ALTER TABLE `mdt_citizen_tags`
  ADD COLUMN `color` VARCHAR(16) NOT NULL DEFAULT 'blue' AFTER `label`;
