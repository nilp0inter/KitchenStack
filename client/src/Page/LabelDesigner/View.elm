module Page.LabelDesigner.View exposing (view)

import Data.Label
import Data.LabelTypes exposing (LabelTypeSpec, isEndlessLabel, labelTypes)
import Html exposing (..)
import Html.Attributes as Attr exposing (checked, class, disabled, placeholder, required, selected, title, type_, value)
import Html.Events exposing (onCheck, onClick, onInput, onSubmit)
import Label
import Page.LabelDesigner.Types exposing (..)
import Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Diseñador de Etiquetas" ]
        , div [ class "grid grid-cols-1 lg:grid-cols-2 gap-6" ]
            [ div [ class "space-y-6" ]
                [ viewForm model
                , viewList model
                ]
            , viewPreview model
            ]
        , viewDeleteConfirm model.deleteConfirm
        ]


viewForm : Model -> Html Msg
viewForm model =
    div [ class "card" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ]
            [ text
                (if model.form.editing /= Nothing then
                    "Editar Preset"

                 else
                    "Nuevo Preset"
                )
            ]
        , Html.form [ onSubmit SavePreset, class "space-y-4" ]
            [ -- Name field
              div []
                [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Nombre" ]
                , input
                    [ type_ "text"
                    , class "input-field"
                    , placeholder "Ej: Mi etiqueta personalizada"
                    , value model.form.name
                    , onInput FormNameChanged
                    , required True
                    , disabled (model.form.editing /= Nothing)
                    ]
                    []
                ]

            -- Label type selector
            , div []
                [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Tipo de Cinta/Etiqueta" ]
                , select
                    [ class "input-field"
                    , onInput FormLabelTypeChanged
                    , value model.form.labelType
                    ]
                    (List.map
                        (\spec ->
                            option
                                [ value spec.id
                                , selected (spec.id == model.form.labelType)
                                ]
                                [ text (spec.description ++ " (" ++ String.fromInt spec.width ++ "px)") ]
                        )
                        labelTypes
                    )
                , p [ class "text-xs text-gray-500 mt-1" ]
                    [ text
                        (if isEndlessLabel model.form.labelType then
                            "Cinta endless: ancho fijo, alto configurable"

                         else
                            "Etiqueta die-cut: dimensiones fijas"
                        )
                    ]
                ]

            -- Dimensions section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Dimensiones" ]
                , div [ class "grid grid-cols-2 gap-3" ]
                    [ div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Ancho (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field bg-gray-100"
                            , Attr.min "100"
                            , value model.form.width
                            , onInput FormWidthChanged
                            , disabled True
                            , title "El ancho está determinado por el tipo de etiqueta"
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ]
                            [ text
                                (if isEndlessLabel model.form.labelType then
                                    "Alto (px) - configurable"

                                 else
                                    "Alto (px) - fijo"
                                )
                            ]
                        , input
                            [ type_ "number"
                            , class
                                (if isEndlessLabel model.form.labelType then
                                    "input-field"

                                 else
                                    "input-field bg-gray-100"
                                )
                            , Attr.min "50"
                            , value model.form.height
                            , onInput FormHeightChanged
                            , disabled (not (isEndlessLabel model.form.labelType))
                            ]
                            []
                        ]
                    ]
                , div [ class "grid grid-cols-2 gap-3 mt-2" ]
                    [ div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Tamaño QR (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "30"
                            , value model.form.qrSize
                            , onInput FormQrSizeChanged
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Padding (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "0"
                            , value model.form.padding
                            , onInput FormPaddingChanged
                            ]
                            []
                        ]
                    ]
                ]

            -- Font section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Fuentes" ]
                , div [ class "grid grid-cols-3 gap-3" ]
                    [ div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Título (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "8"
                            , value model.form.titleFontSize
                            , onInput FormTitleFontSizeChanged
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Fecha (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "8"
                            , value model.form.dateFontSize
                            , onInput FormDateFontSizeChanged
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Pequeña (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "6"
                            , value model.form.smallFontSize
                            , onInput FormSmallFontSizeChanged
                            ]
                            []
                        ]
                    ]
                , div [ class "mt-2" ]
                    [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Familia de fuente" ]
                    , input
                        [ type_ "text"
                        , class "input-field"
                        , placeholder "Atkinson Hyperlegible, sans-serif"
                        , value model.form.fontFamily
                        , onInput FormFontFamilyChanged
                        ]
                        []
                    ]
                ]

            -- Field visibility section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Campos visibles" ]
                , div [ class "grid grid-cols-2 gap-2" ]
                    [ viewCheckbox "Título" model.form.showTitle FormShowTitleChanged
                    , viewCheckbox "Ingredientes" model.form.showIngredients FormShowIngredientsChanged
                    , viewCheckbox "Fecha caducidad" model.form.showExpiryDate FormShowExpiryDateChanged
                    , viewCheckbox "Consumo preferente" model.form.showBestBefore FormShowBestBeforeChanged
                    , viewCheckbox "Código QR" model.form.showQr FormShowQrChanged
                    , viewCheckbox "Marca FrostByte" model.form.showBranding FormShowBrandingChanged
                    ]
                ]

            -- Text fitting section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Ajuste de texto" ]
                , div [ class "grid grid-cols-2 gap-3" ]
                    [ div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Tamaño min. título (px)" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "8"
                            , value model.form.titleMinFontSize
                            , onInput FormTitleMinFontSizeChanged
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Máx. caracteres ingredientes" ]
                        , input
                            [ type_ "number"
                            , class "input-field"
                            , Attr.min "10"
                            , value model.form.ingredientsMaxChars
                            , onInput FormIngredientsMaxCharsChanged
                            ]
                            []
                        ]
                    ]
                ]

            -- Layout section
            , div []
                [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Diseño" ]
                , div [ class "space-y-3" ]
                    [ div [ class "grid grid-cols-2 gap-3" ]
                        [ div []
                            [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Espaciado vertical (px)" ]
                            , input
                                [ type_ "number"
                                , class "input-field"
                                , Attr.min "0"
                                , value model.form.verticalSpacing
                                , onInput FormVerticalSpacingChanged
                                ]
                                []
                            ]
                        , div []
                            [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Radio esquinas (px)" ]
                            , input
                                [ type_ "number"
                                , class "input-field"
                                , Attr.min "0"
                                , value model.form.cornerRadius
                                , onInput FormCornerRadiusChanged
                                , title "Solo afecta la vista previa"
                                ]
                                []
                            ]
                        ]
                    , viewCheckbox "Línea separadora" model.form.showSeparator FormShowSeparatorChanged
                    , if model.form.showSeparator then
                        div [ class "grid grid-cols-2 gap-3 ml-6" ]
                            [ div []
                                [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Grosor (px)" ]
                                , input
                                    [ type_ "number"
                                    , class "input-field"
                                    , Attr.min "1"
                                    , value model.form.separatorThickness
                                    , onInput FormSeparatorThicknessChanged
                                    ]
                                    []
                                ]
                            , div []
                                [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Color" ]
                                , input
                                    [ type_ "color"
                                    , class "input-field h-10"
                                    , value model.form.separatorColor
                                    , onInput FormSeparatorColorChanged
                                    ]
                                    []
                                ]
                            ]

                      else
                        text ""
                    , viewCheckbox "Rotar 90° para impresión" model.form.rotate FormRotateChanged
                    ]
                ]

            -- Submit buttons
            , div [ class "flex justify-end space-x-4 pt-4" ]
                [ if model.form.editing /= Nothing then
                    button
                        [ type_ "button"
                        , class "px-4 py-2 bg-gray-500 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors"
                        , onClick CancelEdit
                        ]
                        [ text "Cancelar" ]

                  else
                    text ""
                , button
                    [ type_ "submit"
                    , class "btn-primary"
                    , disabled model.loading
                    ]
                    [ if model.loading then
                        text "Guardando..."

                      else
                        text "Guardar"
                    ]
                ]
            ]
        ]


