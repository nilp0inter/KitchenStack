module Api.Encoders exposing
    ( encodeBatchRequest
    , encodeConsumePortionRequest
    , encodeCreateContainerType
    , encodeCreateIngredient
    , encodeCreateLabelPreset
    , encodeDeleteRequest
    , encodeDiscardPortionRequest
    , encodePrintPngRequest
    , encodePrintRequest
    , encodeRecipeRequest
    , encodeRecordPortionPrintedRequest
    , encodeReturnPortionRequest
    , encodeUpdateBatchRequest
    , encodeUpdateContainerType
    , encodeUpdateIngredient
    , encodeUpdateLabelPreset
    )

import Json.Encode as Encode
import Types exposing (..)
import UUID exposing (UUID)


encodeBatchRequest : BatchForm -> UUID -> List UUID -> Maybe String -> Encode.Value
encodeBatchRequest form batchUuid portionUuids maybeLabelPreset =
    let
        ingredientNames =
            List.map .name form.selectedIngredients

        labelPresetField =
            case maybeLabelPreset of
                Just presetName ->
                    [ ( "p_label_preset", Encode.string presetName ) ]

                Nothing ->
                    []

        detailsField =
            if String.trim form.details /= "" then
                [ ( "p_details", Encode.string form.details ) ]

            else
                []

        -- Only include manual expiry if user provided one
        expiryField =
            if form.expiryDate /= "" then
                [ ( "p_expiry_date", Encode.string form.expiryDate ) ]

            else
                []

        imageField =
            case form.image of
                Just imageData ->
                    [ ( "p_image_data", Encode.string imageData ) ]

                Nothing ->
                    []
    in
    Encode.object
        ([ ( "p_batch_id", Encode.string (UUID.toString batchUuid) )
         , ( "p_portion_ids", Encode.list (Encode.string << UUID.toString) portionUuids )
         , ( "p_name", Encode.string form.name )
         , ( "p_ingredient_names", Encode.list Encode.string ingredientNames )
         , ( "p_container_id", Encode.string form.containerId )
         , ( "p_created_at", Encode.string form.createdAt )
         ]
            ++ expiryField
            ++ labelPresetField
            ++ detailsField
            ++ imageField
        )


encodePrintRequest : PortionPrintData -> Encode.Value
encodePrintRequest data =
    Encode.object
        [ ( "id", Encode.string data.portionId )
        , ( "name", Encode.string data.name )
        , ( "ingredients", Encode.string data.ingredients )
        , ( "container", Encode.string data.containerId )
        , ( "expiry_date", Encode.string data.expiryDate )
        ]


encodeConsumePortionRequest : String -> Encode.Value
encodeConsumePortionRequest portionId =
    Encode.object
        [ ( "p_portion_id", Encode.string portionId ) ]


encodeReturnPortionRequest : String -> Encode.Value
encodeReturnPortionRequest portionId =
    Encode.object
        [ ( "p_portion_id", Encode.string portionId ) ]


encodeDeleteRequest : String -> Encode.Value
encodeDeleteRequest name =
    Encode.object
        [ ( "p_name", Encode.string name ) ]


encodeCreateContainerType : ContainerTypeForm -> Encode.Value
encodeCreateContainerType form =
    Encode.object
        [ ( "p_name", Encode.string form.name )
        , ( "p_servings_per_unit", Encode.float (Maybe.withDefault 1.0 (String.toFloat form.servingsPerUnit)) )
        ]


encodeUpdateContainerType : ContainerTypeForm -> Encode.Value
encodeUpdateContainerType form =
    Encode.object
        [ ( "p_original_name", Encode.string (Maybe.withDefault form.name form.editing) )
        , ( "p_name", Encode.string form.name )
        , ( "p_servings_per_unit", Encode.float (Maybe.withDefault 1.0 (String.toFloat form.servingsPerUnit)) )
        ]


encodeCreateIngredient : IngredientForm -> Encode.Value
encodeCreateIngredient form =
    let
        expireDaysValue =
            case String.toInt form.expireDays of
                Just days ->
                    Encode.int days

                Nothing ->
                    Encode.null

        bestBeforeDaysValue =
            case String.toInt form.bestBeforeDays of
                Just days ->
                    Encode.int days

                Nothing ->
                    Encode.null
    in
    Encode.object
        [ ( "p_name", Encode.string (String.toLower form.name) )
        , ( "p_expire_days", expireDaysValue )
        , ( "p_best_before_days", bestBeforeDaysValue )
        ]


encodeUpdateIngredient : IngredientForm -> Encode.Value
encodeUpdateIngredient form =
    let
        expireDaysValue =
            case String.toInt form.expireDays of
                Just days ->
                    Encode.int days

                Nothing ->
                    Encode.null

        bestBeforeDaysValue =
            case String.toInt form.bestBeforeDays of
                Just days ->
                    Encode.int days

                Nothing ->
                    Encode.null
    in
    Encode.object
        [ ( "p_original_name", Encode.string (String.toLower (Maybe.withDefault form.name form.editing)) )
        , ( "p_name", Encode.string (String.toLower form.name) )
        , ( "p_expire_days", expireDaysValue )
        , ( "p_best_before_days", bestBeforeDaysValue )
        ]


