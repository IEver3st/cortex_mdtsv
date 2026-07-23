-- Cortex MDT Citations migration
-- Run this migration to add citation support to the MDT

CREATE TABLE IF NOT EXISTS `mdt_citations` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citation_number` VARCHAR(32) NOT NULL,
    `report_number` VARCHAR(32) DEFAULT NULL,
    `report_id` INT DEFAULT NULL,
    `report_title` VARCHAR(255) DEFAULT NULL,
    `issued_to_citizen_id` VARCHAR(64) NOT NULL,
    `issued_to_name` VARCHAR(128) NOT NULL,
    `issued_by_callsign` VARCHAR(32) DEFAULT NULL,
    `issued_by_name` VARCHAR(128) DEFAULT NULL,
    `issued_by_rank` VARCHAR(64) DEFAULT NULL,
    `issued_by_department` VARCHAR(128) DEFAULT NULL,
    `issued_by_department_short` VARCHAR(8) DEFAULT NULL,
    `charges` JSON NOT NULL,
    `total_fine` INT DEFAULT 0,
    `notes` TEXT DEFAULT NULL,
    `status` VARCHAR(16) DEFAULT 'pending',
    `issued_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `issued_sort` INT DEFAULT NULL,
    INDEX `idx_citizen_id` (`issued_to_citizen_id`),
    INDEX `idx_report_id` (`report_id`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
