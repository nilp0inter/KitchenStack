module Page.LabelDesigner exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

{-| Label Designer page for managing label presets with live preview.
-}

import Api
import Data.LabelPreset
import Data.LabelTypes exposing (LabelTypeSpec, isEndlessLabel, labelTypes, silverRatioHeight)
import Html exposing (Html)
import Http
import Label
import Page.LabelDesigner.Types as LD exposing (..)
import Page.LabelDesigner.View as View
import Ports
import Types exposing (..)


-- Re-expose types for Main.elm
type alias Model = LD.Model
type alias Msg = LD.Msg
type alias OutMsg = LD.OutMsg


init : String -> List LabelPreset -> ( Model, Cmd Msg, OutMsg )
init appHost presets =
    let
        model =
            { presets = presets
            , form = Data.LabelPreset.empty
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
            , viewMode = ListMode
            , selectedPreset = Nothing
            , selectedPresetComputed = Nothing
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
                    , ShowNotification { id = 0, message = "Error al cargar presets", notificationType = Error }
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
            let
                computedData =
                    { titleFontSize = result.titleFittedFontSize
                    , titleLines = result.titleLines
                    , ingredientLines = result.ingredientLines
                    }
            in
            if String.startsWith "selected-" result.requestId then
                -- This is a selected preset preview measurement
                ( { model | selectedPresetComputed = Just computedData }
                , Cmd.none
                , NoOp
                )

            else
                -- This is a form preview measurement
                ( { model | computedLabelData = Just computedData }
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
                    , ShowNotification { id = 0, message = "Error al convertir la etiqueta", notificationType = Error }
                    )

        PrintResult result ->
            case result of
                Ok _ ->
                    ( { model | isPrinting = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Etiqueta enviada a imprimir", notificationType = Success }
                    )

                Err _ ->
                    ( { model | isPrinting = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al imprimir la etiqueta", notificationType = Error }
                    )

        SavePreset ->
            if String.isEmpty model.form.name then
                ( model
                , Cmd.none
                , ShowNotification { id = 0, message = "El nombre es requerido", notificationType = Error }
                )

            else
                ( { model | loading = True }
                , Api.saveLabelPreset model.form PresetSaved
                , NoOp
                )

        StartCreate ->
            let
                newModel =
                    { model
                        | form = Data.LabelPreset.empty
                        , viewMode = FormMode
                        , selectedPreset = Nothing
                        , selectedPresetComputed = Nothing
                    }
            in
            ( newModel
            , Cmd.none
            , requestMeasurement newModel
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
                        , viewMode = FormMode
                        , selectedPreset = Nothing
                        , selectedPresetComputed = Nothing
                    }
            in
            ( newModel
            , Cmd.none
            , requestMeasurement newModel
            )

        CancelEdit ->
            let
                newModel =
                    { model
                        | form = Data.LabelPreset.empty
                        , viewMode = ListMode
                    }
            in
            ( newModel, Cmd.none, requestMeasurement newModel )

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
                    ( { model | loading = False, form = Data.LabelPreset.empty, viewMode = ListMode }
                    , Api.fetchLabelPresets GotPresets
                    , RefreshPresetsWithNotification { id = 0, message = "Preset guardado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al guardar preset", notificationType = Error }
                    )

        PresetDeleted result ->
            case result of
                Ok _ ->
                    ( { model | loading = False }
                    , Api.fetchLabelPresets GotPresets
                    , RefreshPresetsWithNotification { id = 0, message = "Preset eliminado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al eliminar preset", notificationType = Error }
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

        ReceivedLabelPresets labelPresets ->
            ( { model | presets = labelPresets }, Cmd.none, NoOp )

        SelectPreset presetName ->
            -- Find the preset and request measurement
            case List.filter (\p -> p.name == presetName) model.presets |> List.head of
                Just preset ->
                    ( { model | selectedPreset = Just presetName, selectedPresetComputed = Nothing }
                    , Cmd.none
                    , requestMeasurementForPreset model preset
                    )

                Nothing ->
                    ( model, Cmd.none, NoOp )


view : Model -> Html Msg
view =
    View.view