encodeRecipeRequest : RecipeForm -> Encode.Value
encodeRecipeRequest form =
    let
        ingredientNames =
            List.map .name form.selectedIngredients

        containerValue =
            if form.defaultContainerId == "" then
                Encode.null

            else
                Encode.string form.defaultContainerId

        labelPresetValue =
            if form.defaultLabelPreset == "" then
                Encode.null

            else
                Encode.string form.defaultLabelPreset

        detailsValue =
            if String.trim form.details == "" then
                Encode.null

            else
                Encode.string form.details

        portions =
            Maybe.withDefault 1 (String.toInt form.defaultPortions)

        baseFields =
            [ ( "p_name", Encode.string form.name )
            , ( "p_ingredient_names", Encode.list Encode.string ingredientNames )
            , ( "p_default_portions", Encode.int portions )
            , ( "p_default_container_id", containerValue )
            , ( "p_default_label_preset", labelPresetValue )
            , ( "p_details", detailsValue )
            ]

        imageField =
            case form.image of
                Just imageData ->
                    [ ( "p_image_data", Encode.string imageData ) ]

                Nothing ->
                    []

        editingField =
            case form.editing of
                Just originalName ->
                    [ ( "p_original_name", Encode.string originalName ) ]

                Nothing ->
                    []
    in
    Encode.object (baseFields ++ imageField ++ editingField)


encodeCreateLabelPreset : LabelPresetForm -> Encode.Value
encodeCreateLabelPreset form =
    Encode.object
        [ ( "p_name", Encode.string form.name )
        , ( "p_label_type", Encode.string form.labelType )
        , ( "p_width", Encode.int (Maybe.withDefault 696 (String.toInt form.width)) )
        , ( "p_height", Encode.int (Maybe.withDefault 300 (String.toInt form.height)) )
        , ( "p_qr_size", Encode.int (Maybe.withDefault 200 (String.toInt form.qrSize)) )
        , ( "p_padding", Encode.int (Maybe.withDefault 20 (String.toInt form.padding)) )
        , ( "p_title_font_size", Encode.int (Maybe.withDefault 48 (String.toInt form.titleFontSize)) )
        , ( "p_date_font_size", Encode.int (Maybe.withDefault 32 (String.toInt form.dateFontSize)) )
        , ( "p_small_font_size", Encode.int (Maybe.withDefault 18 (String.toInt form.smallFontSize)) )
        , ( "p_font_family", Encode.string form.fontFamily )
        , ( "p_show_title", Encode.bool form.showTitle )
        , ( "p_show_ingredients", Encode.bool form.showIngredients )
        , ( "p_show_expiry_date", Encode.bool form.showExpiryDate )
        , ( "p_show_best_before", Encode.bool form.showBestBefore )
        , ( "p_show_qr", Encode.bool form.showQr )
        , ( "p_show_branding", Encode.bool form.showBranding )
        , ( "p_vertical_spacing", Encode.int (Maybe.withDefault 10 (String.toInt form.verticalSpacing)) )
        , ( "p_show_separator", Encode.bool form.showSeparator )
        , ( "p_separator_thickness", Encode.int (Maybe.withDefault 1 (String.toInt form.separatorThickness)) )
        , ( "p_separator_color", Encode.string form.separatorColor )
        , ( "p_corner_radius", Encode.int (Maybe.withDefault 0 (String.toInt form.cornerRadius)) )
        , ( "p_title_min_font_size", Encode.int (Maybe.withDefault 24 (String.toInt form.titleMinFontSize)) )
        , ( "p_ingredients_max_chars", Encode.int (Maybe.withDefault 45 (String.toInt form.ingredientsMaxChars)) )
        , ( "p_rotate", Encode.bool form.rotate )
        ]