viewCheckbox : String -> Bool -> (Bool -> Msg) -> Html Msg
viewCheckbox labelText isChecked onChange =
    label [ class "flex items-center space-x-2 cursor-pointer" ]
        [ input
            [ type_ "checkbox"
            , class "w-4 h-4 text-frost-600 rounded border-gray-300 focus:ring-frost-500"
            , checked isChecked
            , onCheck onChange
            ]
            []
        , span [ class "text-sm text-gray-700" ] [ text labelText ]
        ]


viewPreview : Model -> Html Msg
viewPreview model =
    let
        settings =
            formToSettings model.form

        sampleData =
            { portionId = "sample-preview"
            , name = model.sampleName
            , ingredients = model.sampleIngredients
            , expiryDate = "2025-12-31"
            , bestBeforeDate = Just "2025-12-25"
            , appHost = model.appHost
            }

        -- Use computed data if available, otherwise use defaults
        computed =
            case model.computedLabelData of
                Just data ->
                    data

                Nothing ->
                    { titleFontSize = settings.titleFontSize
                    , titleLines = [ model.sampleName ]
                    , ingredientLines = [ model.sampleIngredients ]
                    }

        zoomPercent =
            round (model.previewZoom * 100)
    in
    div [ class "card sticky top-4" ]
        [ -- Header with title and container height control
          div [ class "flex items-center justify-between mb-4" ]
            [ h2 [ class "text-lg font-semibold text-gray-800" ] [ text "Vista Previa" ]
            , div [ class "flex items-center gap-2" ]
                [ label [ class "text-xs text-gray-500" ] [ text "Alto:" ]
                , input
                    [ type_ "number"
                    , class "w-20 px-2 py-1 text-sm border border-gray-300 rounded"
                    , Attr.min "200"
                    , Attr.max "800"
                    , value (String.fromInt model.previewContainerHeight)
                    , onInput PreviewContainerHeightChanged
                    ]
                    []
                , span [ class "text-xs text-gray-500" ] [ text "px" ]
                ]
            ]

        -- Preview container with fixed height and zoom/pan
        , div
            [ Attr.id "label-preview-container"
            , class "flex justify-center items-center bg-gray-100 rounded-lg overflow-hidden"
            , Attr.style "height" (String.fromInt model.previewContainerHeight ++ "px")
            ]
            [ div
                [ Attr.attribute "data-zoom-target" "true"
                , Attr.style "transform" ("scale(" ++ String.fromFloat model.previewZoom ++ ") translate(" ++ String.fromFloat model.previewPanX ++ "px, " ++ String.fromFloat model.previewPanY ++ "px)")
                , Attr.style "transform-origin" "center center"
                , Attr.style "transition" "transform 0.1s ease-out"
                ]
                [ Label.viewLabelWithComputed settings sampleData computed ]
            ]

        -- Zoom controls
        , div [ class "mt-3 flex items-center justify-center gap-3" ]
            [ button
                [ type_ "button"
                , class "w-8 h-8 flex items-center justify-center bg-gray-200 hover:bg-gray-300 rounded text-lg font-bold"
                , onClick ZoomOut
                , disabled (model.previewZoom <= 0.25)
                ]
                [ text "-" ]
            , input
                [ type_ "range"
                , class "w-32"
                , Attr.min "25"
                , Attr.max "300"
                , Attr.step "5"
                , value (String.fromInt zoomPercent)
                , onInput (\s -> ZoomChanged (toFloat (Maybe.withDefault 100 (String.toInt s)) / 100))
                ]
                []
            , button
                [ type_ "button"
                , class "w-8 h-8 flex items-center justify-center bg-gray-200 hover:bg-gray-300 rounded text-lg font-bold"
                , onClick ZoomIn
                , disabled (model.previewZoom >= 3.0)
                ]
                [ text "+" ]
            , span [ class "text-sm text-gray-600 w-12 text-center" ] [ text (String.fromInt zoomPercent ++ "%") ]
            , button
                [ type_ "button"
                , class "px-2 py-1 text-xs bg-gray-200 hover:bg-gray-300 rounded"
                , onClick ResetZoomPan
                ]
                [ text "Reset" ]
            ]

        -- Sample text inputs
        , div [ class "mt-4 p-3 bg-gray-50 rounded-lg" ]
            [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Texto de prueba" ]
            , div [ class "space-y-2" ]
                [ div []
                    [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Nombre" ]
                    , input
                        [ type_ "text"
                        , class "input-field"
                        , placeholder "Nombre del producto"
                        , value model.sampleName
                        , onInput SampleNameChanged
                        ]
                        []
                    ]
                , div []
                    [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Ingredientes" ]
                    , input
                        [ type_ "text"
                        , class "input-field"
                        , placeholder "ingrediente1, ingrediente2, ..."
                        , value model.sampleIngredients
                        , onInput SampleIngredientsChanged
                        ]
                        []
                    ]
                ]
            ]

        -- Dimension info
        , div [ class "mt-4 text-center text-sm text-gray-500" ]
            [ text (String.fromInt (Data.Label.displayWidth settings) ++ " x " ++ String.fromInt (Data.Label.displayHeight settings) ++ " px (pantalla)")
            , Html.br [] []
            , text (String.fromInt settings.width ++ " x " ++ String.fromInt settings.height ++ " px (impresión)")
            , if settings.cornerRadius > 0 then
                span [ class "ml-2 text-xs text-gray-400" ] [ text "(radio de esquinas solo en vista previa)" ]

              else
                text ""
            ]

        -- Print button
        , div [ class "mt-4 flex justify-center" ]
            [ button
                [ type_ "button"
                , class "btn-primary flex items-center gap-2"
                , onClick PrintLabel
                , disabled (model.isPrinting || model.computedLabelData == Nothing)
                ]
                [ if model.isPrinting then
                    span [ class "animate-spin" ] [ text "⏳" ]

                  else
                    text ""
                , text
                    (if model.isPrinting then
                        "Imprimiendo..."

                     else
                        "Imprimir prueba"
                    )
                ]
            ]
        , viewHiddenLabel model settings sampleData computed
        ]


