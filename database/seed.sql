-- FrostByte Seed Data

-- Default label presets for all brother_ql supported label sizes
-- Endless labels use silver ratio (1 + sqrt(2)) for height
-- Feature tiers: Minimal (<200px), Small (200-350px), Medium (350-600px), Large (≥600px)
-- rotate: TRUE if height > width (portrait stored, display landscape), FALSE otherwise
INSERT INTO label_preset (
    name, label_type, width, height, qr_size, padding, title_font_size, date_font_size, small_font_size,
    show_title, show_ingredients, show_expiry_date, show_best_before, show_qr, show_branding,
    vertical_spacing, show_separator, separator_thickness, separator_color, corner_radius,
    title_min_font_size, ingredients_max_chars, rotate
) VALUES
    -- ENDLESS LABELS (height = width × silver ratio) - all portrait, rotate=TRUE
    -- Minimal tier
    ('12mm endless', '12', 106, ROUND(106 * (1 + SQRT(2)))::INTEGER, 64, 5, 12, 10, 8,
     TRUE, FALSE, FALSE, FALSE, TRUE, FALSE,
     3, FALSE, 1, '#cccccc', 0,
     8, 20, TRUE),
    -- Small tier
    ('29mm endless', '29', 306, ROUND(306 * (1 + SQRT(2)))::INTEGER, 180, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', 0,
     16, 30, TRUE),
    -- Medium tier
    ('38mm endless', '38', 413, ROUND(413 * (1 + SQRT(2)))::INTEGER, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', 0,
     20, 50, TRUE),
    ('50mm endless', '50', 554, ROUND(554 * (1 + SQRT(2)))::INTEGER, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', 0,
     20, 50, TRUE),
    ('54mm endless', '54', 590, ROUND(590 * (1 + SQRT(2)))::INTEGER, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', 0,
     20, 50, TRUE),
    -- Large tier
    ('62mm endless', '62', 696, ROUND(696 * (1 + SQRT(2)))::INTEGER, 200, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', 0,
     24, 60, TRUE),
    ('62mm endless (black/red/white)', '62red', 696, ROUND(696 * (1 + SQRT(2)))::INTEGER, 200, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', 0,
     24, 60, TRUE),
    ('102mm endless', '102', 1164, ROUND(1164 * (1 + SQRT(2)))::INTEGER, 280, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', 0,
     24, 80, TRUE),

    -- DIE-CUT RECTANGULAR LABELS (fixed dimensions)
    -- corner_radius = 5% of min(width, height) for rounded corners
    -- Minimal tier - portrait, rotate=TRUE
    ('17mm x 54mm die-cut', '17x54', 165, 566, 100, 5, 12, 10, 8,
     TRUE, FALSE, FALSE, FALSE, TRUE, FALSE,
     3, FALSE, 1, '#cccccc', ROUND(LEAST(165, 566) * 0.05)::INTEGER,
     8, 20, TRUE),
    ('17mm x 87mm die-cut', '17x87', 165, 956, 100, 5, 12, 10, 8,
     TRUE, FALSE, FALSE, FALSE, TRUE, FALSE,
     3, FALSE, 1, '#cccccc', ROUND(LEAST(165, 956) * 0.05)::INTEGER,
     8, 20, TRUE),
    -- Small tier
    ('23mm x 23mm die-cut', '23x23', 202, 202, 120, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', ROUND(LEAST(202, 202) * 0.05)::INTEGER,
     16, 30, FALSE),  -- square, no rotation needed
    ('29mm x 42mm die-cut', '29x42', 306, 425, 180, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', ROUND(LEAST(306, 425) * 0.05)::INTEGER,
     16, 30, TRUE),
    ('29mm x 90mm die-cut', '29x90', 306, 991, 180, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', ROUND(LEAST(306, 991) * 0.05)::INTEGER,
     16, 30, TRUE),
    -- Medium tier
    ('39mm x 48mm die-cut', '39x48', 425, 495, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', ROUND(LEAST(425, 495) * 0.05)::INTEGER,
     20, 50, TRUE),
    ('38mm x 90mm die-cut', '39x90', 413, 991, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', ROUND(LEAST(413, 991) * 0.05)::INTEGER,
     20, 50, TRUE),
    ('52mm x 29mm die-cut', '52x29', 578, 271, 180, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, FALSE,
     8, TRUE, 1, '#cccccc', ROUND(LEAST(578, 271) * 0.05)::INTEGER,
     20, 50, FALSE),  -- landscape, no rotation needed
    -- Large tier
    ('62mm x 29mm die-cut', '62x29', 696, 271, 180, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', ROUND(LEAST(696, 271) * 0.05)::INTEGER,
     24, 60, FALSE),  -- landscape, no rotation needed
    ('62mm x 100mm die-cut', '62x100', 696, 1109, 200, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', ROUND(LEAST(696, 1109) * 0.05)::INTEGER,
     24, 60, TRUE),
    ('102mm x 51mm die-cut', '102x51', 1164, 526, 250, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', ROUND(LEAST(1164, 526) * 0.05)::INTEGER,
     24, 80, FALSE),  -- landscape, no rotation needed
    ('102mm x 153mm die-cut', '102x152', 1164, 1660, 280, 20, 48, 32, 18,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     10, TRUE, 1, '#cccccc', ROUND(LEAST(1164, 1660) * 0.05)::INTEGER,
     24, 80, TRUE),

    -- ROUND DIE-CUT LABELS (square dimensions, no rotation needed)
    -- Minimal tier
    ('12mm round die-cut', 'd12', 94, 94, 60, 5, 10, 8, 6,
     TRUE, FALSE, FALSE, FALSE, TRUE, FALSE,
     2, FALSE, 1, '#cccccc', 47,
     6, 15, FALSE),
    -- Small tier
    ('24mm round die-cut', 'd24', 236, 236, 140, 10, 24, 16, 12,
     TRUE, FALSE, TRUE, FALSE, TRUE, FALSE,
     6, TRUE, 1, '#cccccc', 118,
     16, 30, FALSE),
    -- Large tier
    ('58mm round die-cut', 'd58', 618, 618, 200, 15, 36, 24, 16,
     TRUE, TRUE, TRUE, FALSE, TRUE, TRUE,
     8, TRUE, 1, '#cccccc', 309,
     20, 50, FALSE);

