-- FrostByte Seed Data (as events)
-- All seed data is inserted as events; the trigger populates projection tables.

-- Label preset
INSERT INTO frostbyte_data.event (type, payload) VALUES
('label_preset_created', '{
    "name": "29mm Custom",
    "label_type": "29",
    "width": 306,
    "height": 739,
    "qr_size": 320,
    "padding": 20,
    "title_font_size": 50,
    "date_font_size": 26,
    "small_font_size": 22,
    "font_family": "Atkinson Hyperlegible, sans-serif",
    "show_title": true,
    "show_ingredients": true,
    "show_expiry_date": true,
    "show_best_before": false,
    "show_qr": true,
    "show_branding": true,
    "vertical_spacing": 10,
    "show_separator": true,
    "separator_thickness": 1,
    "separator_color": "#cccccc",
    "corner_radius": 0,
    "title_min_font_size": 16,
    "ingredients_max_chars": 74,
    "rotate": true
}');

-- Ingredients
INSERT INTO frostbyte_data.event (type, payload) VALUES
('ingredient_created', '{"name": "arroz", "expire_days": 120, "best_before_days": 90}'),
('ingredient_created', '{"name": "pollo", "expire_days": 365, "best_before_days": 270}'),
('ingredient_created', '{"name": "verduras", "expire_days": 240, "best_before_days": 180}'),
('ingredient_created', '{"name": "carne", "expire_days": 365, "best_before_days": 270}'),
('ingredient_created', '{"name": "pescado", "expire_days": 180, "best_before_days": 120}'),
('ingredient_created', '{"name": "legumbres", "expire_days": 365, "best_before_days": 300}'),
('ingredient_created', '{"name": "pasta", "expire_days": 180, "best_before_days": 120}'),
('ingredient_created', '{"name": "pan", "expire_days": 90, "best_before_days": 60}'),
('ingredient_created', '{"name": "caldo", "expire_days": 120, "best_before_days": 90}'),
('ingredient_created', '{"name": "marisco", "expire_days": 180, "best_before_days": 120}'),
('ingredient_created', '{"name": "ternera", "expire_days": 365, "best_before_days": 270}'),
('ingredient_created', '{"name": "cerdo", "expire_days": 365, "best_before_days": 270}'),
('ingredient_created', '{"name": "guiso", "expire_days": 365, "best_before_days": 300}'),
('ingredient_created', '{"name": "postre", "expire_days": 90, "best_before_days": 60}'),
('ingredient_created', '{"name": "salsa", "expire_days": 365, "best_before_days": 300}');

-- Container types
INSERT INTO frostbyte_data.event (type, payload) VALUES
('container_type_created', '{"name": "Bolsa 1L", "servings_per_unit": 2}'),
('container_type_created', '{"name": "Tupper pequeño", "servings_per_unit": 1}'),
('container_type_created', '{"name": "Tupper mediano", "servings_per_unit": 2}'),
('container_type_created', '{"name": "Tupper grande", "servings_per_unit": 4}'),
('container_type_created', '{"name": "Bolsa de 3 raciones", "servings_per_unit": 3.00}'),
('container_type_created', '{"name": "Bolsa de 1 ración", "servings_per_unit": 1.00}'),
('container_type_created', '{"name": "Bolsa de 2 raciones", "servings_per_unit": 2.00}'),
('container_type_created', '{"name": "Cubo de 250ml", "servings_per_unit": 0.75}'),
('container_type_created', '{"name": "Cubo de 125ml", "servings_per_unit": 0.375}'),
('container_type_created', '{"name": "Tupper de aluminio grande (1100ml)", "servings_per_unit": 3.25}'),
('container_type_created', '{"name": "Tupper de aluminio mediano (980ml)", "servings_per_unit": 3.00}'),
('container_type_created', '{"name": "Tupper de alumino pequeño (300ml)", "servings_per_unit": 0.90}'),
('container_type_created', '{"name": "Tupper de cristal rectangular grande (1800ml)", "servings_per_unit": 5.50}'),
('container_type_created', '{"name": "Tupper de cristal rectangular mediano (1000ml)", "servings_per_unit": 3.00}'),
('container_type_created', '{"name": "Tupper de cristal redondo (400ml)", "servings_per_unit": 1.25}'),
('container_type_created', '{"name": "Tupper de cristal cuadrado grande (1200ml)", "servings_per_unit": 3.50}'),
('container_type_created', '{"name": "Tupper de cristal cuadrado mediano (600ml)", "servings_per_unit": 1.75}'),
('container_type_created', '{"name": "Tupper de cristal cuadrado pequeño (180ml)", "servings_per_unit": 0.50}');