viewList : Model -> Html Msg
viewList model =
    div [ class "card" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ] [ text "Presets existentes" ]
        , if List.isEmpty model.presets then
            div [ class "text-center py-8 text-gray-500" ]
                [ text "No hay presets definidos" ]

          else
            div [ class "space-y-2 max-h-64 overflow-y-auto" ]
                (List.map viewPresetRow model.presets)
        ]


viewPresetRow : LabelPreset -> Html Msg
viewPresetRow preset =
    div [ class "flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100" ]
        [ div []
            [ div [ class "font-medium text-gray-900" ] [ text preset.name ]
            , div [ class "text-sm text-gray-500" ]
                [ text (String.fromInt preset.width ++ "x" ++ String.fromInt preset.height ++ " px (impresión)") ]
            ]
        , div [ class "flex space-x-2" ]
            [ button
                [ onClick (EditPreset preset)
                , class "text-blue-600 hover:text-blue-800 font-medium text-sm"
                , title "Editar"
                ]
                [ text "Editar" ]
            , button
                [ onClick (DeletePreset preset.name)
                , class "text-red-600 hover:text-red-800 font-medium text-sm"
                , title "Eliminar"
                ]
                [ text "Eliminar" ]
            ]
        ]


viewDeleteConfirm : Maybe String -> Html Msg
viewDeleteConfirm maybeName =
    case maybeName of
        Just name ->
            div [ class "fixed inset-0 z-50 flex items-center justify-center" ]
                [ div
                    [ class "absolute inset-0 bg-black bg-opacity-50"
                    , onClick CancelDelete
                    ]
                    []
                , div [ class "relative bg-white rounded-xl shadow-2xl max-w-md w-full mx-4 overflow-hidden" ]
                    [ div [ class "px-6 py-4 border-b" ]
                        [ h3 [ class "text-lg font-semibold text-gray-800" ]
                            [ text "Confirmar eliminación" ]
                        ]
                    , div [ class "p-6" ]
                        [ p [ class "text-gray-600" ]
                            [ text "¿Estás seguro de que quieres eliminar el preset \""
                            , span [ class "font-medium" ] [ text name ]
                            , text "\"? Esta acción no se puede deshacer."
                            ]
                        ]
                    , div [ class "flex justify-end px-6 py-4 bg-gray-50 border-t space-x-4" ]
                        [ button
                            [ onClick CancelDelete
                            , class "px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-medium"
                            ]
                            [ text "Cancelar" ]
                        , button
                            [ onClick (ConfirmDelete name)
                            , class "px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium"
                            ]
                            [ text "Eliminar" ]
                        ]
                    ]
                ]

        Nothing ->
            text ""


{-| Render a hidden label for SVG→PNG conversion.
-}
viewHiddenLabel : Model -> Data.Label.LabelSettings -> Data.Label.LabelData -> Data.Label.ComputedLabelData -> Html Msg
viewHiddenLabel model settings sampleData computed =
    if model.isPrinting then
        let
            -- For printing, we render without corner radius (print dimensions only)
            printSettings =
                { settings | cornerRadius = 0 }
        in
        div
            [ Attr.style "position" "absolute"
            , Attr.style "left" "-9999px"
            , Attr.style "top" "-9999px"
            ]
            [ Label.viewLabelWithComputed printSettings sampleData computed ]

    else
        text ""
