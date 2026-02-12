module Api.Encoders exposing
    ( encodeBatchRequest
    , encodeConsumeRequest
    , encodeContainerType
    , encodeIngredient
    , encodeLabelPreset
    , encodePrintPngRequest
    , encodePrintRequest
    , encodeRecipeRequest
    , encodeReturnToFreezerRequest
    )

import Json.Encode as Encode
import Types exposing (..)
import UUID exposing (UUID)


encodeBatchRequest : BatchForm -> UUID -> List UUID -> Maybe String -> String -> Maybe String -> Encode.Value
encodeBatchRequest form batchUuid portionUuids maybeLabelPreset expiryDate maybeBestBeforeDate =
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

        bestBeforeField =
            case maybeBestBeforeDate of
                Just date ->
                    [ ( "p_best_before_date", Encode.string date ) ]

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
         , ( "p_expiry_date", Encode.string expiryDate )
         ]
            ++ bestBeforeField
            ++ labelPresetField
            ++ detailsField
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


encodeConsumeRequest : Encode.Value
encodeConsumeRequest =
    Encode.object
        [ ( "status", Encode.string "CONSUMED" )
        , ( "consumed_at", Encode.string "now()" )
        ]


encodeReturnToFreezerRequest : Encode.Value
encodeReturnToFreezerRequest =
    Encode.object
        [ ( "status", Encode.string "FROZEN" )
        , ( "consumed_at", Encode.null )
        ]


encodeContainerType : ContainerTypeForm -> Encode.Value
encodeContainerType form =
    Encode.object
        [ ( "name", Encode.string form.name )
        , ( "servings_per_unit", Encode.float (Maybe.withDefault 1.0 (String.toFloat form.servingsPerUnit)) )
        ]


encodeIngredient : IngredientForm -> Encode.Value
encodeIngredient form =
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
        [ ( "name", Encode.string (String.toLower form.name) )
        , ( "expire_days", expireDaysValue )
        , ( "best_before_days", bestBeforeDaysValue )
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
            [ ( "p_name", Encode.string (String.toLower form.name) )
            , ( "p_ingredient_names", Encode.list Encode.string ingredientNames )
            , ( "p_default_portions", Encode.int portions )
            , ( "p_default_container_id", containerValue )
            , ( "p_default_label_preset", labelPresetValue )
            , ( "p_details", detailsValue )
            ]

        fields =
            case form.editing of
                Just originalName ->
                    baseFields ++ [ ( "p_original_name", Encode.string originalName ) ]

                Nothing ->
                    baseFields
    in
    Encode.object fields


encodeLabelPreset : LabelPresetForm -> Encode.Value
encodeLabelPreset form =
    Encode.object
        [ ( "name", Encode.string form.name )
        , ( "label_type", Encode.string form.labelType )
        , ( "width", Encode.int (Maybe.withDefault 696 (String.toInt form.width)) )
        , ( "height", Encode.int (Maybe.withDefault 300 (String.toInt form.height)) )
        , ( "qr_size", Encode.int (Maybe.withDefault 200 (String.toInt form.qrSize)) )
        , ( "padding", Encode.int (Maybe.withDefault 20 (String.toInt form.padding)) )
        , ( "title_font_size", Encode.int (Maybe.withDefault 48 (String.toInt form.titleFontSize)) )
        , ( "date_font_size", Encode.int (Maybe.withDefault 32 (String.toInt form.dateFontSize)) )
        , ( "small_font_size", Encode.int (Maybe.withDefault 18 (String.toInt form.smallFontSize)) )
        , ( "font_family", Encode.string form.fontFamily )
        , ( "show_title", Encode.bool form.showTitle )
        , ( "show_ingredients", Encode.bool form.showIngredients )
        , ( "show_expiry_date", Encode.bool form.showExpiryDate )
        , ( "show_best_before", Encode.bool form.showBestBefore )
        , ( "show_qr", Encode.bool form.showQr )
        , ( "show_branding", Encode.bool form.showBranding )
        , ( "vertical_spacing", Encode.int (Maybe.withDefault 10 (String.toInt form.verticalSpacing)) )
        , ( "show_separator", Encode.bool form.showSeparator )
        , ( "separator_thickness", Encode.int (Maybe.withDefault 1 (String.toInt form.separatorThickness)) )
        , ( "separator_color", Encode.string form.separatorColor )
        , ( "corner_radius", Encode.int (Maybe.withDefault 0 (String.toInt form.cornerRadius)) )
        , ( "title_min_font_size", Encode.int (Maybe.withDefault 24 (String.toInt form.titleMinFontSize)) )
        , ( "ingredients_max_chars", Encode.int (Maybe.withDefault 45 (String.toInt form.ingredientsMaxChars)) )
        , ( "rotate", Encode.bool form.rotate )
        ]


encodePrintPngRequest : String -> String -> Encode.Value
encodePrintPngRequest pngBase64 labelType =
    Encode.object
        [ ( "image_data", Encode.string pngBase64 )
        , ( "label_type", Encode.string labelType )
        ]
