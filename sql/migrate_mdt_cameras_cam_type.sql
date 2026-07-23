-- Run once if `mdt_cameras.cam_type` is still ENUM('placed','dynamic') from older schema.
-- Adds ps-mdt-style categories used by data/cctv_presets.json.

ALTER TABLE `mdt_cameras`
    MODIFY `cam_type` ENUM(
        'placed',
        'dynamic',
        'store',
        'bank',
        'jewelry',
        'government',
        'medical',
        'other'
    ) DEFAULT 'placed';
