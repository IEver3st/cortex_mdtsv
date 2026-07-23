-- ═══════════════════════════════════════════════════════════
-- CORTEX MDT — Database Schema
-- Run this once to initialize all MDT tables.
-- Uses oxmysql (MySQL/MariaDB).
-- ═══════════════════════════════════════════════════════════

-- Officers / Personnel
CREATE TABLE IF NOT EXISTS `mdt_officers` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizen_id` VARCHAR(64) DEFAULT NULL,
    `identifier` VARCHAR(64) NOT NULL,
    `first_name` VARCHAR(64) NOT NULL,
    `last_name` VARCHAR(64) NOT NULL,
    `callsign` VARCHAR(16) DEFAULT NULL,
    `rank` VARCHAR(32) DEFAULT 'Officer',
    `department` VARCHAR(32) DEFAULT 'police',
    `avatar` TEXT DEFAULT NULL,
    `certifications` JSON DEFAULT '[]',
    `status` ENUM('active','suspended','terminated','loa') DEFAULT 'active',
    `hired_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Citizens / Civilian Profiles
CREATE TABLE IF NOT EXISTS `mdt_citizens` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizen_id` VARCHAR(64) NOT NULL,
    `first_name` VARCHAR(64) NOT NULL,
    `last_name` VARCHAR(64) NOT NULL,
    `dob` VARCHAR(16) DEFAULT NULL,
    `gender` VARCHAR(16) DEFAULT NULL,
    `phone` VARCHAR(20) DEFAULT NULL,
    `mugshot` TEXT DEFAULT NULL,
    `fingerprint` VARCHAR(128) DEFAULT NULL,
    `occupation` VARCHAR(64) DEFAULT NULL,
    `properties` JSON DEFAULT '[]',
    `flags` JSON DEFAULT '[]',
    `notes` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_citizen_id` (`citizen_id`),
    KEY `idx_name` (`first_name`, `last_name`),
    KEY `idx_fingerprint` (`fingerprint`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Citizen Licenses
CREATE TABLE IF NOT EXISTS `mdt_citizen_licenses` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizen_id` VARCHAR(64) NOT NULL,
    `type` VARCHAR(32) NOT NULL,
    `status` ENUM('valid','suspended','revoked','expired') DEFAULT 'valid',
    `issued_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    KEY `idx_citizen` (`citizen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Citizen Tags
CREATE TABLE IF NOT EXISTS `mdt_citizen_tags` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizen_id` VARCHAR(64) NOT NULL,
    `label` VARCHAR(64) NOT NULL,
    `color` VARCHAR(16) NOT NULL DEFAULT 'blue',
    `created_by` INT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_citizen` (`citizen_id`),
    UNIQUE KEY `uk_citizen_tag` (`citizen_id`, `label`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Vehicles
CREATE TABLE IF NOT EXISTS `mdt_vehicles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(16) NOT NULL,
    `vin` VARCHAR(32) DEFAULT NULL,
    `owner_citizen_id` VARCHAR(64) DEFAULT NULL,
    `model` VARCHAR(64) DEFAULT NULL,
    `color` VARCHAR(32) DEFAULT NULL,
    `vehicle_class` VARCHAR(32) DEFAULT NULL,
    `registration_status` ENUM('valid','expired','suspended','stolen','unregistered') DEFAULT 'valid',
    `flags` JSON DEFAULT '[]',
    `notes` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_plate` (`plate`),
    KEY `idx_owner` (`owner_citizen_id`),
    KEY `idx_vin` (`vin`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Vehicle Impounds
CREATE TABLE IF NOT EXISTS `mdt_impounds` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `vehicle_id` INT NOT NULL,
    `plate` VARCHAR(16) NOT NULL,
    `officer_id` INT NOT NULL,
    `reason` TEXT DEFAULT NULL,
    `lot_location` VARCHAR(64) DEFAULT 'Downtown Lot',
    `fee` INT DEFAULT 0,
    `hold_until` TIMESTAMP NULL DEFAULT NULL,
    `status` ENUM('impounded','released','auctioned') DEFAULT 'impounded',
    `released_by` INT DEFAULT NULL,
    `released_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_vehicle` (`vehicle_id`),
    KEY `idx_plate` (`plate`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Incident Reports
CREATE TABLE IF NOT EXISTS `mdt_reports` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `report_number` VARCHAR(32) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `template` VARCHAR(32) DEFAULT 'general',
    `narrative` LONGTEXT DEFAULT NULL,
    `author_id` INT NOT NULL,
    `department` VARCHAR(32) DEFAULT 'police',
    `status` ENUM('draft','submitted','approved','rejected','archived') DEFAULT 'draft',
    `priority` ENUM('low','normal','high','critical') DEFAULT 'normal',
    `tags` JSON DEFAULT '[]',
    `restricted` TINYINT(1) DEFAULT 0,
    `restricted_to` JSON DEFAULT '[]',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_report_number` (`report_number`),
    KEY `idx_author` (`author_id`),
    KEY `idx_status` (`status`),
    KEY `idx_department` (`department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Report Timeline Events
CREATE TABLE IF NOT EXISTS `mdt_report_timeline` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `report_id` INT NOT NULL,
    `timestamp` VARCHAR(32) NOT NULL,
    `description` TEXT NOT NULL,
    `author_id` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_report` (`report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Report Entity Tags (citizens, vehicles, evidence linked to a report)
CREATE TABLE IF NOT EXISTS `mdt_report_entities` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `report_id` INT NOT NULL,
    `entity_type` ENUM('citizen','vehicle','evidence','officer') NOT NULL,
    `entity_id` INT NOT NULL,
    `role` VARCHAR(32) DEFAULT 'involved',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_report` (`report_id`),
    KEY `idx_entity` (`entity_type`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Structured Report Participants
CREATE TABLE IF NOT EXISTS `mdt_report_participants` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `report_id` INT NOT NULL,
    `participant_type` ENUM('suspect','victim','officer','witness','other') DEFAULT 'suspect',
    `name` VARCHAR(128) NOT NULL,
    `citizen_id` VARCHAR(64) DEFAULT NULL,
    `officer_id` INT DEFAULT NULL,
    `notes` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_report` (`report_id`),
    KEY `idx_participant_type` (`participant_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Structured Report Charges
CREATE TABLE IF NOT EXISTS `mdt_report_charges` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `report_id` INT NOT NULL,
    `charge` VARCHAR(128) NOT NULL,
    `severity` ENUM('infraction','misdemeanor','felony') DEFAULT 'misdemeanor',
    `count` INT DEFAULT 1,
    `fine` INT DEFAULT 0,
    `notes` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_report` (`report_id`),
    KEY `idx_charge_severity` (`severity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Issued citations generated from MDT reports
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
    `issued_by_department_short` VARCHAR(16) DEFAULT NULL,
    `charges` JSON NOT NULL,
    `total_fine` INT DEFAULT 0,
    `notes` TEXT DEFAULT NULL,
    `status` ENUM('pending','viewed','paid','voided') DEFAULT 'pending',
    `issued_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `issued_sort` BIGINT DEFAULT NULL,
    UNIQUE KEY `uk_citation_number` (`citation_number`),
    KEY `idx_citation_citizen` (`issued_to_citizen_id`),
    KEY `idx_citation_report` (`report_id`),
    KEY `idx_citation_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Report Collaborators (officers working on a report)
CREATE TABLE IF NOT EXISTS `mdt_report_collaborators` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `report_id` INT NOT NULL,
    `officer_id` INT NOT NULL,
    `added_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_collab` (`report_id`, `officer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Cases / Investigations
CREATE TABLE IF NOT EXISTS `mdt_cases` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `case_number` VARCHAR(32) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `description` LONGTEXT DEFAULT NULL,
    `lead_officer_id` INT NOT NULL,
    `department` VARCHAR(32) DEFAULT 'police',
    `status` ENUM('open','pending_warrant','under_review','closed','cold') DEFAULT 'open',
    `priority` ENUM('low','normal','high','critical') DEFAULT 'normal',
    `restricted` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_case_number` (`case_number`),
    KEY `idx_lead` (`lead_officer_id`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Case assigned personnel
CREATE TABLE IF NOT EXISTS `mdt_case_personnel` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `case_id` INT NOT NULL,
    `officer_id` INT NOT NULL,
    `role` VARCHAR(32) DEFAULT 'assigned',
    `added_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_case_officer` (`case_id`, `officer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Case linked entities (reports, evidence, citizens)
CREATE TABLE IF NOT EXISTS `mdt_case_links` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `case_id` INT NOT NULL,
    `entity_type` ENUM('report','evidence','citizen','vehicle') NOT NULL,
    `entity_id` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_case_link` (`case_id`, `entity_type`, `entity_id`),
    KEY `idx_case` (`case_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Evidence Records
CREATE TABLE IF NOT EXISTS `mdt_evidence` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `evidence_id` VARCHAR(32) NOT NULL,
    `type` VARCHAR(32) DEFAULT 'general',
    `serial_number` VARCHAR(64) DEFAULT NULL,
    `description` TEXT NOT NULL,
    `photo_url` TEXT DEFAULT NULL,
    `stash_location` VARCHAR(64) DEFAULT NULL,
    `collected_by` INT NOT NULL,
    `status` ENUM('in_custody','transferred','released','destroyed','in_lab') DEFAULT 'in_custody',
    `report_id` INT DEFAULT NULL,
    `case_id` INT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_evidence_id` (`evidence_id`),
    KEY `idx_report` (`report_id`),
    KEY `idx_case` (`case_id`),
    KEY `idx_serial` (`serial_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Evidence Chain of Custody
CREATE TABLE IF NOT EXISTS `mdt_evidence_custody` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `evidence_id` INT NOT NULL,
    `action` VARCHAR(64) NOT NULL,
    `from_officer` INT DEFAULT NULL,
    `to_officer` INT DEFAULT NULL,
    `from_location` VARCHAR(64) DEFAULT NULL,
    `to_location` VARCHAR(64) DEFAULT NULL,
    `notes` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_evidence` (`evidence_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Attachment / file metadata
CREATE TABLE IF NOT EXISTS `mdt_attachments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `parent_type` ENUM('case','evidence','report') NOT NULL,
    `parent_id` INT NOT NULL,
    `file_name` VARCHAR(255) NOT NULL,
    `file_url` TEXT NOT NULL,
    `file_type` VARCHAR(64) DEFAULT NULL,
    `uploaded_by` INT NOT NULL,
    `notes` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_parent` (`parent_type`, `parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Weapons Registry
CREATE TABLE IF NOT EXISTS `mdt_weapons` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `serial_number` VARCHAR(64) NOT NULL,
    `owner_citizen_id` VARCHAR(64) DEFAULT NULL,
    `owner_name` VARCHAR(128) DEFAULT NULL,
    `weapon_type` VARCHAR(64) DEFAULT NULL,
    `make` VARCHAR(64) DEFAULT NULL,
    `model` VARCHAR(64) DEFAULT NULL,
    `caliber` VARCHAR(32) DEFAULT NULL,
    `status` ENUM('registered','flagged','seized','stolen','destroyed') DEFAULT 'registered',
    `notes` TEXT DEFAULT NULL,
    `image_url` TEXT DEFAULT NULL,
    `registered_by` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_weapon_serial` (`serial_number`),
    KEY `idx_owner` (`owner_citizen_id`),
    KEY `idx_weapon_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_weapon_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `weapon_id` INT NOT NULL,
    `action` VARCHAR(32) NOT NULL,
    `from_owner_citizen_id` VARCHAR(64) DEFAULT NULL,
    `to_owner_citizen_id` VARCHAR(64) DEFAULT NULL,
    `officer_id` INT NOT NULL,
    `notes` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_weapon_history_weapon` (`weapon_id`),
    KEY `idx_weapon_history_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- BOLOs
CREATE TABLE IF NOT EXISTS `mdt_bolos` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `type` ENUM('person','vehicle','weapon','other') DEFAULT 'person',
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT NOT NULL,
    `citizen_id` VARCHAR(64) DEFAULT NULL,
    `plate` VARCHAR(16) DEFAULT NULL,
    `vehicle_description` VARCHAR(255) DEFAULT NULL,
    `weapon_description` VARCHAR(255) DEFAULT NULL,
    `photo_url` TEXT DEFAULT NULL,
    `issued_by` INT NOT NULL,
    `department` VARCHAR(32) DEFAULT 'police',
    `status` ENUM('active','apprehended','cleared','expired') DEFAULT 'active',
    `report_id` INT DEFAULT NULL,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY `idx_status` (`status`),
    KEY `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Warrants
CREATE TABLE IF NOT EXISTS `mdt_warrants` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizen_id` VARCHAR(64) NOT NULL,
    `citizen_name` VARCHAR(128) NOT NULL,
    `charges` JSON DEFAULT '[]',
    `description` TEXT DEFAULT NULL,
    `issued_by` INT NOT NULL,
    `approved_by` INT DEFAULT NULL,
    `department` VARCHAR(32) DEFAULT 'police',
    `status` ENUM('pending','active','served','expired','recalled') DEFAULT 'pending',
    `report_id` INT DEFAULT NULL,
    `bolo_id` INT DEFAULT NULL,
    `served_by` INT DEFAULT NULL,
    `served_at` TIMESTAMP NULL DEFAULT NULL,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY `idx_citizen` (`citizen_id`),
    KEY `idx_status` (`status`),
    KEY `idx_served_by` (`served_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Active Units (real-time state, frequently updated)
CREATE TABLE IF NOT EXISTS `mdt_units` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `callsign` VARCHAR(16) NOT NULL,
    `officer_id` INT NOT NULL,
    `department` VARCHAR(32) DEFAULT 'police',
    `status` ENUM('available','busy','enroute','scene','en_route','on_scene','emergency','off_duty') DEFAULT 'available',
    `assignment` VARCHAR(255) DEFAULT NULL,
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_officer` (`officer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- CCTV Cameras
CREATE TABLE IF NOT EXISTS `mdt_cameras` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `cam_id` VARCHAR(64) NOT NULL,
    `cam_label` VARCHAR(128) NOT NULL,
    `cam_type` ENUM('placed','dynamic','store','bank','jewelry','government','medical','other') DEFAULT 'placed',
    `model` VARCHAR(64) NOT NULL DEFAULT 'security_cam_03',
    `coords` JSON NOT NULL,
    `rotation` JSON NOT NULL,
    `image` TEXT DEFAULT NULL,
    `can_rotate` TINYINT(1) DEFAULT 1,
    `is_online` TINYINT(1) DEFAULT 1,
    `spawns_model` TINYINT(1) DEFAULT 1,
    `created_by` VARCHAR(128) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_cam_id` (`cam_id`),
    KEY `idx_cam_online` (`is_online`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- MOTD / Announcements
CREATE TABLE IF NOT EXISTS `mdt_announcements` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `title` VARCHAR(255) NOT NULL,
    `content` TEXT NOT NULL,
    `author_id` INT NOT NULL,
    `department` VARCHAR(32) DEFAULT NULL,
    `pinned` TINYINT(1) DEFAULT 0,
    `active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Audit / Compliance Logs
CREATE TABLE IF NOT EXISTS `mdt_audit_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `officer_id` INT NOT NULL,
    `action` VARCHAR(64) NOT NULL,
    `category` VARCHAR(32) DEFAULT 'general',
    `target_type` VARCHAR(32) DEFAULT NULL,
    `target_id` INT DEFAULT NULL,
    `details` JSON DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_officer` (`officer_id`),
    KEY `idx_action` (`action`),
    KEY `idx_category` (`category`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Settings (key-value store for admin config)
CREATE TABLE IF NOT EXISTS `mdt_settings` (
    `key` VARCHAR(64) PRIMARY KEY,
    `value` TEXT NOT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- License Type Catalog (admin-configured types available for citizen assignment)
CREATE TABLE IF NOT EXISTS `mdt_license_types` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `type_id` VARCHAR(64) NOT NULL,
    `name` VARCHAR(128) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_type_id` (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default settings
INSERT IGNORE INTO `mdt_settings` (`key`, `value`) VALUES
    ('motd', ''),
    ('case_prefix', 'CASE'),
    ('report_prefix', 'RPT'),
    ('evidence_prefix', 'EV'),
    ('weapon_prefix', 'WPN'),
    ('retention_misdemeanor_days', '60'),
    ('retention_felony_days', '0'),
    ('cross_dept_reports', 'false');

ALTER TABLE `mdt_citizens`
    ADD COLUMN IF NOT EXISTS `job_title` VARCHAR(96) DEFAULT NULL AFTER `phone`,
    ADD COLUMN IF NOT EXISTS `property_count` INT DEFAULT 0 AFTER `job_title`;
