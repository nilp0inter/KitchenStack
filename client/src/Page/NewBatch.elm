module Page.NewBatch exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

import Api
import Components.MarkdownEditor as MarkdownEditor
import Data.Batch
import Data.Label
import Data.LabelPreset
import Dict exposing (Dict)
import Html exposing (Html)
import Http
import Label
import Page.NewBatch.Types as NB exposing (..)
import Page.NewBatch.View as View
import Ports
import Random
import Types exposing (..)
import UUID exposing (UUID)


type alias Model = NB.Model
type alias Msg = NB.Msg
type alias OutMsg = NB.OutMsg


init : String -> String -> List Ingredient -> List ContainerType -> List Recipe -> List LabelPreset -> ( Model, Cmd Msg )
init currentDate appHost ingredients containerTypes recipes labelPresets =
    let
        form =
            Data.Batch.empty currentDate

        formWithDefaults =
            { form
                | containerId =
                    List.head containerTypes
                        |> Maybe.map .name
                        |> Maybe.withDefault ""
            }

        defaultPreset =
            List.head labelPresets
    in
    ( { form = formWithDefaults
      , ingredients = ingredients
      , containerTypes = containerTypes
      , recipes = recipes
      , labelPresets = labelPresets
      , selectedPreset = defaultPreset
      , appHost = appHost
      , loading = False
      , printWithSave = True
      , printingProgress = Nothing
      , showSuggestions = False
      , showRecipeSuggestions = False
      , expiryRequired = False
      , pendingPrintData = []
      , pendingPngRequests = []
      , pendingMeasurements = []
      , computedLabelData = Dict.empty
      , detailsEditor = MarkdownEditor.init ""
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        FormNameChanged name ->
            let
                form =
                    model.form

                shouldShowRecipeSuggestions =
                    String.length name >= 2
            in
            ( { model
                | form = { form | name = name }
                , showRecipeSuggestions = shouldShowRecipeSuggestions
              }
            , Cmd.none
            , NoOp
            )

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

                -- Check if any selected ingredient has expire_days
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

                -- Check if any remaining ingredient has expire_days
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

        FormQuantityChanged quantity ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | quantity = quantity } }, Cmd.none, NoOp )

        FormCreatedAtChanged createdAt ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | createdAt = createdAt } }, Cmd.none, NoOp )

        FormExpiryDateChanged expiryDate ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | expiryDate = expiryDate } }, Cmd.none, NoOp )

        DetailsEditorMsg subMsg ->
            ( { model | detailsEditor = MarkdownEditor.update subMsg model.detailsEditor }
            , Cmd.none
            , NoOp
            )

        SubmitBatchOnly ->
            if List.isEmpty model.form.selectedIngredients then
                ( model, Cmd.none, ShowNotification { id = 0, message = "Debes añadir al menos un ingrediente", notificationType = Error } )

            else if model.expiryRequired && model.form.expiryDate == "" then
                ( model, Cmd.none, ShowNotification { id = 0, message = "Debes indicar fecha de caducidad (ningún ingrediente tiene días definidos)", notificationType = Error } )

            else
                let
                    quantity =
                        Maybe.withDefault 1 (String.toInt model.form.quantity)

                    uuidCount =
                        1 + quantity

                    -- Sync details from editor to form
                    form =
                        model.form

                    updatedForm =
                        { form | details = MarkdownEditor.getText model.detailsEditor }
                in
                ( { model | loading = True, printWithSave = False, form = updatedForm }
                , Random.generate GotUuidsForBatch (Random.list uuidCount UUID.generator)
                , NoOp
                )

        SubmitBatchWithPrint ->
            if List.isEmpty model.form.selectedIngredients then
                ( model, Cmd.none, ShowNotification { id = 0, message = "Debes añadir al menos un ingrediente", notificationType = Error } )

            else if model.expiryRequired && model.form.expiryDate == "" then
                ( model, Cmd.none, ShowNotification { id = 0, message = "Debes indicar fecha de caducidad (ningún ingrediente tiene días definidos)", notificationType = Error } )

            else
                let
                    quantity =
                        Maybe.withDefault 1 (String.toInt model.form.quantity)

                    uuidCount =
                        1 + quantity

                    -- Sync details from editor to form
                    form =
                        model.form

                    updatedForm =
                        { form | details = MarkdownEditor.getText model.detailsEditor }
                in
                ( { model | loading = True, printWithSave = True, form = updatedForm }
                , Random.generate GotUuidsForBatch (Random.list uuidCount UUID.generator)
                , NoOp
                )

        GotUuidsForBatch uuids ->
            case uuids of
                batchUuid :: portionUuids ->
                    let
                        labelPresetName =
                            Maybe.map .name model.selectedPreset
                    in
                    ( model
                    , Api.createBatch model.form batchUuid portionUuids labelPresetName BatchCreated
                    , NoOp
                    )

                [] ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Failed to generate UUIDs", notificationType = Error }
                    )

        BatchCreated result ->
            case result of
                Ok response ->
                    let
                        ingredientsText =
                            String.join ", " (List.map .name model.form.selectedIngredients)

                        currentDate =
                            model.form.createdAt

                        details =
                            model.form.details
                    in
                    if model.printWithSave then
                        let
                            quantity =
                                List.length response.portionIds

                            printData =
                                List.map
                                    (\portionId ->
                                        { portionId = portionId
                                        , name = model.form.name
                                        , ingredients = ingredientsText
                                        , containerId = model.form.containerId
                                        , expiryDate = response.expiryDate
                                        , bestBeforeDate = response.bestBeforeDate
                                        }
                                    )
                                    response.portionIds

                            -- Start text measurement for the first label
                            -- The rest will be triggered after each measurement completes
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
                            | form = Data.Batch.empty currentDate
                            , loading = False
                            , printingProgress = Just { total = quantity, completed = 0, failed = 0 }
                            , expiryRequired = False
                            , pendingPrintData = printData
                            , pendingPngRequests = List.map .portionId printData
                            , pendingMeasurements = List.map .portionId printData
                            , computedLabelData = Dict.empty
                            , detailsEditor = MarkdownEditor.init ""
                          }
                        , Cmd.none
                        , case firstMeasureRequest of
                            Just req ->
                                RequestTextMeasure req

                            Nothing ->
                                ShowNotification { id = 0, message = "No label preset selected", notificationType = Error }
                        )

                    else
                        let
                            -- Construct BatchSummary locally for zero-fetch navigation
                            newBatch : BatchSummary
                            newBatch =
                                { batchId = response.batchId
                                , name = model.form.name
                                , containerId = model.form.containerId
                                , bestBeforeDate = response.bestBeforeDate
                                , labelPreset = Maybe.map .name model.selectedPreset
                                , batchCreatedAt = currentDate
                                , expiryDate = response.expiryDate
                                , frozenCount = List.length response.portionIds
                                , consumedCount = 0
                                , totalCount = List.length response.portionIds
                                , ingredients = ingredientsText
                                , details =
                                    if String.isEmpty (String.trim details) then
                                        Nothing

                                    else
                                        Just details
                                , image = model.form.image
                                }
                        in
                        ( { model
                            | form = Data.Batch.empty currentDate
                            , loading = False
                            , expiryRequired = False
                            , detailsEditor = MarkdownEditor.init ""
                          }
                        , Cmd.none
                        , BatchCreatedLocally newBatch response.batchId
                        )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al crear lote. Verifica que los ingredientes tienen días de caducidad o especifica una fecha manual.", notificationType = Error }
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
            in
            ( { model | printingProgress = finalProgress }
            , Cmd.none
            , if allDone then
                RefreshBatches

              else
                outMsg
            )

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
                    , Api.printLabelPng base64Data labelType PrintResult
                    , case nextRequest of
                        Just req ->
                            RequestSvgToPng req

                        Nothing ->
                            NoOp
                    )

                Nothing ->
                    -- PNG conversion failed
                    let
                        errorMsg =
                            Maybe.withDefault "Unknown error" result.error

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
                                RefreshBatches

                            else
                                NoOp
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

                -- Remove from pending measurements
                remainingMeasurements =
                    List.filter (\id -> id /= result.requestId) model.pendingMeasurements

                -- Check if all measurements are done
                allMeasured =
                    List.isEmpty remainingMeasurements
            in
            if allMeasured then
                -- All measurements done, start SVG→PNG conversion
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
                  }
                , Cmd.none
                , case nextMeasureRequest of
                    Just req ->
                        RequestTextMeasure req

                    Nothing ->
                        NoOp
                )

        HideSuggestions ->
            ( { model | showSuggestions = False }, Cmd.none, NoOp )

        HideRecipeSuggestions ->
            ( { model | showRecipeSuggestions = False }, Cmd.none, NoOp )

        SelectRecipe recipe ->
            let
                -- Parse ingredients from recipe.ingredients string
                ingredientNames =
                    String.split ", " recipe.ingredients
                        |> List.filter (\s -> String.trim s /= "")

                selectedIngredients =
                    List.map
                        (\name ->
                            { name = name
                            , isNew = not (List.any (\i -> String.toLower i.name == String.toLower name) model.ingredients)
                            }
                        )
                        ingredientNames

                -- Check if any ingredient has expire_days
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

                containerId =
                    Maybe.withDefault model.form.containerId recipe.defaultContainerId

                -- Find the matching label preset from recipe's default
                newSelectedPreset =
                    case recipe.defaultLabelPreset of
                        Just presetName ->
                            case List.filter (\p -> p.name == presetName) model.labelPresets |> List.head of
                                Just preset ->
                                    Just preset

                                Nothing ->
                                    model.selectedPreset

                        Nothing ->
                            model.selectedPreset

                form =
                    model.form
            in
            ( { model
                | form =
                    { form
                        | name = recipe.name
                        , selectedIngredients = selectedIngredients
                        , quantity = String.fromInt recipe.defaultPortions
                        , containerId = containerId
                        , details = Maybe.withDefault "" recipe.details
                        , image = recipe.image
                    }
                , showRecipeSuggestions = False
                , expiryRequired = not hasExpiryInfo && not (List.isEmpty selectedIngredients)
                , selectedPreset = newSelectedPreset
                , detailsEditor = MarkdownEditor.init (Maybe.withDefault "" recipe.details)
              }
            , Cmd.none
            , NoOp
            )

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

        ReceivedIngredients ingredients ->
            ( { model | ingredients = ingredients }, Cmd.none, NoOp )

        ReceivedContainerTypes containerTypes ->
            ( { model | containerTypes = containerTypes }, Cmd.none, NoOp )

        ReceivedRecipes recipes ->
            ( { model | recipes = recipes }, Cmd.none, NoOp )

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
                    ( { model | form = { form | image = Just base64 } }
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
                            -- User cancelled, no error
                            ( model, Cmd.none, NoOp )

        RemoveImage ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | image = Nothing } }, Cmd.none, NoOp )


view : Model -> Html Msg
view =
    View.view
