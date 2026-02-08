module Page.LabelDesigner exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    , init
    , update
    , view
    )

{-| Label Designer page for managing label presets with live preview.
-}

import Api
import Html exposing (..)
import Html.Attributes as Attr exposing (checked, class, disabled, placeholder, required, selected, title, type_, value)
import Html.Events exposing (onCheck, onClick, onInput, onSubmit)
import Http
import Label
import Ports
import Types exposing (..)


{-| Specification for a brother_ql label type.
-}
type alias LabelTypeSpec =
    { id : String
    , description : String
    , width : Int
    , height : Maybe Int -- Nothing for endless (variable height)
    , isEndless : Bool
    , isRound : Bool
    }


{-| All supported brother_ql label types.
-}
labelTypes : List LabelTypeSpec
labelTypes =
    [ -- Endless labels
      { id = "12", description = "12mm endless", width = 106, height = Nothing, isEndless = True, isRound = False }
    , { id = "29", description = "29mm endless", width = 306, height = Nothing, isEndless = True, isRound = False }
    , { id = "38", description = "38mm endless", width = 413, height = Nothing, isEndless = True, isRound = False }
    , { id = "50", description = "50mm endless", width = 554, height = Nothing, isEndless = True, isRound = False }
    , { id = "54", description = "54mm endless", width = 590, height = Nothing, isEndless = True, isRound = False }
    , { id = "62", description = "62mm endless", width = 696, height = Nothing, isEndless = True, isRound = False }
    , { id = "62red", description = "62mm endless (red)", width = 696, height = Nothing, isEndless = True, isRound = False }
    , { id = "102", description = "102mm endless", width = 1164, height = Nothing, isEndless = True, isRound = False }

    -- Die-cut rectangular labels
    , { id = "17x54", description = "17mm x 54mm", width = 165, height = Just 566, isEndless = False, isRound = False }
    , { id = "17x87", description = "17mm x 87mm", width = 165, height = Just 956, isEndless = False, isRound = False }
    , { id = "23x23", description = "23mm x 23mm", width = 202, height = Just 202, isEndless = False, isRound = False }
    , { id = "29x42", description = "29mm x 42mm", width = 306, height = Just 425, isEndless = False, isRound = False }
    , { id = "29x90", description = "29mm x 90mm", width = 306, height = Just 991, isEndless = False, isRound = False }
    , { id = "39x48", description = "39mm x 48mm", width = 425, height = Just 495, isEndless = False, isRound = False }
    , { id = "39x90", description = "38mm x 90mm", width = 413, height = Just 991, isEndless = False, isRound = False }
    , { id = "52x29", description = "52mm x 29mm", width = 578, height = Just 271, isEndless = False, isRound = False }
    , { id = "62x29", description = "62mm x 29mm", width = 696, height = Just 271, isEndless = False, isRound = False }
    , { id = "62x100", description = "62mm x 100mm", width = 696, height = Just 1109, isEndless = False, isRound = False }
    , { id = "102x51", description = "102mm x 51mm", width = 1164, height = Just 526, isEndless = False, isRound = False }
    , { id = "102x152", description = "102mm x 153mm", width = 1164, height = Just 1660, isEndless = False, isRound = False }

    -- Round die-cut labels
    , { id = "d12", description = "12mm round", width = 94, height = Just 94, isEndless = False, isRound = True }
    , { id = "d24", description = "24mm round", width = 236, height = Just 236, isEndless = False, isRound = True }
    , { id = "d58", description = "58mm round", width = 618, height = Just 618, isEndless = False, isRound = True }
    ]


{-| Check if a label type is endless (variable height).
-}
isEndlessLabel : String -> Bool
isEndlessLabel labelTypeId =
    List.any (\spec -> spec.id == labelTypeId && spec.isEndless) labelTypes


{-| Calculate silver ratio height for endless labels.
-}
silverRatioHeight : Int -> Int
silverRatioHeight width =
    round (toFloat width * 2.414)


