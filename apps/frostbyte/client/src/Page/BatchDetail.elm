module Page.BatchDetail exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

import Api
import Data.Label
import Data.LabelPreset
import Dict exposing (Dict)
import Html exposing (Html)
import Http
import Label
import Page.BatchDetail.Types as BD exposing (..)
import Page.BatchDetail.View as View
import Ports
import Types exposing (..)


type alias Model = BD.Model
type alias Msg = BD.Msg
type alias OutMsg = BD.OutMsg


init : String -> String -> List BatchSummary -> List LabelPreset -> ( Model, Cmd Msg )
init batchId appHost batches labelPresets =
    let
        maybeBatch =
            List.filter (\b -> b.batchId == batchId) batches
                |> List.head

        -- Use batch's stored preset if available, otherwise fall back to first preset
        batchPreset =
            maybeBatch
                |> Maybe.andThen .labelPreset
                |> Maybe.andThen
                    (\name ->
                        List.filter (\p -> p.name == name) labelPresets
                            |> List.head
                    )

        defaultPreset =
            case batchPreset of
                Just preset ->
                    Just preset

                Nothing ->
                    List.head labelPresets
    in
    ( { batchId = batchId
      , batch = maybeBatch
      , portions = []
      , labelPresets = labelPresets
      , selectedPreset = defaultPreset
      , appHost = appHost
      , loading = True
      , error = Nothing
      , previewModal = Nothing
      , pendingPreview = Nothing
      , printingProgress = Nothing
      , pendingPrintData = []
      , pendingPngRequests = []
      , pendingMeasurements = []
      , computedLabelData = Dict.empty
      }
    , Cmd.batch
        [ Api.fetchBatchPortions batchId GotBatchPortions
        , if maybeBatch == Nothing then
            Api.fetchBatchById batchId GotBatches
          else
            Cmd.none
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotBatches result ->
            case result of
                Ok batches ->
                    let
                        maybeBatch =
                            List.filter (\b -> b.batchId == model.batchId) batches
                                |> List.head

                        -- Recalculate selectedPreset based on fresh batch data
                        -- If batch has a stored preset, use it; otherwise keep current selection
                        updatedSelectedPreset =
                            case maybeBatch |> Maybe.andThen .labelPreset of
                                Just presetName ->
                                    List.filter (\p -> p.name == presetName) model.labelPresets
                                        |> List.head
                                        |> (\found ->
                                                case found of
                                                    Just preset ->
                                                        Just preset

                                                    Nothing ->
                                                        model.selectedPreset
                                           )

                                Nothing ->
                                    model.selectedPreset
                    in
                    ( { model | batch = maybeBatch, selectedPreset = updatedSelectedPreset }, Cmd.none, NoOp )

                Err _ ->
                    ( model, Cmd.none, ShowNotification { id = 0, message = "Failed to load batch", notificationType = Error } )

        GotBatchPortions result ->
            case result of
                Ok portions ->
                    ( { model | portions = portions, loading = False }, Cmd.none, NoOp )

                Err _ ->
                    ( { model | error = Just "Failed to load batch portions", loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Failed to load batch portions", notificationType = Error }
                    )

        ReprintPortion portion ->
            case ( model.batch, model.selectedPreset ) of
                ( Just batch, Just preset ) ->
                    let
                        printData =
                            { portionId = portion.portionId
                            , name = batch.name
                            , ingredients = batch.ingredients
                            , containerId = batch.containerId
                            , expiryDate = portion.expiryDate
                            , bestBeforeDate = batch.bestBeforeDate
                            }

                        labelSettings =
                            Data.LabelPreset.presetToSettings preset

                        measureRequest =
                            { requestId = printData.portionId
                            , titleText = printData.name
                            , ingredientsText = printData.ingredients
                            , fontFamily = preset.fontFamily
                            , titleFontSize = preset.titleFontSize
                            , titleMinFontSize = preset.titleMinFontSize
                            , smallFontSize = preset.smallFontSize
                            , maxWidth = Data.Label.textMaxWidth labelSettings
                            , ingredientsMaxChars = preset.ingredientsMaxChars
                            }
                    in
                    ( { model
                        | printingProgress = Just { total = 1, completed = 0, failed = 0 }
                        , pendingPrintData = [ printData ]
                        , pendingPngRequests = [ printData.portionId ]
                        , pendingMeasurements = [ printData.portionId ]
                        , computedLabelData = Dict.empty
                      }
                    , Cmd.none
                    , RequestTextMeasure measureRequest
                    )

                ( _, Nothing ) ->
                    ( model, Cmd.none, ShowNotification { id = 0, message = "No hay preajuste de etiqueta seleccionado", notificationType = Error } )

                ( Nothing, _ ) ->
                    ( model, Cmd.none, NoOp )

        ReprintAllFrozen ->
            case ( model.batch, model.selectedPreset ) of
                ( Just batch, Just preset ) ->
                    let
                        frozenPortions =
                            List.filter (\p -> p.status == "FROZEN") model.portions

                        quantity =
                            List.length frozenPortions

                        printData =
                            List.map
                                (\portion ->
                                    { portionId = portion.portionId
                                    , name = batch.name
                                    , ingredients = batch.ingredients
                                    , containerId = batch.containerId
                                    , expiryDate = portion.expiryDate
                                    , bestBeforeDate = batch.bestBeforeDate
                                    }
                                )
                                frozenPortions

                        labelSettings =
                            Data.LabelPreset.presetToSettings preset

                        -- Start text measurement for the first label
                        firstMeasureRequest =
                            case List.head printData of
                                Just firstData ->
                                    Just
                                        { requestId = firstData.portionId
                                        , titleText = firstData.name
                                        , ingredientsText = firstData.ingredients
                                        , fontFamily = preset.fontFamily
                                        , titleFontSize = preset.titleFontSize
                                        , titleMinFontSize = preset.titleMinFontSize
                                        , smallFontSize = preset.smallFontSize
                                        , maxWidth = Data.Label.textMaxWidth labelSettings
                                        , ingredientsMaxChars = preset.ingredientsMaxChars
                                        }

                                Nothing ->
                                    Nothing
                    in
                    if quantity > 0 then
                        ( { model
                            | printingProgress = Just { total = quantity, completed = 0, failed = 0 }
                            , pendingPrintData = printData
                            , pendingPngRequests = List.map .portionId printData
                            , pendingMeasurements = List.map .portionId printData
                            , computedLabelData = Dict.empty
                          }
                        , Cmd.none
                        , case firstMeasureRequest of
                            Just req ->
                                RequestTextMeasure req

                            Nothing ->
                                NoOp
                        )

                    else
                        ( model
                        , Cmd.none
                        , ShowNotification { id = 0, message = "No hay porciones congeladas para imprimir", notificationType = Info }
                        )

                ( _, Nothing ) ->
                    ( model, Cmd.none, ShowNotification { id = 0, message = "No hay preajuste de etiqueta seleccionado", notificationType = Error } )

                ( Nothing, _ ) ->
                    ( model, Cmd.none, NoOp )

        PrintResult portionId result ->
            let
                updateProgress progress =
                    case result of
                        Ok _ ->
                            { progress | completed = progress.completed + 1 }

                        Err _ ->
                            { progress | failed = progress.failed + 1 }

                newProgress =
                    Maybe.map updateProgress model.printingProgress

                allDone =
                    case newProgress of
                        Just p ->
                            p.completed + p.failed >= p.total

                        Nothing ->
                            True

                outMsg =
                    if allDone then
                        case newProgress of
                            Just p ->
                                if p.failed > 0 then
                                    ShowNotification { id = 0, message = String.fromInt p.completed ++ " etiquetas impresas, " ++ String.fromInt p.failed ++ " fallidas", notificationType = Error }

                                else
                                    ShowNotification { id = 0, message = String.fromInt p.completed ++ " etiquetas impresas correctamente!", notificationType = Success }

                            Nothing ->
                                NoOp

                    else
                        NoOp

                finalProgress =
                    if allDone then
                        Nothing

                    else
                        newProgress

                ( recordCmd, updatedPortions ) =
                    case result of
                        Ok _ ->
                            ( Api.recordPortionPrinted portionId RecordPrintedResult
                            , List.map
                                (\p ->
                                    if p.portionId == portionId then
                                        { p | printCount = p.printCount + 1 }

                                    else
                                        p
                                )
                                model.portions
                            )

                        Err _ ->
                            ( Cmd.none, model.portions )
            in
            ( { model | printingProgress = finalProgress, portions = updatedPortions }, recordCmd, outMsg )

        RecordPrintedResult _ ->
            ( model, Cmd.none, NoOp )

        SelectPreset presetName ->
            let
                maybePreset =
                    List.filter (\p -> p.name == presetName) model.labelPresets
                        |> List.head
            in
            ( { model | selectedPreset = maybePreset }, Cmd.none, NoOp )

        GotPngResult result ->
            case result.dataUrl of
                Just dataUrl ->
                    let
                        -- Strip the data:image/png;base64, prefix
                        base64Data =
                            String.replace "data:image/png;base64," "" dataUrl

                        -- Get label type from selected preset
                        labelType =
                            model.selectedPreset
                                |> Maybe.map .labelType
                                |> Maybe.withDefault "62"

                        -- Remove this request from pending
                        remainingRequests =
                            List.filter (\id -> id /= result.requestId) model.pendingPngRequests

                        -- Find next pending print data to convert
                        nextRequest =
                            case ( List.head remainingRequests, model.selectedPreset ) of
                                ( Just nextId, Just preset ) ->
                                    Just
                                        { svgId = Label.labelSvgId nextId
                                        , requestId = nextId
                                        , width = preset.width
                                        , height = preset.height
                                        , rotate = preset.rotate
                                        }

                                _ ->
                                    Nothing
                    in
                    ( { model | pendingPngRequests = remainingRequests }
                    , Api.printLabelPng base64Data labelType (PrintResult result.requestId)
                    , case nextRequest of
                        Just req ->
                            RequestSvgToPng req

                        Nothing ->
                            NoOp
                    )

                Nothing ->
                    -- PNG conversion failed
                    let
                        updateProgress progress =
                            { progress | failed = progress.failed + 1 }

                        newProgress =
                            Maybe.map updateProgress model.printingProgress

                        remainingRequests =
                            List.filter (\id -> id /= result.requestId) model.pendingPngRequests

                        allDone =
                            case newProgress of
                                Just p ->
                                    p.completed + p.failed >= p.total

                                Nothing ->
                                    True

                        finalProgress =
                            if allDone then
                                Nothing

                            else
                                newProgress

                        -- Try next conversion even if this one failed
                        nextRequest =
                            case ( List.head remainingRequests, model.selectedPreset ) of
                                ( Just nextId, Just preset ) ->
                                    Just
                                        { svgId = Label.labelSvgId nextId
                                        , requestId = nextId
                                        , width = preset.width
                                        , height = preset.height
                                        , rotate = preset.rotate
                                        }

                                _ ->
                                    Nothing

                        outMsg =
                            if allDone then
                                case newProgress of
                                    Just p ->
                                        if p.failed > 0 then
                                            ShowNotification { id = 0, message = String.fromInt p.completed ++ " etiquetas impresas, " ++ String.fromInt p.failed ++ " fallidas", notificationType = Error }

                                        else
                                            ShowNotification { id = 0, message = String.fromInt p.completed ++ " etiquetas impresas correctamente!", notificationType = Success }

                                    Nothing ->
                                        NoOp

                            else
                                NoOp
                    in
                    ( { model
                        | pendingPngRequests = remainingRequests
                        , printingProgress = finalProgress
                      }
                    , Cmd.none
                    , case nextRequest of
                        Just req ->
                            RequestSvgToPng req

                        Nothing ->
                            outMsg
                    )

        GotTextMeasureResult result ->
            let
                -- Store computed data for this label
                newComputedData =
                    Dict.insert result.requestId
                        { titleFontSize = result.titleFittedFontSize
                        , titleLines = result.titleLines
                        , ingredientLines = result.ingredientLines
                        }
                        model.computedLabelData

                -- Check if this was for a preview request
                ( newPreviewModal, newPendingPreview ) =
                    case model.pendingPreview of
                        Just pending ->
                            if pending.portionId == result.requestId then
                                ( Just pending, Nothing )

                            else
                                ( model.previewModal, model.pendingPreview )

                        Nothing ->
                            ( model.previewModal, Nothing )

                -- Remove from pending measurements
                remainingMeasurements =
                    List.filter (\id -> id /= result.requestId) model.pendingMeasurements

                -- Check if all measurements are done
                allMeasured =
                    List.isEmpty remainingMeasurements
            in
            if allMeasured then
                -- All measurements done, start SVG→PNG conversion (if printing)
                let
                    firstRequest =
                        case ( List.head model.pendingPngRequests, model.selectedPreset ) of
                            ( Just firstId, Just preset ) ->
                                Just
                                    { svgId = Label.labelSvgId firstId
                                    , requestId = firstId
                                    , width = preset.width
                                    , height = preset.height
                                    , rotate = preset.rotate
                                    }

                            _ ->
                                Nothing
                in
                ( { model
                    | computedLabelData = newComputedData
                    , pendingMeasurements = []
                    , previewModal = newPreviewModal
                    , pendingPreview = newPendingPreview
                  }
                , Cmd.none
                , case firstRequest of
                    Just req ->
                        RequestSvgToPng req

                    Nothing ->
                        NoOp
                )

            else
                -- Request next measurement
                let
                    nextMeasureRequest =
                        case ( List.head remainingMeasurements, model.selectedPreset ) of
                            ( Just nextId, Just preset ) ->
                                let
                                    maybeData =
                                        List.filter (\d -> d.portionId == nextId) model.pendingPrintData
                                            |> List.head

                                    labelSettings =
                                        Data.LabelPreset.presetToSettings preset
                                in
                                case maybeData of
                                    Just nextData ->
                                        Just
                                            { requestId = nextId
                                            , titleText = nextData.name
                                            , ingredientsText = nextData.ingredients
                                            , fontFamily = preset.fontFamily
                                            , titleFontSize = preset.titleFontSize
                                            , titleMinFontSize = preset.titleMinFontSize
                                            , smallFontSize = preset.smallFontSize
                                            , maxWidth = Data.Label.textMaxWidth labelSettings
                                            , ingredientsMaxChars = preset.ingredientsMaxChars
                                            }

                                    Nothing ->
                                        Nothing

                            _ ->
                                Nothing
                in
                ( { model
                    | computedLabelData = newComputedData
                    , pendingMeasurements = remainingMeasurements
                    , previewModal = newPreviewModal
                    , pendingPreview = newPendingPreview
                  }
                , Cmd.none
                , case nextMeasureRequest of
                    Just req ->
                        RequestTextMeasure req

                    Nothing ->
                        NoOp
                )

        OpenPreviewModal portionData ->
            case ( Dict.get portionData.portionId model.computedLabelData, model.selectedPreset ) of
                ( Just _, _ ) ->
                    -- Already have computed data, show modal immediately
                    ( { model | previewModal = Just portionData }, Cmd.none, NoOp )

                ( Nothing, Just preset ) ->
                    -- Need measurement first
                    let
                        labelSettings =
                            Data.LabelPreset.presetToSettings preset

                        measureRequest =
                            { requestId = portionData.portionId
                            , titleText = portionData.name
                            , ingredientsText = portionData.ingredients
                            , fontFamily = preset.fontFamily
                            , titleFontSize = preset.titleFontSize
                            , titleMinFontSize = preset.titleMinFontSize
                            , smallFontSize = preset.smallFontSize
                            , maxWidth = Data.Label.textMaxWidth labelSettings
                            , ingredientsMaxChars = preset.ingredientsMaxChars
                            }
                    in
                    ( { model | pendingPreview = Just portionData }
                    , Cmd.none
                    , RequestTextMeasure measureRequest
                    )

                ( Nothing, Nothing ) ->
                    -- No preset, fallback to show modal without text fitting
                    ( { model | previewModal = Just portionData }, Cmd.none, NoOp )

        ClosePreviewModal ->
            ( { model | previewModal = Nothing }, Cmd.none, NoOp )

        ReturnToFreezer portionId ->
            ( model
            , Api.returnPortionToFreezer portionId ReturnToFreezerResult
            , NoOp
            )

        ReturnToFreezerResult result ->
            case result of
                Ok _ ->
                    ( model
                    , Api.fetchBatchPortions model.batchId GotBatchPortions
                    , ShowNotification { id = 0, message = "Porción devuelta al congelador", notificationType = Success }
                    )

                Err _ ->
                    ( model
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al devolver porción al congelador", notificationType = Error }
                    )

        DiscardPortion portionId ->
            ( model
            , Api.discardPortion portionId DiscardPortionResult
            , NoOp
            )

        DiscardPortionResult result ->
            case result of
                Ok _ ->
                    ( model
                    , Cmd.batch
                        [ Api.fetchBatchPortions model.batchId GotBatchPortions
                        , Api.fetchBatches GotBatches
                        ]
                    , ShowNotification { id = 0, message = "Porción descartada", notificationType = Success }
                    )

                Err _ ->
                    ( model
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al descartar porción", notificationType = Error }
                    )

        ReceivedBatches batches ->
            let
                maybeBatch =
                    List.filter (\b -> b.batchId == model.batchId) batches
                        |> List.head

                -- Recalculate selectedPreset based on fresh batch data
                updatedSelectedPreset =
                    case maybeBatch |> Maybe.andThen .labelPreset of
                        Just presetName ->
                            List.filter (\p -> p.name == presetName) model.labelPresets
                                |> List.head
                                |> (\found ->
                                        case found of
                                            Just preset ->
                                                Just preset

                                            Nothing ->
                                                model.selectedPreset
                                   )

                        Nothing ->
                            model.selectedPreset
            in
            ( { model | batch = maybeBatch, selectedPreset = updatedSelectedPreset }, Cmd.none, NoOp )

        ReceivedLabelPresets labelPresets ->
            let
                -- Preserve the selected preset if it still exists
                updatedSelectedPreset =
                    model.selectedPreset
                        |> Maybe.andThen
                            (\current ->
                                List.filter (\p -> p.name == current.name) labelPresets
                                    |> List.head
                            )
            in
            ( { model | labelPresets = labelPresets, selectedPreset = updatedSelectedPreset }
            , Cmd.none
            , NoOp
            )


view : Model -> Html Msg
view =
    View.view