-- Common ingredients with expiry info (migrated from old categories)
INSERT INTO ingredient (name, expire_days, best_before_days) VALUES
    ('arroz', 120, 90),
    ('pollo', 365, 270),
    ('verduras', 240, 180),
    ('carne', 365, 270),
    ('pescado', 180, 120),
    ('legumbres', 365, 300),
    ('pasta', 180, 120),
    ('pan', 90, 60),
    ('caldo', 120, 90);

-- Container types with servings per unit
INSERT INTO container_type (name, servings_per_unit) VALUES
    ('Bolsa 1L', 2),
    ('Tupper pequeño', 1),
    ('Tupper mediano', 2),
    ('Tupper grande', 4);

-- Additional Ingredients with their freezer shelf life in days
INSERT INTO ingredient (name, expire_days, best_before_days) VALUES
    ('marisco', 180, 120),
    ('ternera', 365, 270),
    ('cerdo', 365, 270),
    ('guiso', 365, 300),
    ('postre', 90, 60),
    ('salsa', 365, 300)
ON CONFLICT (name) DO NOTHING;

-- Container types with servings per unit
INSERT INTO container_type (name, servings_per_unit) VALUES
    ('Bolsa de 3 raciones', 3.00),
    ('Bolsa de 1 ración', 1.00),
    ('Bolsa de 2 raciones', 2.00),
    ('Cubo de 250ml', 0.75),
    ('Cubo de 125ml', 0.375),
    ('Tupper de aluminio grande (1100ml)', 3.25),
    ('Tupper de aluminio mediano (980ml)', 3.00),
    ('Tupper de alumino pequeño (300ml)', 0.90),
    ('Tupper de cristal rectangular grande (1800ml)', 5.50),
    ('Tupper de cristal rectangular mediano (1000ml)', 3.00),
    ('Tupper de cristal redondo (400ml)', 1.25),
    ('Tupper de cristal cuadrado grande (1200ml)', 3.50),
    ('Tupper de cristal cuadrado mediano (600ml)', 1.75),
    ('Tupper de cristal cuadrado pequeño (180ml)', 0.50)
ON CONFLICT (name) DO NOTHING;
