# LabelMaker App — CLAUDE.md

LabelMaker is a **general-purpose label canvas editor** using **CQRS + Event Sourcing**. All writes go through an append-only event table; projection tables are rebuilt from events.

Supports **multiple label templates** — a list page to create/select/delete templates, and an editor page per template. Every modification is persisted as an event; state survives page refresh.

Also supports **labels** — instances of a template with concrete key-value pairs filled in. Labels can be previewed, edited, and printed via the Brother QL printer service.

Also supports **labelsets** — named collections of rows (each row is a label's worth of variable values) based on a template. Enables batch label creation and printing from a spreadsheet-like interface.

## Three-Schema Architecture

```
labelmaker_data   — Persistent storage: event store (append-only)
labelmaker_logic  — Business logic: projection tables, event handlers, replay, helpers
labelmaker_api    — External interface: read views + RPC write functions (exposed via PostgREST)
```

- `labelmaker_data` schema is created once via migration and never dropped
- `labelmaker_logic` and `labelmaker_api` schemas are idempotent (DROP + CREATE) and can be redeployed without data loss
- All writes INSERT into `labelmaker_data.event`; a trigger calls `labelmaker_logic.apply_event()` to update projections
- `labelmaker_logic.replay_all_events()` truncates all projections and rebuilds from the event store

## Key Database Objects

**Data schema (persistent — `labelmaker_data`):**
- **`labelmaker_data.event`**: Append-only event store (id BIGSERIAL, type TEXT, payload JSONB, created_at TIMESTAMPTZ, version INTEGER DEFAULT 1)

**Logic schema (idempotent — `labelmaker_logic`):**
- **`labelmaker_logic.template`**: Projection table (id UUID, name, label_type_id, label_width, label_height, corner_radius, rotate, padding, content JSONB, next_id, sample_values JSONB, created_at, deleted)
- **`labelmaker_logic.label`**: Projection table (id UUID, template_id UUID FK, name TEXT, values JSONB, created_at, deleted)
- **`labelmaker_logic.labelset`**: Projection table (id UUID, template_id UUID FK, name TEXT, rows JSONB, created_at, deleted)
- **8 template handler functions**: `apply_template_created`, `apply_template_deleted`, `apply_template_name_set`, `apply_template_label_type_set`, `apply_template_height_set`, `apply_template_padding_set`, `apply_template_content_set`, `apply_template_sample_value_set`
- **4 label handler functions**: `apply_label_created`, `apply_label_deleted`, `apply_label_values_set`, `apply_label_name_set`
- **4 labelset handler functions**: `apply_labelset_created`, `apply_labelset_deleted`, `apply_labelset_name_set`, `apply_labelset_rows_set`
- **`labelmaker_logic.apply_event()`**: CASE dispatcher to 16 handler functions
- **`labelmaker_logic.replay_all_events()`**: Truncates labelset, label, and template tables and rebuilds from events

**API schema (idempotent — `labelmaker_api`):**
- **`labelmaker_api.template_list`**: Summary view for list page (id, name, label_type_id, created_at; excludes deleted)
- **`labelmaker_api.template_detail`**: Full state view for editor (all fields; excludes deleted)
- **`labelmaker_api.label_list`**: Label summary view (id, template_id, template_name, label_type_id, name, values, created_at; joins template, excludes deleted)
- **`labelmaker_api.label_detail`**: Full label+template data for rendering (includes template dimensions, content, padding, name, etc.)
- **`labelmaker_api.create_template(p_name)`**: RPC function that generates UUID, inserts `template_created` event, returns `template_id`
- **`labelmaker_api.create_label(p_template_id, p_name)`**: RPC function that generates UUID, copies template's sample_values as initial label values, inserts `label_created` event with name, returns `label_id`
- **`labelmaker_api.labelset_list`**: LabelSet summary view (id, template_id, template_name, label_type_id, name, row_count, created_at; joins template, excludes deleted)
- **`labelmaker_api.labelset_detail`**: Full labelset+template data for rendering (includes template dimensions, content, padding, rows)
- **`labelmaker_api.create_labelset(p_template_id, p_name)`**: RPC function that generates UUID, copies template's sample_values as first row, inserts `labelset_created` event, returns `labelset_id`
- **`labelmaker_api.delete_template(p_template_id)`**: RPC function, inserts `template_deleted` event
- **`labelmaker_api.set_template_name(p_template_id, p_name)`**: RPC function, inserts `template_name_set` event
- **`labelmaker_api.set_template_label_type(p_template_id, p_label_type_id, p_label_width, p_label_height, p_corner_radius, p_rotate)`**: RPC function, inserts `template_label_type_set` event
- **`labelmaker_api.set_template_height(p_template_id, p_label_height)`**: RPC function, inserts `template_height_set` event
- **`labelmaker_api.set_template_padding(p_template_id, p_padding)`**: RPC function, inserts `template_padding_set` event
- **`labelmaker_api.set_template_content(p_template_id, p_content, p_next_id)`**: RPC function, inserts `template_content_set` event
- **`labelmaker_api.set_template_sample_value(p_template_id, p_variable_name, p_value)`**: RPC function, inserts `template_sample_value_set` event
- **`labelmaker_api.delete_label(p_label_id)`**: RPC function, inserts `label_deleted` event
- **`labelmaker_api.set_label_name(p_label_id, p_name)`**: RPC function, inserts `label_name_set` event
- **`labelmaker_api.set_label_values(p_label_id, p_values)`**: RPC function, inserts `label_values_set` event
- **`labelmaker_api.delete_labelset(p_labelset_id)`**: RPC function, inserts `labelset_deleted` event
- **`labelmaker_api.set_labelset_name(p_labelset_id, p_name)`**: RPC function, inserts `labelset_name_set` event
- **`labelmaker_api.set_labelset_rows(p_labelset_id, p_rows)`**: RPC function, inserts `labelset_rows_set` event

## Event Types (16)

| Event | Payload |
|---|---|
| `template_created` | `{ template_id, name }` |
| `template_deleted` | `{ template_id }` |
| `template_name_set` | `{ template_id, name }` |
| `template_label_type_set` | `{ template_id, label_type_id, label_width, label_height, corner_radius, rotate }` |
| `template_height_set` | `{ template_id, label_height }` |
| `template_padding_set` | `{ template_id, padding }` |
| `template_content_set` | `{ template_id, content: [...full tree...], next_id }` |
| `template_sample_value_set` | `{ template_id, variable_name, value }` |
| `label_created` | `{ label_id, template_id, name, values: {...} }` |
| `label_deleted` | `{ label_id }` |
| `label_name_set` | `{ label_id, name }` |
| `label_values_set` | `{ label_id, values: {...} }` |
| `labelset_created` | `{ labelset_id, template_id, name, rows: [{...}] }` |
| `labelset_deleted` | `{ labelset_id }` |
| `labelset_name_set` | `{ labelset_id, name }` |
| `labelset_rows_set` | `{ labelset_id, rows: [{...}, ...] }` |

Content events store the **full object tree** (not deltas). Labelset row events store the **full rows array** (not deltas). Server generates template, label, and labelset UUIDs via `gen_random_uuid()` in the respective RPC functions.

## Database File Structure

```
apps/labelmaker/database/
├── migrations/001-initial.sql    # Data schema (event table, indexes, extensions)
├── logic.sql                     # Logic schema (event handlers, replay) — idempotent
├── api.sql                       # API schema (views, RPC functions) — idempotent
├── seed.sql                      # Seed data as events (empty)
├── migrate.sh                    # Auto-migration (runs in labelmaker_db_migrator container)
└── deploy.sh                     # Manual redeploy from host (uses docker exec)
```

### Deploying Schema Changes

Schema changes are **auto-applied on every `docker compose up`** by the `labelmaker_db_migrator` one-shot container. For manual redeploy:

```bash
./apps/labelmaker/database/deploy.sh
```

**Note:** After manual `deploy.sh`, restart PostgREST to refresh its schema cache: `docker restart kitchen_postgrest`

## Elm Client Structure

SPA using `Browser.application` with multi-page routing and event-sourced persistence:

```
apps/labelmaker/client/src/
├── Main.elm              # Entry point, routing, port subscriptions, OutMsg handling
├── Route.elm             # Route type: TemplateList | TemplateEditor | LabelList | LabelEditor | LabelSetList | LabelSetEditor | NotFound
├── Types.elm             # Shared types (RemoteData, Notification, Committable)
├── Ports.elm             # Port module: text measurement + SVG-to-PNG conversion
├── Api.elm               # HTTP functions (templates, labels, labelsets, printing)
├── Api/
│   ├── Decoders.elm      # JSON decoders (TemplateSummary, TemplateDetail, LabelSummary, LabelDetail, LabelSetSummary, LabelSetDetail, etc.)
│   └── Encoders.elm      # JSON encoders (encodeLabelObject, encodePrintRequest, etc.)
├── Components.elm        # Header, notification, loading
├── Data/
│   ├── LabelObject.elm   # Label object types, tree operations, constructors, allVariableNames
│   └── LabelTypes.elm    # Brother QL label specs (25 types, copied from FrostByte)
├── main.js               # Elm init + text measurement + SVG-to-PNG + font loading
└── Page/
    ├── Templates.elm     # Facade: template list page (create, delete, navigate)
    ├── Templates/
    │   ├── Types.elm     # Model (RemoteData list), Msg, OutMsg (NavigateTo)
    │   └── View.elm      # Card grid with create/delete buttons
    ├── Home.elm          # Facade: template editor page (init takes templateId, deferred persistence, subscriptions for drag)
    ├── Home/
    │   ├── Types.elm     # Editor model (templateId, templateName, label settings, content tree, dragState, treeDragState), msgs, OutMsg
    │   └── View.elm      # Two-column layout: SVG preview (drag-to-move/resize) + editor controls (DnD tree), back link, name input
    ├── Labels.elm        # Facade: label list page (create from template, delete, navigate)
    ├── Labels/
    │   ├── Types.elm     # Model (labels + templates RemoteData, selectedTemplateId, newName), Msg, OutMsg
    │   └── View.elm      # Template picker + name input + card grid of labels
    ├── Label.elm         # Facade: label editor page (view/edit values, print)
    ├── Label/
    │   ├── Types.elm     # Model (label data, labelName, values, printing state), Msg, OutMsg (print flow)
    │   └── View.elm      # Two-column: SVG preview (read-only) + editable name + value form + print button
    ├── LabelSets.elm     # Facade: labelset list page (create from template, delete, navigate)
    ├── LabelSets/
    │   ├── Types.elm     # Model (labelsets + templates RemoteData, selectedTemplateId, newName), Msg, OutMsg
    │   └── View.elm      # Template picker + name input + card grid of labelsets
    ├── LabelSet.elm      # Facade: labelset editor page (spreadsheet, preview, batch print)
    ├── LabelSet/
    │   ├── Types.elm     # Model (labelset data, rows, selectedRowIndex, print queue), Msg, OutMsg
    │   └── View.elm      # Two-column: SVG preview + spreadsheet table + print controls
    ├── NotFound.elm      # Facade
    └── NotFound/
        └── View.elm      # 404 page
```

**Architecture pattern:** Same as FrostByte — each page exposes Model, Msg, OutMsg, init, update, view. The template editor (Home) also exposes `subscriptions` for mouse drag events. Pages communicate up via OutMsg.

**Routes:**
- `/` — Template list (create, select, delete templates)
- `/template/<uuid>` — Template editor (label canvas with persistence)
- `/labels` — Label list (create from template, view, delete labels)
- `/label/<uuid>` — Label editor (edit values, preview, print)
- `/sets` — LabelSet list (create from template, view, delete labelsets)
- `/set/<uuid>` — LabelSet editor (spreadsheet, preview, single/batch print)

**Styling:** Tailwind CSS with custom "label" color palette (warm brown tones)

**Served on:** Port `:8080` via Caddy

### Persistence Pattern (Deferred with Committable)

All editor pages use **deferred persistence** to avoid emitting an event on every keystroke. The shared `Committable` type in `Types.elm` tracks dirty state:

```elm
type Committable a = Dirty a | Clean a

getValue : Committable a -> a
```

**How it works:**
- Text/number `onInput` handlers set the model field to `Dirty newValue` (updates preview instantly, no HTTP POST)
- `onBlur` handlers (Commit* msgs) pattern-match: only emit the event if the value is `Dirty`, then set it to `Clean`
- Discrete actions (dropdown selects, button clicks like Add/Remove) set `Clean` and persist immediately via `withCmd`/`withContentCmd`

**Template editor (Home.elm):**
- Wrapped fields: `templateName`, `labelHeight`, `padding`, `content`, `sampleValues`
- Deferred: `TemplateNameChanged`, `HeightChanged`, `PaddingChanged`, `UpdateObjectProperty` (except `SetShapeType`, `SetHAlign`, `SetVAlign`), `UpdateSampleValue`
- Immediate: `LabelTypeChanged`, `RotateChanged`, `AddObject`, `RemoveObject`, `SetShapeType`, `SetHAlign`, `SetVAlign`, `MoveObjectToParent`, `MoveObjectToSlot`, `TreeDrop`, `SvgMouseUp` (commits on release)

**Label editor (Label.elm):**
- Wrapped fields: `labelName : Committable String`, `values : Dict String (Committable String)`
- Deferred: `UpdateName`/`CommitName`, `UpdateValue`/`CommitValues` on blur

**LabelSet editor (LabelSet.elm):**
- Wrapped fields: `labelsetName : Committable String`, `rows : Committable (List (Dict String String))`
- Deferred: `UpdateName`/`CommitName`, `UpdateCell`/`CommitRows`
- Immediate: `AddRow`, `DeleteRow`

Content changes use `withContentCmd` which sends the full object tree via `Api.setTemplateContent`. Ephemeral state (`SelectObject`, `GotTextMeasureResult`, `EventEmitted`) is NOT persisted.

### Template Editor Init Flow

1. `Home.init templateId` creates model with defaults, fires `fetchTemplateDetail`
2. `GotTemplateDetail (Ok (Just detail))` applies fetched state via `applyTemplateDetail`, triggers text measurements
3. `GotTemplateDetail (Ok Nothing)` — template not found (deleted or invalid UUID)

## Composable Label Object System

Labels are built from a tree of composable objects defined in `Data/LabelObject.elm`:

```elm
type LabelObject
    = Container { id, name, x, y, width, height, content : List LabelObject }
    | VSplit { id, name, split, top : Maybe LabelObject, bottom : Maybe LabelObject }
    | HSplit { id, name, split, left : Maybe LabelObject, right : Maybe LabelObject }
    | TextObj { id, content, properties : TextProperties }
    | VariableObj { id, name, properties : TextProperties }
    | ImageObj { id, url }
    | ShapeObj { id, properties : ShapeProperties }
```

**Design principles:**
- Objects fill their parent container (no explicit dimensions on non-Container objects)
- Positioning is only done via Container (wrap an object in a Container with x, y, width, height)
- Multiple objects at the same level overlap (z-ordered by list position)
- Shapes fill the container: Rectangle = full area, Circle = inscribed, Line = diagonal
- Each object has an `id : ObjectId` for selection, measurement tracking, and persistence

**Supporting types:**
- `Color { r, g, b, a }` — RGBA color
- `TextProperties { fontSize, fontFamily, color, hAlign, vAlign }` — `fontSize` is the max for auto-fit (min derived as `max 6 (fontSize / 3)`); `hAlign` (`AlignLeft | AlignCenter | AlignRight`) and `vAlign` (`AlignTop | AlignMiddle | AlignBottom`) control text positioning within the container (default: center/middle)
- `ShapeProperties { shapeType, color }` — `ShapeType` is `Rectangle | Circle | Line`
- `SlotPosition` — `TopSlot | BottomSlot | LeftSlot | RightSlot` — identifies a slot within VSplit/HSplit containers

**Tree operations:** `findObject`, `updateObjectInTree`, `removeObjectFromTree`, `addObjectTo`, `addObjectToSlot`, `allTextObjectIds`, `removeAndReturn`, `insertAtTarget`, `isDescendantOf`, `allContainerIds`, `allSlotTargets`

**Constructors:** `newText`, `newVariable`, `newContainer`, `newVSplit`, `newHSplit`, `newShape`, `newImage` — all take a `nextId : Int` parameter. `newContainer` additionally takes `x, y, width, height`. `newVSplit`/`newHSplit` only take `nextId` (splits fill their parent, no positioning).

**JSON serialization:** Objects are serialized with a `"type"` discriminator field (`"container"`, `"text"`, `"variable"`, `"image"`, `"shape"`). Container's `content` uses `Decode.lazy` for recursive decoding. Container `name` is decoded with `Maybe` fallback to `""` for backward compatibility with existing data. `TextProperties.hAlign`/`vAlign` are encoded as strings (`"left"/"center"/"right"`, `"top"/"middle"/"bottom"`) and decoded with `optionalField` defaulting to `"center"`/`"middle"` for backward compatibility with existing templates.

## Label Canvas Editor (Template Editor Page)

The editor page (`/template/<uuid>`) is a live label canvas editor with composable objects and auto-sizing text. All changes are persisted as events.

### Model

- `templateId` — UUID of the template being edited
- `templateName : Committable String` — Editable template name (deferred persistence via `CommitTemplateName`)
- `labelTypeId` — Selected Brother QL label type (default: `"62"` = 62mm endless)
- `labelWidth`, `labelHeight : Committable Int` — Label dimensions in pixels (from `Data.LabelTypes`)
- `cornerRadius` — For round labels (width/2), 0 otherwise
- `rotate` — `True` for die-cut rectangular labels (display swapped for landscape)
- `content : Committable (List LabelObject)` — Object tree (default: one `VariableObj "nombre"`)
- `selectedObjectId : Maybe ObjectId` — Currently selected object for property editing
- `sampleValues : Dict String (Committable String)` — Variable name to sample value mapping for preview
- `computedTexts : Dict ObjectId ComputedText` — Per-object auto-fit results (fittedFontSize + lines)
- `nextId : Int` — Auto-incrementing ID counter for new objects
- `padding : Committable Int` — Inner padding in pixels (default: 20)
- `dragState : Maybe DragState` — SVG canvas drag state (move/resize containers via mouse)
- `treeDragState : Maybe TreeDragState` — Object tree HTML5 drag-and-drop state (reorder/reparent)

### Text Fitting Flow

1. Any layout-affecting change (label type, object properties, sample values, padding) emits `RequestTextMeasures` via OutMsg with a batch of requests
2. `Main.elm` sends all requests through `Ports.requestTextMeasure` via `Cmd.batch`
3. `collectMeasurements` in Types.elm walks the object tree, threading container bounds, emitting one request per text/variable object
4. JavaScript (`main.js`) splits text by `\n` into paragraphs, measures the longest segment to shrink font, then word-wraps each paragraph independently. Empty paragraphs (`\n\n`) produce blank lines. If `maxHeight > 0`, further shrinks to fit wrapped lines within the vertical constraint
5. Results sent back via `Ports.receiveTextMeasureResult` → `Main.elm` → `GotTextMeasureResult` msg
6. Each result is stored in `computedTexts` dict keyed by object ID
7. SVG preview re-renders with computed font sizes and wrapped lines

### View Layout

**Top — Template header:**
- Back link to template list (`/`)
- Editable template name input

**Left column — SVG preview:**
- White rectangle at label dimensions (swapped if `rotate=True`)
- Recursive rendering of object tree (`renderObject`)
- Click objects on canvas to select them (dashed blue border overlay)
- Click background to deselect
- **Drag-to-move**: selected containers can be dragged on canvas (`cursor: move` on selection overlay)
- **Drag-to-resize**: 4 corner handles (8x8 blue squares) on selected containers for resize via drag
- Mouse deltas are divided by `scaleFactor` for screen-to-SVG coordinate conversion (no DOM queries)
- Content is marked `Dirty` during drag, committed on mouse up; text remeasurement deferred to release for resize
- Scaled to fit max 500px width
- Dimension info below

**Right column — Editor controls (scrollable):**
1. **Label settings** (top): label type dropdown, dimensions, padding, rotate checkbox
2. **Object tree** (middle): hierarchical list with type icons, click-to-select, delete buttons, indented container children. VSplit/HSplit show named slots (Arriba/Abajo, Izq./Der.) with "(vacío)" for empty slots. Supports **HTML5 drag-and-drop** for reordering (drop indicators: blue line for before/after, highlight for drop-into container or empty VSplit/HSplit slot). Prevents dropping into own descendants.
3. **Add toolbar**: buttons to add Text, Variable, Container, Rectangle, Circle, Line, Image (appends to root or inside selected container)
4. **Property editor** (bottom): context-sensitive controls for selected object:
   - Container: name, x, y, width, height
   - VSplit/HSplit: name, split %
   - TextObj: content (multiline textarea), font family, font size, horizontal alignment, vertical alignment, RGB color
   - VariableObj: variable name, sample value (multiline textarea), font family, font size, horizontal alignment, vertical alignment, RGB color
   - ShapeObj: shape type dropdown, RGB color
   - ImageObj: URL input
   - All types: "Mover a" dropdown to reparent into a container, empty VSplit/HSplit slot, or root level

### Messages

- `SelectObject (Maybe ObjectId)` — Select/deselect an object (ephemeral)
- `AddObject LabelObject` — Add object to root or inside selected container → immediate `template_content_set`
- `RemoveObject ObjectId` — Remove object from tree → immediate `template_content_set`
- `UpdateObjectProperty ObjectId PropertyChange` — Apply a property change → deferred (except `SetShapeType`, `SetHAlign`, `SetVAlign` which are immediate). Includes `SetContainerName`.
- `UpdateSampleValue String String` — Set sample value for a variable (deferred)
- `LabelTypeChanged` → immediate `template_label_type_set`
- `HeightChanged` → deferred, updates model only
- `PaddingChanged` → deferred, updates model only
- `RotateChanged` → immediate `template_label_type_set` (persists via `setTemplateLabelType` with current label type params)
- `TemplateNameChanged` → deferred, updates model only
- `CommitTemplateName` — On blur: persists `template_name_set` if dirty
- `CommitHeight` — On blur: persists `template_height_set` if dirty
- `CommitPadding` — On blur: persists `template_padding_set` if dirty
- `CommitContent` — On blur: persists `template_content_set` if dirty
- `CommitSampleValue String` — On blur: persists `template_sample_value_set` if dirty
- `SvgMouseDown ObjectId DragMode Float Float` — Start SVG drag (move or resize handle, Container only)
- `SplitDragStart ObjectId Float Float Float Float` — Start split line drag (objectId, mouseX, mouseY, containerW, containerH); View passes parent dimensions since splits have no stored size
- `SvgMouseMove Float Float` — Continue SVG drag (via `Browser.Events.onMouseMove` subscription)
- `SvgMouseUp` — End SVG drag, commit content, remeasure text if resized
- `TreeDragStart ObjectId` — Start HTML5 tree drag
- `TreeDragOver DropTarget` — Update tree drop target (DropBefore/DropAfter/DropInto/DropIntoSlot based on offset ratio or slot hover)
- `TreeDrop` — Execute tree reorder/reparent (including into empty VSplit/HSplit slots)
- `TreeDragEnd` — Clear tree drag state
- `MoveObjectToParent ObjectId (Maybe ObjectId)` — Reparent object via "Mover a" dropdown (Nothing = root)
- `MoveObjectToSlot ObjectId ObjectId SlotPosition` — Move object into an empty VSplit/HSplit slot via "Mover a" dropdown
- `GotTextMeasureResult` — Receive measurement result from JS (ephemeral)
- `GotTemplateDetail` — Receive template state from API on init
- `EventEmitted` — No-op acknowledgement of event POST

### Label Type Selection Logic

When a label type is selected:
- **Endless labels**: height = silver ratio (width * 2.414), cornerRadius = 0, rotate = false
- **Die-cut rectangular**: height from spec, cornerRadius = 0, rotate = true (landscape display)
- **Round die-cut**: height = width, cornerRadius = width/2, rotate = false

## Label Editor Page

The label editor page (`/label/<uuid>`) displays a label instance with its template's design and allows editing variable values and printing.

### Init Flow

1. `Label.init labelId` creates model with defaults, fires `fetchLabelDetail`
2. `GotLabelDetail (Ok (Just detail))` applies template+label data, extracts `variableNames` from content tree via `allVariableNames`, triggers text measurements
3. Variable values are pre-filled from the template's sample_values (copied at label creation time)

### Print Flow

1. User clicks "Imprimir" → `RequestPrint` msg → sets `printing = True`
2. `RequestSvgToPng` OutMsg sent to Main.elm → port command to JS
3. JS serializes SVG → Canvas → PNG (handles `rotate` flag for printer orientation)
4. `GotPngResult` received → strips `data:image/png;base64,` prefix → POST to `/api/printer/print`
5. `GotPrintResult Ok` → `printing = False`, success notification
6. `GotPrintResult Err` → `printing = False`, error notification

### Name Editing

Label name is editable in the header. Uses deferred persistence:
1. `onInput` → `UpdateName`: sets `labelName = Dirty name`
2. `onBlur` → `CommitName`: if `Dirty`, emits `label_name_set` event, sets to `Clean`

### Value Editing

Each variable in the template has a multiline textarea. Uses deferred persistence:
1. `onInput` → `UpdateValue`: sets `Dirty val` in `values` dict, triggers text remeasurement for updated preview
2. `onBlur` → `CommitValues`: if any value is `Dirty`, emits `label_values_set` event with all values, sets all to `Clean`

## LabelSet Editor Page

The labelset editor page (`/set/<uuid>`) displays a spreadsheet of rows where each row contains values for all template variables. Includes SVG preview of the selected row and single/batch printing.

### Init Flow

1. `LabelSet.init labelsetId` creates model with defaults, fires `fetchLabelSetDetail`
2. `GotLabelSetDetail (Ok (Just detail))` applies template+labelset data, extracts `variableNames` from content tree, selects row 0, triggers text measurements
3. Variable names are derived from the template's content tree via `allVariableNames`

### Spreadsheet

- Header: "#" + one column per variable name
- Rows: clickable row number (selects row for preview) + `<textarea>` per cell (supports multiline values; Enter inserts newline when editing, Ctrl+Enter adds new row)
- Selected row highlighted with `bg-label-50`
- Delete button per row (hidden if only 1 row)
- "Agregar fila" button below table adds a row with empty values
- Cell edits are deferred: `onInput` → `Dirty`, `onBlur` → `CommitRows` emits `labelset_rows_set` if dirty
- `AddRow`/`DeleteRow` persist immediately (set `Clean`)
- Labelset name editing is also deferred: `UpdateName` → `Dirty`, `CommitName` on blur

### CSV Import/Export Mode

Toggle between table and CSV textarea via the "CSV"/"Tabla" button next to the "Datos" heading. Uses `BrianHicks/elm-csv` for encode/decode.

- **Model fields:** `csvMode : Bool`, `csvText : String`, `csvError : Maybe String`, `fieldSeparator : Char` (default `','`)
- **Messages:** `ToggleCsvMode`, `UpdateCsvText String`, `UpdateFieldSeparator String`
- **To CSV mode:** encodes current `rows` to `csvText`, clears cell focus
- **To table mode:** commits dirty rows, switches back
- **Live decode:** `UpdateCsvText` attempts decode on every keystroke; on success updates `rows` (as `Dirty`) and triggers SVG preview re-measurement; on failure shows error without touching rows
- **Separator:** configurable single-char field separator; changing it re-encodes from current rows
- **CSV helpers in `LabelSet.elm`:** `encodeCsv`, `decodeCsv`, `buildRowDecoder` (dynamic named-field decoder built via fold over `variableNames`)

### Print Flow (Single Row)

Same as Label editor: `RequestPrint` → SVG-to-PNG → POST to printer

### Batch Print Flow

1. `RequestPrintAll` sets `printingAll=True`, `printProgress={current=1, total=N}`, selects row 0, clears computedTexts
2. Text measurements complete → all text object IDs have entries in `computedTexts` → auto-trigger `RequestSvgToPng`
3. `GotPngResult` → POST to printer
4. `GotPrintResult Ok` → advance: if more rows in `printQueue`, select next, clear computedTexts, request measurements (loop to step 2). If done, show success notification.
5. Detection: in `GotTextMeasureResult`, after inserting result, check if all text object IDs (from `allTextObjectIds`) have entries. If yes AND `printingAll`, trigger SVG-to-PNG.

## Working with Ports

Ports are defined in `Ports.elm` and handled in `main.js`:

```elm
-- Text measurement
port requestTextMeasure : TextMeasureRequest -> Cmd msg
port receiveTextMeasureResult : (TextMeasureResult -> msg) -> Sub msg

-- SVG to PNG conversion (for printing)
port requestSvgToPng : SvgToPngRequest -> Cmd msg
port receivePngResult : (PngResult -> msg) -> Sub msg
```

**TextMeasureRequest fields:** `requestId`, `text`, `fontFamily`, `maxFontSize`, `minFontSize`, `maxWidth`, `maxHeight`

**TextMeasureResult fields:** `requestId`, `fittedFontSize`, `lines` (List String)

**SvgToPngRequest fields:** `svgId`, `requestId`, `width`, `height`, `rotate`

**PngResult fields:** `requestId`, `dataUrl` (Maybe String), `error` (Maybe String)

`Main.elm` subscribes to both `receiveTextMeasureResult` and `receivePngResult`, forwarding results to the active page. Text measurements are used by both the template editor and label editor. SVG-to-PNG conversion is used by the label editor for printing.

The JS handler in `main.js` supports multiline text: it splits by `\n` into paragraphs, measures the longest segment for font shrinking, then word-wraps each paragraph independently. Empty paragraphs (`\n\n`) produce blank lines. If `maxHeight > 0`, further shrinks to fit wrapped lines within the vertical constraint. Font loading (Atkinson Hyperlegible) uses base64 embedding for accurate SVG-to-PNG rendering.

## Installing Elm Packages

**IMPORTANT:** Do not manually edit `apps/labelmaker/client/elm.json` to add dependencies. Elm requires proper dependency resolution which only `elm install` can perform correctly.

```bash
cd apps/labelmaker/client
docker run --rm -v "$(pwd)":/app -w /app node:20-alpine sh -c "npm install -g elm && echo y | elm install <package-name>"
```

To verify compilation:

```bash
docker run --rm -v "$(pwd)":/app -w /app node:20-alpine sh -c "npm install -g elm && elm make src/Main.elm --output=/dev/null"
```

## API Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/db/template_list` | GET | List all templates (summary, excludes deleted) |
| `/api/db/template_detail?id=eq.<uuid>` | GET | Full template state for editor |
| `/api/db/rpc/create_template` | POST | Create template (body: `{"p_name":"..."}`, returns `[{"template_id":"uuid"}]`) |
| `/api/db/label_list` | GET | List all labels (summary with template info, excludes deleted) |
| `/api/db/label_detail?id=eq.<uuid>` | GET | Full label+template data for rendering |
| `/api/db/rpc/create_label` | POST | Create label from template (body: `{"p_template_id":"uuid","p_name":"..."}`, returns `[{"label_id":"uuid"}]`) |
| `/api/db/labelset_list` | GET | List all labelsets (summary with template info, excludes deleted) |
| `/api/db/labelset_detail?id=eq.<uuid>` | GET | Full labelset+template data for rendering |
| `/api/db/rpc/create_labelset` | POST | Create labelset from template (body: `{"p_template_id":"uuid","p_name":"..."}`, returns `[{"labelset_id":"uuid"}]`) |
| `/api/db/rpc/delete_template` | POST | Delete template (body: `{"p_template_id":"uuid"}`) |
| `/api/db/rpc/set_template_name` | POST | Set template name (body: `{"p_template_id":"uuid","p_name":"..."}`) |
| `/api/db/rpc/set_template_label_type` | POST | Set template label type (body: `{"p_template_id":"uuid","p_label_type_id":"...","p_label_width":N,"p_label_height":N,"p_corner_radius":N,"p_rotate":bool}`) |
| `/api/db/rpc/set_template_height` | POST | Set template height (body: `{"p_template_id":"uuid","p_label_height":N}`) |
| `/api/db/rpc/set_template_padding` | POST | Set template padding (body: `{"p_template_id":"uuid","p_padding":N}`) |
| `/api/db/rpc/set_template_content` | POST | Set template content (body: `{"p_template_id":"uuid","p_content":[...],"p_next_id":N}`) |
| `/api/db/rpc/set_template_sample_value` | POST | Set template sample value (body: `{"p_template_id":"uuid","p_variable_name":"...","p_value":"..."}`) |
| `/api/db/rpc/delete_label` | POST | Delete label (body: `{"p_label_id":"uuid"}`) |
| `/api/db/rpc/set_label_name` | POST | Set label name (body: `{"p_label_id":"uuid","p_name":"..."}`) |
| `/api/db/rpc/set_label_values` | POST | Set label values (body: `{"p_label_id":"uuid","p_values":{...}}`) |
| `/api/db/rpc/delete_labelset` | POST | Delete labelset (body: `{"p_labelset_id":"uuid"}`) |
| `/api/db/rpc/set_labelset_name` | POST | Set labelset name (body: `{"p_labelset_id":"uuid","p_name":"..."}`) |
| `/api/db/rpc/set_labelset_rows` | POST | Set labelset rows (body: `{"p_labelset_id":"uuid","p_rows":[{...},...]}`) |
| `/api/printer/print` | POST | Print PNG label (body: `{"image_data":"base64...","label_type":"62"}`) |
| `/api/printer/health` | GET | Printer service health check |

## Adding a New Page

Same pattern as FrostByte:

1. Create `Page/NewPage.elm` (facade) + `Page/NewPage/Types.elm` + `Page/NewPage/View.elm`
2. Add route in `Route.elm`
3. Wire up in `Main.elm` (Page type, Msg type, initPage, update, viewPage)
4. Add nav link in `Components.elm`
