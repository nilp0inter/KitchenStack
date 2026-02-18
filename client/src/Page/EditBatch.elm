module Page.EditBatch exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

import Api
import Components.MarkdownEditor as MarkdownEditor
import Data.Label
import Data.LabelPreset
import Dict exposing (Dict)
import Html exposing (Html)
import Http
import Label
import Page.EditBatch.Types as EB exposing (..)
import Page.EditBatch.View as View
import Ports
import Random
import Types exposing (..)
import UUID exposing (UUID)


type alias Model = EB.Model
type alias Msg = EB.Msg
type alias OutMsg = EB.OutMsg


init : String -> String -> String -> List Ingredient -> List ContainerType -> List LabelPreset -> ( Model, Cmd Msg )
init batchId appHost currentDate ingredients containerTypes labelPresets =
    let
        defaultPreset =
            List.head labelPresets
    in
    ( { batchId = batchId
      , batch = Nothing
      , portions = []
      , ingredients = ingredients
      , containerTypes = containerTypes
      , labelPresets = labelPresets
      , selectedPreset = defaultPreset
      , appHost = appHost
      , currentDate = currentDate
      , loading = True
      , saving = False
      , form =
            { name = ""
            , selectedIngredients = []
            , ingredientInput = ""
            , containerId = ""
            , bestBeforeDate = ""
            , details = ""
            , image = Nothing
            }
      , discardPortionIds = []
      , newPortionQuantity = "0"
      , newPortionsExpiryDate = ""
      , expiryRequired = False
      , showSuggestions = False
      , imageChanged = False
      , detailsEditor = MarkdownEditor.init ""
      , printingProgress = Nothing
      , pendingPrintData = []
      , pendingPngRequests = []
      , pendingMeasurements = []
      , computedLabelData = Dict.empty
      }
    , Cmd.batch
        [ Api.fetchBatchById batchId GotBatch
        , Api.fetchBatchPortions batchId GotBatchPortions
        , Api.fetchBatchIngredients batchId GotBatchIngredients
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotBatch result ->
            case result of
                Ok batches ->
                    case List.head batches of
                        Just batch ->
                            let
                                -- Find the label preset for this batch
                                batchPreset =
                                    batch.labelPreset
                                        |> Maybe.andThen
                                            (\name ->
                                                List.filter (\p -> p.name == name) model.labelPresets
                                                    |> List.head
                                            )

                                selectedPreset =
                                    case batchPreset of
                                        Just preset ->
                                            Just preset

                                        Nothing ->
                                            model.selectedPreset

                                form =
                                    model.form
                            in
                            ( { model
                                | batch = Just batch
                                , loading = False
                                , selectedPreset = selectedPreset
                                , form =
                                    { form
                                        | name = batch.name
                                        , containerId = batch.containerId
                                        , bestBeforeDate = Maybe.withDefault "" batch.bestBeforeDate
                                        , details = Maybe.withDefault "" batch.details
                                        , image = batch.image
                                    }
                                , detailsEditor = MarkdownEditor.init (Maybe.withDefault "" batch.details)
                              }
                            , Cmd.none
                            , NoOp
                            )

                        Nothing ->
                            ( { model | loading = False }, Cmd.none, NoOp )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al cargar el lote", notificationType = Error }
                    )

        GotBatchPortions result ->
            case result of
                Ok portions ->
                    ( { model | portions = portions }, Cmd.none, NoOp )

                Err _ ->
                    ( model, Cmd.none, ShowNotification { id = 0, message = "Error al cargar porciones", notificationType = Error } )

        GotBatchIngredients result ->
            case result of
                Ok batchIngredients ->
                    let
                        selectedIngredients =
                            List.map
                                (\bi ->
                                    { name = bi.ingredientName
                                    , isNew = not (List.any (\i -> String.toLower i.name == String.toLower bi.ingredientName) model.ingredients)
                                    }
                                )
                                batchIngredients

                        hasExpiryInfo =
                            List.any
                                (\sel ->
                                    List.any
                                        (\ing ->
                                            String.toLower ing.name == String.toLower sel.name && ing.expireDays /= Nothing
                                        )
                                        model.ingredients
                                )
                                selectedIngredients

                        form =
                            model.form
                    in
                    ( { model
                        | form = { form | selectedIngredients = selectedIngredients }
                        , expiryRequired = not hasExpiryInfo && not (List.isEmpty selectedIngredients)
                      }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( model, Cmd.none, ShowNotification { id = 0, message = "Error al cargar ingredientes del lote", notificationType = Error } )

        FormNameChanged name ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | name = name } }, Cmd.none, NoOp )

        FormIngredientInputChanged input ->
            let
                form =
                    model.form

                shouldShowSuggestions =
                    String.length input >= 1
            in
            ( { model
                | form = { form | ingredientInput = input }
                , showSuggestions = shouldShowSuggestions
              }
            , Cmd.none
            , NoOp
            )

        AddIngredient ingredientName ->
            let
                trimmedName =
                    String.trim (String.toLower ingredientName)

                form =
                    model.form

                alreadySelected =
                    List.any (\i -> String.toLower i.name == trimmedName) form.selectedIngredients

                isExisting =
                    List.any (\i -> String.toLower i.name == trimmedName) model.ingredients

                newSelectedIngredient =
                    { name = trimmedName
                    , isNew = not isExisting
                    }

                newSelectedIngredients =
                    if trimmedName /= "" && not alreadySelected then
                        form.selectedIngredients ++ [ newSelectedIngredient ]

                    else
                        form.selectedIngredients

                hasExpiryInfo =
                    List.any
                        (\sel ->
                            List.any
                                (\ing ->
                                    String.toLower ing.name == String.toLower sel.name && ing.expireDays /= Nothing
                                )
                                model.ingredients
                        )
                        newSelectedIngredients
            in
            ( { model
                | form =
                    { form
                        | selectedIngredients = newSelectedIngredients
                        , ingredientInput = ""
                    }
                , showSuggestions = False
                , expiryRequired = not hasExpiryInfo
              }
            , Cmd.none
            , NoOp
            )

        RemoveIngredient ingredientName ->
            let
                form =
                    model.form

                newSelectedIngredients =
                    List.filter (\i -> i.name /= ingredientName) form.selectedIngredients

                hasExpiryInfo =
                    List.any
                        (\sel ->
                            List.any
                                (\ing ->
                                    String.toLower ing.name == String.toLower sel.name && ing.expireDays /= Nothing
                                )
                                model.ingredients
                        )
                        newSelectedIngredients
            in
            ( { model
                | form = { form | selectedIngredients = newSelectedIngredients }
                , expiryRequired = not hasExpiryInfo && not (List.isEmpty newSelectedIngredients)
              }
            , Cmd.none
            , NoOp
            )

        FormContainerChanged containerId ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | containerId = containerId } }, Cmd.none, NoOp )

        FormBestBeforeDateChanged date ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | bestBeforeDate = date } }, Cmd.none, NoOp )

        NewPortionQuantityChanged qty ->
            ( { model | newPortionQuantity = qty }, Cmd.none, NoOp )

        NewPortionsExpiryDateChanged date ->
            ( { model | newPortionsExpiryDate = date }, Cmd.none, NoOp )

        ToggleDiscardPortion portionId ->
            let
                newDiscardIds =
                    if List.member portionId model.discardPortionIds then
                        List.filter (\id -> id /= portionId) model.discardPortionIds

                    else
                        portionId :: model.discardPortionIds
            in
            ( { model | discardPortionIds = newDiscardIds }, Cmd.none, NoOp )

        SelectPreset presetName ->
            let
                maybePreset =
                    List.filter (\p -> p.name == presetName) model.labelPresets
                        |> List.head
            in
            ( { model | selectedPreset = maybePreset }, Cmd.none, NoOp )

        SubmitUpdate ->
            submitBatch False model

        SubmitUpdateAndPrint ->
            submitBatch True model

        GotUuidsForUpdate uuids ->
            let
                newPortionIds =
                    List.map UUID.toString uuids

                form =
                    model.form

                ingredientNames =
                    List.map .name form.selectedIngredients

                details =
                    MarkdownEditor.getText model.detailsEditor
            in
            ( model
            , Api.updateBatch
                { batchId = model.batchId
                , name = form.name
                , containerId = form.containerId
                , ingredientNames = ingredientNames
                , labelPreset = Maybe.map .name model.selectedPreset
                , details = details
                , image =
                    if model.imageChanged then
                        form.image

                    else
                        Nothing
                , removeImage = model.imageChanged && form.image == Nothing
                , bestBeforeDate = form.bestBeforeDate
                , newPortionIds = newPortionIds
                , discardPortionIds = model.discardPortionIds
                , newPortionsCreatedAt = model.currentDate
                , newPortionsExpiryDate = model.newPortionsExpiryDate
                }
                BatchUpdated
            , NoOp
            )

        BatchUpdated result ->
            case result of
                Ok response ->
                    let
                        ingredientsText =
                            String.join ", " (List.map .name model.form.selectedIngredients)

                        hasNewPortions =
                            not (List.isEmpty response.newPortionIds)
                    in
                    if hasNewPortions && model.saving then
                        -- model.saving is True when we want to print (printWithSave pattern)
                        -- Check if we should print
                        let
                            printData =
                                List.map
                                    (\portionId ->
                                        { portionId = portionId
                                        , name = model.form.name
                                        , ingredients = ingredientsText
                                        , containerId = model.form.containerId
                                        , expiryDate = Maybe.withDefault "" response.newExpiryDate
                                        , bestBeforeDate = response.bestBeforeDate
                                        }
                                    )
                                    response.newPortionIds

                            quantity =
                                List.length response.newPortionIds

                            firstMeasureRequest =
                                case ( List.head printData, model.selectedPreset ) of
                                    ( Just firstData, Just preset ) ->
                                        let
                                            labelSettings =
                                                Data.LabelPreset.presetToSettings preset
                                        in
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

                                    _ ->
                                        Nothing
                        in
                        ( { model
                            | saving = False
                            , printingProgress = Just { total = quantity, completed = 0, failed = 0 }
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
                                RefreshBatchesWithNotification { id = 0, message = "Lote actualizado", notificationType = Success }
                        )

                    else
                        ( { model | saving = False }
                        , Cmd.none
                        , RefreshBatchesWithNotification { id = 0, message = "Lote actualizado", notificationType = Success }
                        )

                Err _ ->
                    ( { model | saving = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al actualizar el lote", notificationType = Error }
                    )

        PrintResult result ->
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

                printNotification =
                    if allDone then
                        case newProgress of
                            Just p ->
                                if p.failed > 0 then
                                    Just { id = 0, message = String.fromInt p.completed ++ " etiquetas impresas, " ++ String.fromInt p.failed ++ " fallidas", notificationType = Error }

                                else
                                    Just { id = 0, message = String.fromInt p.completed ++ " etiquetas impresas correctamente!", notificationType = Success }

                            Nothing ->
                                Nothing

                    else
                        Nothing

                finalProgress =
                    if allDone then
                        Nothing

                    else
                        newProgress
            in
            ( { model | printingProgress = finalProgress }
            , Cmd.none
            , if allDone then
                case printNotification of
                    Just n ->
                        RefreshBatchesWithNotification n

                    Nothing ->
                        RefreshBatchesWithNotification { id = 0, message = "Lote actualizado", notificationType = Success }

              else
                NoOp
            )

        HideSuggestions ->
            ( { model | showSuggestions = False }, Cmd.none, NoOp )

        IngredientKeyDown key ->
            if key == "Enter" || key == "," then
                let
                    trimmedInput =
                        String.trim model.form.ingredientInput
                in
                if trimmedInput /= "" then
                    update (AddIngredient trimmedInput) model

                else
                    ( model, Cmd.none, NoOp )

            else
                ( model, Cmd.none, NoOp )

        DetailsEditorMsg subMsg ->
            ( { model | detailsEditor = MarkdownEditor.update subMsg model.detailsEditor }
            , Cmd.none
            , NoOp
            )

        SelectImage ->
            ( model
            , Cmd.none
            , RequestFileSelect
                { requestId = "batch-image"
                , maxSizeKb = 500
                , acceptTypes = [ "image/png", "image/jpeg", "image/webp" ]
                }
            )

        GotImageResult result ->
            case result.dataUrl of
                Just base64 ->
                    let
                        form =
                            model.form
                    in
                    ( { model | form = { form | image = Just base64 }, imageChanged = True }
                    , Cmd.none
                    , NoOp
                    )

                Nothing ->
                    case result.error of
                        Just errorMsg ->
                            ( model
                            , Cmd.none
                            , ShowNotification { id = 0, message = errorMsg, notificationType = Error }
                            )

                        Nothing ->
                            ( model, Cmd.none, NoOp )

        RemoveImage ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | image = Nothing }, imageChanged = True }, Cmd.none, NoOp )

        GotPngResult result ->
            case result.dataUrl of
                Just dataUrl ->
                    let
                        base64Data =
                            String.replace "data:image/png;base64," "" dataUrl

                        labelType =
                            model.selectedPreset
                                |> Maybe.map .labelType
                                |> Maybe.withDefault "62"

                        remainingRequests =
                            List.filter (\id -> id /= result.requestId) model.pendingPngRequests

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
                    , Api.printLabelPng base64Data labelType PrintResult
                    , case nextRequest of
                        Just req ->
                            RequestSvgToPng req

                        Nothing ->
                            NoOp
                    )

                Nothing ->
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
                    ( { model
                        | pendingPngRequests = remainingRequests
                        , printingProgress = finalProgress
                      }
                    , Cmd.none
                    , case nextRequest of
                        Just req ->
                            RequestSvgToPng req

                        Nothing ->
                            if allDone then
                                RefreshBatchesWithNotification { id = 0, message = "Lote actualizado", notificationType = Success }

                            else
                                NoOp
                    )

        GotTextMeasureResult result ->
            let
                newComputedData =
                    Dict.insert result.requestId
                        { titleFontSize = result.titleFittedFontSize
                        , titleLines = result.titleLines
                        , ingredientLines = result.ingredientLines
                        }
                        model.computedLabelData

                remainingMeasurements =
                    List.filter (\id -> id /= result.requestId) model.pendingMeasurements

                allMeasured =
                    List.isEmpty remainingMeasurements
            in
            if allMeasured then
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
                  }
                , Cmd.none
                , case firstRequest of
                    Just req ->
                        RequestSvgToPng req

                    Nothing ->
                        NoOp
                )

            else
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
                  }
                , Cmd.none
                , case nextMeasureRequest of
                    Just req ->
                        RequestTextMeasure req

                    Nothing ->
                        NoOp
                )

        ReceivedIngredients ingredients ->
            ( { model | ingredients = ingredients }, Cmd.none, NoOp )

        ReceivedContainerTypes containerTypes ->
            ( { model | containerTypes = containerTypes }, Cmd.none, NoOp )

        ReceivedLabelPresets labelPresets ->
            let
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