type alias Model =
    { presets : List LabelPreset
    , form : LabelPresetForm
    , appHost : String
    , loading : Bool
    , deleteConfirm : Maybe String
    , sampleName : String
    , sampleIngredients : String
    , computedLabelData : Maybe Label.ComputedLabelData
    , isPrinting : Bool
    , previewZoom : Float
    , previewPanX : Float
    , previewPanY : Float
    , previewContainerHeight : Int
    }


type Msg
    = GotPresets (Result Http.Error (List LabelPreset))
    | FormNameChanged String
    | FormLabelTypeChanged String
    | FormWidthChanged String
    | FormHeightChanged String
    | FormQrSizeChanged String
    | FormPaddingChanged String
    | FormTitleFontSizeChanged String
    | FormDateFontSizeChanged String
    | FormSmallFontSizeChanged String
    | FormFontFamilyChanged String
    | FormShowTitleChanged Bool
    | FormShowIngredientsChanged Bool
    | FormShowExpiryDateChanged Bool
    | FormShowBestBeforeChanged Bool
    | FormShowQrChanged Bool
    | FormShowBrandingChanged Bool
    | FormVerticalSpacingChanged String
    | FormShowSeparatorChanged Bool
    | FormSeparatorThicknessChanged String
    | FormSeparatorColorChanged String
    | FormCornerRadiusChanged String
    | FormTitleMinFontSizeChanged String
    | FormIngredientsMaxCharsChanged String
    | FormRotateChanged Bool
    | SampleNameChanged String
    | SampleIngredientsChanged String
    | SavePreset
    | EditPreset LabelPreset
    | CancelEdit
    | DeletePreset String
    | ConfirmDelete String
    | CancelDelete
    | PresetSaved (Result Http.Error ())
    | PresetDeleted (Result Http.Error ())
    | GotTextMeasureResult Ports.TextMeasureResult
    | PrintLabel
    | GotPngResult Ports.PngResult
    | PrintResult (Result Http.Error ())
    | ZoomChanged Float
    | ZoomIn
    | ZoomOut
    | PinchZoomUpdated { zoom : Float, panX : Float, panY : Float }
    | PreviewContainerHeightChanged String
    | ResetZoomPan


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshPresets
    | RequestTextMeasure Ports.TextMeasureRequest
    | RequestSvgToPng Ports.SvgToPngRequest
    | RequestInitPinchZoom { elementId : String, initialZoom : Float }
    | RequestSetPinchZoom { elementId : String, zoom : Float, panX : Float, panY : Float }