encodeUpdateLabelPreset : LabelPresetForm -> Encode.Value
encodeUpdateLabelPreset form =
    Encode.object
        [ ( "p_original_name", Encode.string (Maybe.withDefault form.name form.editing) )
        , ( "p_name", Encode.string form.name )
        , ( "p_label_type", Encode.string form.labelType )
        , ( "p_width", Encode.int (Maybe.withDefault 696 (String.toInt form.width)) )
        , ( "p_height", Encode.int (Maybe.withDefault 300 (String.toInt form.height)) )
        , ( "p_qr_size", Encode.int (Maybe.withDefault 200 (String.toInt form.qrSize)) )
        , ( "p_padding", Encode.int (Maybe.withDefault 20 (String.toInt form.padding)) )
        , ( "p_title_font_size", Encode.int (Maybe.withDefault 48 (String.toInt form.titleFontSize)) )
        , ( "p_date_font_size", Encode.int (Maybe.withDefault 32 (String.toInt form.dateFontSize)) )
        , ( "p_small_font_size", Encode.int (Maybe.withDefault 18 (String.toInt form.smallFontSize)) )
        , ( "p_font_family", Encode.string form.fontFamily )
        , ( "p_show_title", Encode.bool form.showTitle )
        , ( "p_show_ingredients", Encode.bool form.showIngredients )
        , ( "p_show_expiry_date", Encode.bool form.showExpiryDate )
        , ( "p_show_best_before", Encode.bool form.showBestBefore )
        , ( "p_show_qr", Encode.bool form.showQr )
        , ( "p_show_branding", Encode.bool form.showBranding )
        , ( "p_vertical_spacing", Encode.int (Maybe.withDefault 10 (String.toInt form.verticalSpacing)) )
        , ( "p_show_separator", Encode.bool form.showSeparator )
        , ( "p_separator_thickness", Encode.int (Maybe.withDefault 1 (String.toInt form.separatorThickness)) )
        , ( "p_separator_color", Encode.string form.separatorColor )
        , ( "p_corner_radius", Encode.int (Maybe.withDefault 0 (String.toInt form.cornerRadius)) )
        , ( "p_title_min_font_size", Encode.int (Maybe.withDefault 24 (String.toInt form.titleMinFontSize)) )
        , ( "p_ingredients_max_chars", Encode.int (Maybe.withDefault 45 (String.toInt form.ingredientsMaxChars)) )
        , ( "p_rotate", Encode.bool form.rotate )
        ]


encodePrintPngRequest : String -> String -> Encode.Value
encodePrintPngRequest pngBase64 labelType =
    Encode.object
        [ ( "image_data", Encode.string pngBase64 )
        , ( "label_type", Encode.string labelType )
        ]


encodeDiscardPortionRequest : String -> Encode.Value
encodeDiscardPortionRequest portionId =
    Encode.object
        [ ( "p_portion_id", Encode.string portionId ) ]


encodeRecordPortionPrintedRequest : String -> Encode.Value
encodeRecordPortionPrintedRequest portionId =
    Encode.object
        [ ( "p_portion_id", Encode.string portionId ) ]


encodeUpdateBatchRequest :
    { batchId : String
    , name : String
    , containerId : String
    , ingredientNames : List String
    , labelPreset : Maybe String
    , details : String
    , image : Maybe String
    , removeImage : Bool
    , bestBeforeDate : String
    , newPortionIds : List String
    , discardPortionIds : List String
    , newPortionsCreatedAt : String
    , newPortionsExpiryDate : String
    }
    -> Encode.Value
encodeUpdateBatchRequest params =
    let
        labelPresetField =
            case params.labelPreset of
                Just presetName ->
                    [ ( "p_label_preset", Encode.string presetName ) ]

                Nothing ->
                    []

        detailsField =
            if String.trim params.details /= "" then
                [ ( "p_details", Encode.string params.details ) ]

            else
                []

        imageField =
            case params.image of
                Just imageData ->
                    [ ( "p_image_data", Encode.string imageData ) ]

                Nothing ->
                    []

        bestBeforeField =
            if params.bestBeforeDate /= "" then
                [ ( "p_best_before_date", Encode.string params.bestBeforeDate ) ]

            else
                []

        newPortionIdsField =
            if not (List.isEmpty params.newPortionIds) then
                [ ( "p_new_portion_ids", Encode.list Encode.string params.newPortionIds ) ]

            else
                []

        discardPortionIdsField =
            if not (List.isEmpty params.discardPortionIds) then
                [ ( "p_discard_portion_ids", Encode.list Encode.string params.discardPortionIds ) ]

            else
                []

        newPortionsCreatedAtField =
            if params.newPortionsCreatedAt /= "" then
                [ ( "p_new_portions_created_at", Encode.string params.newPortionsCreatedAt ) ]

            else
                []

        newPortionsExpiryField =
            if params.newPortionsExpiryDate /= "" then
                [ ( "p_new_portions_expiry_date", Encode.string params.newPortionsExpiryDate ) ]

            else
                []
    in
    Encode.object
        ([ ( "p_batch_id", Encode.string params.batchId )
         , ( "p_name", Encode.string params.name )
         , ( "p_container_id", Encode.string params.containerId )
         , ( "p_ingredient_names", Encode.list Encode.string params.ingredientNames )
         , ( "p_remove_image", Encode.bool params.removeImage )
         ]
            ++ labelPresetField
            ++ detailsField
            ++ imageField
            ++ bestBeforeField
            ++ newPortionIdsField
            ++ discardPortionIdsField
            ++ newPortionsCreatedAtField
            ++ newPortionsExpiryField
        )