submitBatch : Bool -> Model -> ( Model, Cmd Msg, OutMsg )
submitBatch printAfterSave model =
    if List.isEmpty model.form.selectedIngredients then
        ( model, Cmd.none, ShowNotification { id = 0, message = "Debes añadir al menos un ingrediente", notificationType = Error } )

    else
        let
            newQty =
                Maybe.withDefault 0 (String.toInt model.newPortionQuantity)

            needsExpiry =
                newQty > 0 && model.expiryRequired && model.newPortionsExpiryDate == ""
        in
        if needsExpiry then
            ( model, Cmd.none, ShowNotification { id = 0, message = "Debes indicar fecha de caducidad para las nuevas porciones", notificationType = Error } )

        else if newQty > 0 then
            -- Generate UUIDs for new portions
            ( { model | saving = printAfterSave || model.saving }
            , Random.generate GotUuidsForUpdate (Random.list newQty UUID.generator)
            , NoOp
            )

        else
            -- No new portions, submit directly
            let
                form =
                    model.form

                details =
                    MarkdownEditor.getText model.detailsEditor

                ingredientNames =
                    List.map .name form.selectedIngredients
            in
            ( { model | saving = True }
            , Api.updateBatch
                { batchId = model.batchId
                , name = form.name
                , containerId = form.containerId
                , ingredientNames = ingredientNames
                , labelPreset = Maybe.map .name model.selectedPreset
                , details = details
                , image =
                    if model.imageChanged then
                        form.image

                    else
                        Nothing
                , removeImage = model.imageChanged && form.image == Nothing
                , bestBeforeDate = form.bestBeforeDate
                , newPortionIds = []
                , discardPortionIds = model.discardPortionIds
                , newPortionsCreatedAt = model.currentDate
                , newPortionsExpiryDate = ""
                }
                BatchUpdated
            , NoOp
            )


view : Model -> Html Msg
view =
    View.view