init : String -> List LabelPreset -> ( Model, Cmd Msg, OutMsg )
init appHost presets =
    let
        model =
            { presets = presets
            , form = emptyLabelPresetForm
            , appHost = appHost
            , loading = False
            , deleteConfirm = Nothing
            , sampleName = "Pollo con arroz"
            , sampleIngredients = "pollo, arroz, verduras, cebolla, ajo"
            , computedLabelData = Nothing
            , isPrinting = False
            , previewZoom = 1.0
            , previewPanX = 0
            , previewPanY = 0
            , previewContainerHeight = 400
            }
    in
    ( model
    , Cmd.none
    , requestMeasurement model
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotPresets result ->
            case result of
                Ok presets ->
                    ( { model | presets = presets, loading = False }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al cargar presets", notificationType = Error }
                    )

        FormNameChanged name ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | name = name } }, Cmd.none, NoOp )

        FormLabelTypeChanged labelTypeId ->
            let
                maybeSpec =
                    List.filter (\s -> s.id == labelTypeId) labelTypes
                        |> List.head

                form =
                    model.form

                newForm =
                    case maybeSpec of
                        Just spec ->
                            let
                                newHeight =
                                    case spec.height of
                                        Just h ->
                                            String.fromInt h

                                        Nothing ->
                                            -- Endless: use silver ratio
                                            String.fromInt (silverRatioHeight spec.width)

                                newCornerRadius =
                                    if spec.isRound then
                                        String.fromInt (spec.width // 2)

                                    else if not spec.isEndless then
                                        -- Die-cut: 5% of min dimension
                                        case spec.height of
                                            Just h ->
                                                String.fromInt (round (toFloat (min spec.width h) * 0.05))

                                            Nothing ->
                                                "0"

                                    else
                                        "0"

                                newRotate =
                                    case spec.height of
                                        Just h ->
                                            h > spec.width

                                        Nothing ->
                                            -- Endless labels are portrait
                                            True
                            in
                            { form
                                | labelType = spec.id
                                , width = String.fromInt spec.width
                                , height = newHeight
                                , cornerRadius = newCornerRadius
                                , rotate = newRotate
                            }

                        Nothing ->
                            form

                newModel =
                    { model | form = newForm }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormWidthChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | width = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormHeightChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | height = val } }, Cmd.none, NoOp )

        FormQrSizeChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | qrSize = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormPaddingChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | padding = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormTitleFontSizeChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | titleFontSize = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormDateFontSizeChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | dateFontSize = val } }, Cmd.none, NoOp )

        FormSmallFontSizeChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | smallFontSize = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormFontFamilyChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | fontFamily = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormShowTitleChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showTitle = val } }, Cmd.none, NoOp )

        FormShowIngredientsChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showIngredients = val } }, Cmd.none, NoOp )

        FormShowExpiryDateChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showExpiryDate = val } }, Cmd.none, NoOp )

        FormShowBestBeforeChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showBestBefore = val } }, Cmd.none, NoOp )

        FormShowQrChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | showQr = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormShowBrandingChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showBranding = val } }, Cmd.none, NoOp )

        FormVerticalSpacingChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | verticalSpacing = val } }, Cmd.none, NoOp )

        FormShowSeparatorChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | showSeparator = val } }, Cmd.none, NoOp )

        FormSeparatorThicknessChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | separatorThickness = val } }, Cmd.none, NoOp )

        FormSeparatorColorChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | separatorColor = val } }, Cmd.none, NoOp )

        FormCornerRadiusChanged val ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | cornerRadius = val } }, Cmd.none, NoOp )

        FormTitleMinFontSizeChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | titleMinFontSize = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormIngredientsMaxCharsChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | ingredientsMaxChars = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        FormRotateChanged val ->
            let
                form =
                    model.form

                newModel =
                    { model | form = { form | rotate = val } }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        SampleNameChanged val ->
            let
                newModel =
                    { model | sampleName = val }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        SampleIngredientsChanged val ->
            let
                newModel =
                    { model | sampleIngredients = val }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

        GotTextMeasureResult result ->
            ( { model
                | computedLabelData =
                    Just
                        { titleFontSize = result.titleFittedFontSize
                        , titleLines = result.titleLines
                        , ingredientLines = result.ingredientLines
                        }
              }
            , Cmd.none
            , NoOp
            )

        PrintLabel ->
            let
                settings =
                    formToSettings model.form
            in
            ( { model | isPrinting = True }
            , Cmd.none
            , RequestSvgToPng
                { svgId = "label-svg-sample-preview"
                , requestId = "preview"
                , width = settings.width
                , height = settings.height
                , rotate = settings.rotate
                }
            )

        GotPngResult result ->
            case result.dataUrl of
                Just dataUrl ->
                    let
                        -- Strip the data URL prefix to get base64
                        base64Data =
                            String.replace "data:image/png;base64," "" dataUrl

                        labelType =
                            model.form.labelType
                    in
                    ( model
                    , Api.printLabelPng base64Data labelType PrintResult
                    , NoOp
                    )

                Nothing ->
                    ( { model | isPrinting = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al convertir la etiqueta", notificationType = Error }
                    )

        PrintResult result ->
            case result of
                Ok _ ->
                    ( { model | isPrinting = False }
                    , Cmd.none
                    , ShowNotification { message = "Etiqueta enviada a imprimir", notificationType = Success }
                    )

                Err _ ->
                    ( { model | isPrinting = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al imprimir la etiqueta", notificationType = Error }
                    )

        SavePreset ->
            if String.isEmpty model.form.name then
                ( model
                , Cmd.none
                , ShowNotification { message = "El nombre es requerido", notificationType = Error }
                )

            else
                ( { model | loading = True }
                , Api.saveLabelPreset model.form PresetSaved
                , NoOp
                )

        EditPreset preset ->
            let
                newModel =
                    { model
                        | form =
                            { name = preset.name
                            , labelType = preset.labelType
                            , width = String.fromInt preset.width
                            , height = String.fromInt preset.height
                            , qrSize = String.fromInt preset.qrSize
                            , padding = String.fromInt preset.padding
                            , titleFontSize = String.fromInt preset.titleFontSize
                            , dateFontSize = String.fromInt preset.dateFontSize
                            , smallFontSize = String.fromInt preset.smallFontSize
                            , fontFamily = preset.fontFamily
                            , showTitle = preset.showTitle
                            , showIngredients = preset.showIngredients
                            , showExpiryDate = preset.showExpiryDate
                            , showBestBefore = preset.showBestBefore
                            , showQr = preset.showQr
                            , showBranding = preset.showBranding
                            , verticalSpacing = String.fromInt preset.verticalSpacing
                            , showSeparator = preset.showSeparator
                            , separatorThickness = String.fromInt preset.separatorThickness
                            , separatorColor = preset.separatorColor
                            , cornerRadius = String.fromInt preset.cornerRadius
                            , titleMinFontSize = String.fromInt preset.titleMinFontSize
                            , ingredientsMaxChars = String.fromInt preset.ingredientsMaxChars
                            , rotate = preset.rotate
                            , editing = Just preset.name
                            }
                    }
            in
            ( newModel
            , Cmd.none
            , requestMeasurement newModel
            )

        CancelEdit ->
            ( { model | form = emptyLabelPresetForm }, Cmd.none, NoOp )

        DeletePreset name ->
            ( { model | deleteConfirm = Just name }, Cmd.none, NoOp )

        ConfirmDelete name ->
            ( { model | deleteConfirm = Nothing, loading = True }
            , Api.deleteLabelPreset name PresetDeleted
            , NoOp
            )

        CancelDelete ->
            ( { model | deleteConfirm = Nothing }, Cmd.none, NoOp )

        PresetSaved result ->
            case result of
                Ok _ ->
                    ( { model | loading = False, form = emptyLabelPresetForm }
                    , Api.fetchLabelPresets GotPresets
                    , ShowNotification { message = "Preset guardado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al guardar preset", notificationType = Error }
                    )

        PresetDeleted result ->
            case result of
                Ok _ ->
                    ( { model | loading = False }
                    , Api.fetchLabelPresets GotPresets
                    , ShowNotification { message = "Preset eliminado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Error al eliminar preset", notificationType = Error }
                    )

        ZoomChanged newZoom ->
            let
                clampedZoom =
                    clamp 0.25 3.0 newZoom
            in
            ( { model | previewZoom = clampedZoom }
            , Cmd.none
            , RequestSetPinchZoom
                { elementId = "label-preview-container"
                , zoom = clampedZoom
                , panX = model.previewPanX
                , panY = model.previewPanY
                }
            )

        ZoomIn ->
            let
                newZoom =
                    clamp 0.25 3.0 (model.previewZoom + 0.1)
            in
            ( { model | previewZoom = newZoom }
            , Cmd.none
            , RequestSetPinchZoom
                { elementId = "label-preview-container"
                , zoom = newZoom
                , panX = model.previewPanX
                , panY = model.previewPanY
                }
            )

        ZoomOut ->
            let
                newZoom =
                    clamp 0.25 3.0 (model.previewZoom - 0.1)
            in
            ( { model | previewZoom = newZoom }
            , Cmd.none
            , RequestSetPinchZoom
                { elementId = "label-preview-container"
                , zoom = newZoom
                , panX = model.previewPanX
                , panY = model.previewPanY
                }
            )

        PinchZoomUpdated data ->
            ( { model
                | previewZoom = clamp 0.25 3.0 data.zoom
                , previewPanX = data.panX
                , previewPanY = data.panY
              }
            , Cmd.none
            , NoOp
            )

        PreviewContainerHeightChanged heightStr ->
            case String.toInt heightStr of
                Just h ->
                    ( { model | previewContainerHeight = clamp 200 800 h }
                    , Cmd.none
                    , NoOp
                    )

                Nothing ->
                    ( model, Cmd.none, NoOp )

        ResetZoomPan ->
            ( { model | previewZoom = 1.0, previewPanX = 0, previewPanY = 0 }
            , Cmd.none
            , RequestSetPinchZoom
                { elementId = "label-preview-container"
                , zoom = 1.0
                , panX = 0
                , panY = 0
                }
            )


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
            [ text (String.fromInt (Label.displayWidth settings) ++ " x " ++ String.fromInt (Label.displayHeight settings) ++ " px (pantalla)")
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
viewHiddenLabel : Model -> Label.LabelSettings -> Label.LabelData -> Label.ComputedLabelData -> Html Msg
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


{-| Build a text measure request from current model state.
-}
requestMeasurement : Model -> OutMsg
requestMeasurement model =
    let
        settings =
            formToSettings model.form
    in
    RequestTextMeasure
        { requestId = "preview"
        , titleText = model.sampleName
        , ingredientsText = model.sampleIngredients
        , fontFamily = settings.fontFamily
        , titleFontSize = settings.titleFontSize
        , titleMinFontSize = settings.titleMinFontSize
        , smallFontSize = settings.smallFontSize
        , maxWidth = Label.textMaxWidth settings
        , ingredientsMaxChars = settings.ingredientsMaxChars
        }


{-| Convert form values to LabelSettings for preview.
-}
formToSettings : LabelPresetForm -> Label.LabelSettings
formToSettings form =
    { name = form.name
    , labelType = form.labelType
    , width = Maybe.withDefault 696 (String.toInt form.width)
    , height = Maybe.withDefault 300 (String.toInt form.height)
    , qrSize = Maybe.withDefault 200 (String.toInt form.qrSize)
    , padding = Maybe.withDefault 20 (String.toInt form.padding)
    , titleFontSize = Maybe.withDefault 48 (String.toInt form.titleFontSize)
    , dateFontSize = Maybe.withDefault 32 (String.toInt form.dateFontSize)
    , smallFontSize = Maybe.withDefault 18 (String.toInt form.smallFontSize)
    , fontFamily = form.fontFamily
    , showTitle = form.showTitle
    , showIngredients = form.showIngredients
    , showExpiryDate = form.showExpiryDate
    , showBestBefore = form.showBestBefore
    , showQr = form.showQr
    , showBranding = form.showBranding
    , verticalSpacing = Maybe.withDefault 10 (String.toInt form.verticalSpacing)
    , showSeparator = form.showSeparator
    , separatorThickness = Maybe.withDefault 1 (String.toInt form.separatorThickness)
    , separatorColor = form.separatorColor
    , cornerRadius = Maybe.withDefault 0 (String.toInt form.cornerRadius)
    , titleMinFontSize = Maybe.withDefault 24 (String.toInt form.titleMinFontSize)
    , ingredientsMaxChars = Maybe.withDefault 45 (String.toInt form.ingredientsMaxChars)
    , rotate = form.rotate
    }
