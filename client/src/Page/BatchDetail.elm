module Page.BatchDetail exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    , init
    , update
    , view
    )

import Api
import Components
import Html exposing (..)
import Html.Attributes as Attr exposing (class, href, title)
import Html.Events exposing (onClick, onInput)
import Http
import Label
import Ports
import Types exposing (..)


type alias Model =
    { batchId : String
    , batch : Maybe BatchSummary
    , portions : List PortionInBatch
    , labelPresets : List LabelPreset
    , selectedPreset : Maybe LabelPreset
    , appHost : String
    , loading : Bool
    , error : Maybe String
    , previewModal : Maybe PortionPrintData
    , printingProgress : Maybe PrintingProgress
    , pendingPrintData : List PortionPrintData
    , pendingPngRequests : List String
    }


type Msg
    = GotBatches (Result Http.Error (List BatchSummary))
    | GotBatchPortions (Result Http.Error (List PortionInBatch))
    | ReprintPortion PortionInBatch
    | ReprintAllFrozen
    | PrintResult (Result Http.Error ())
    | OpenPreviewModal PortionPrintData
    | ClosePreviewModal
    | ReturnToFreezer String
    | ReturnToFreezerResult (Result Http.Error ())
    | SelectPreset String
    | GotPngResult Ports.PngResult


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RequestSvgToPng Ports.SvgToPngRequest


init : String -> String -> List BatchSummary -> List LabelPreset -> ( Model, Cmd Msg )
init batchId appHost batches labelPresets =
    let
        maybeBatch =
            List.filter (\b -> b.batchId == batchId) batches
                |> List.head

        defaultPreset =
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
      , printingProgress = Nothing
      , pendingPrintData = []
      , pendingPngRequests = []
      }
    , Cmd.batch
        [ Api.fetchBatches GotBatches
        , Api.fetchBatchPortions batchId GotBatchPortions
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
                    in
                    ( { model | batch = maybeBatch }, Cmd.none, NoOp )

                Err _ ->
                    ( model, Cmd.none, ShowNotification { message = "Failed to load batch", notificationType = Error } )

        GotBatchPortions result ->
            case result of
                Ok portions ->
                    ( { model | portions = portions, loading = False }, Cmd.none, NoOp )

                Err _ ->
                    ( { model | error = Just "Failed to load batch portions", loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Failed to load batch portions", notificationType = Error }
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

                        request =
                            { svgId = Label.labelSvgId printData.portionId
                            , requestId = printData.portionId
                            , width = preset.width
                            , height = preset.height
                            }
                    in
                    ( { model
                        | printingProgress = Just { total = 1, completed = 0, failed = 0 }
                        , pendingPrintData = [ printData ]
                        , pendingPngRequests = [ printData.portionId ]
                      }
                    , Cmd.none
                    , RequestSvgToPng request
                    )

                ( _, Nothing ) ->
                    ( model, Cmd.none, ShowNotification { message = "No hay preajuste de etiqueta seleccionado", notificationType = Error } )

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

                        -- Start SVG→PNG conversion for the first label
                        firstRequest =
                            case List.head printData of
                                Just firstData ->
                                    Just
                                        { svgId = Label.labelSvgId firstData.portionId
                                        , requestId = firstData.portionId
                                        , width = preset.width
                                        , height = preset.height
                                        }

                                Nothing ->
                                    Nothing
                    in
                    if quantity > 0 then
                        ( { model
                            | printingProgress = Just { total = quantity, completed = 0, failed = 0 }
                            , pendingPrintData = printData
                            , pendingPngRequests = List.map .portionId printData
                          }
                        , Cmd.none
                        , case firstRequest of
                            Just req ->
                                RequestSvgToPng req

                            Nothing ->
                                NoOp
                        )

                    else
                        ( model
                        , Cmd.none
                        , ShowNotification { message = "No hay porciones congeladas para imprimir", notificationType = Info }
                        )

                ( _, Nothing ) ->
                    ( model, Cmd.none, ShowNotification { message = "No hay preajuste de etiqueta seleccionado", notificationType = Error } )

                ( Nothing, _ ) ->
                    ( model, Cmd.none, NoOp )

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
                                    ShowNotification { message = String.fromInt p.completed ++ " etiquetas impresas, " ++ String.fromInt p.failed ++ " fallidas", notificationType = Error }

                                else
                                    ShowNotification { message = String.fromInt p.completed ++ " etiquetas impresas correctamente!", notificationType = Success }

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
            ( { model | printingProgress = finalProgress }, Cmd.none, outMsg )

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
                                        }

                                _ ->
                                    Nothing
                    in
                    ( { model | pendingPngRequests = remainingRequests }
                    , Api.printLabelPng base64Data PrintResult
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
                                        }

                                _ ->
                                    Nothing

                        outMsg =
                            if allDone then
                                case newProgress of
                                    Just p ->
                                        if p.failed > 0 then
                                            ShowNotification { message = String.fromInt p.completed ++ " etiquetas impresas, " ++ String.fromInt p.failed ++ " fallidas", notificationType = Error }

                                        else
                                            ShowNotification { message = String.fromInt p.completed ++ " etiquetas impresas correctamente!", notificationType = Success }

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

        OpenPreviewModal portionData ->
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
                    , ShowNotification { message = "Porción devuelta al congelador", notificationType = Success }
                    )

                Err _ ->
                    ( model
                    , Cmd.none
                    , ShowNotification { message = "Error al devolver porción al congelador", notificationType = Error }
                    )


view : Model -> Html Msg
view model =
    div []
        [ viewPreviewModal model
        , Components.viewPrintingProgress model.printingProgress
        , viewContent model
        , viewHiddenLabels model
        ]


{-| Use SVG-based preview modal with the selected preset settings.
-}
viewPreviewModal : Model -> Html Msg
viewPreviewModal model =
    case model.selectedPreset of
        Just preset ->
            let
                labelSettings =
                    { name = preset.name
                    , width = preset.width
                    , height = preset.height
                    , qrSize = preset.qrSize
                    , padding = preset.padding
                    , titleFontSize = preset.titleFontSize
                    , dateFontSize = preset.dateFontSize
                    , smallFontSize = preset.smallFontSize
                    , fontFamily = preset.fontFamily
                    , showTitle = preset.showTitle
                    , showIngredients = preset.showIngredients
                    , showExpiryDate = preset.showExpiryDate
                    , showBestBefore = preset.showBestBefore
                    , showQr = preset.showQr
                    , showBranding = preset.showBranding
                    , verticalSpacing = preset.verticalSpacing
                    , showSeparator = preset.showSeparator
                    , separatorThickness = preset.separatorThickness
                    , separatorColor = preset.separatorColor
                    , cornerRadius = preset.cornerRadius
                    , titleMaxChars = preset.titleMaxChars
                    , ingredientsMaxChars = preset.ingredientsMaxChars
                    }
            in
            Components.viewPreviewModalSvg labelSettings model.appHost model.previewModal ClosePreviewModal

        Nothing ->
            Components.viewPreviewModal model.previewModal ClosePreviewModal


viewContent : Model -> Html Msg
viewContent model =
    case model.batch of
        Nothing ->
            if model.loading then
                Components.viewLoading

            else
                div [ class "text-center py-12" ]
                    [ span [ class "text-6xl" ] [ text "❓" ]
                    , h1 [ class "text-3xl font-bold text-gray-800 mt-4" ] [ text "Batch no encontrado" ]
                    , a [ href "/", class "btn-primary inline-block mt-4" ] [ text "Volver al inicio" ]
                    ]

        Just batch ->
            let
                frozenCount =
                    List.filter (\p -> p.status == "FROZEN") model.portions
                        |> List.length
            in
            div [ class "max-w-4xl mx-auto" ]
                [ viewBatchHeader model batch frozenCount
                , viewPortionsTable batch model.portions
                , div [ class "mt-6" ]
                    [ a [ href "/", class "text-frost-600 hover:text-frost-800" ] [ text "← Volver al inventario" ]
                    ]
                ]


viewBatchHeader : Model -> BatchSummary -> Int -> Html Msg
viewBatchHeader model batch frozenCount =
    div [ class "card mb-6" ]
        [ div [ class "flex justify-between items-start" ]
            [ div []
                [ h1 [ class "text-2xl font-bold text-gray-800" ] [ text batch.name ]
                , p [ class "text-gray-600 mt-1" ]
                    [ text batch.containerId ]
                , if batch.ingredients /= "" then
                    p [ class "text-gray-500 mt-1 text-sm" ]
                        [ span [ class "font-medium" ] [ text "Ingredientes: " ]
                        , text batch.ingredients
                        ]

                  else
                    text ""
                , p [ class "text-gray-500 mt-2" ]
                    [ text ("Caduca: " ++ batch.expiryDate) ]
                , case batch.bestBeforeDate of
                    Just bbDate ->
                        p [ class "text-gray-500 text-sm" ]
                            [ text ("Consumo preferente: " ++ bbDate) ]

                    Nothing ->
                        text ""
                ]
            , div [ class "flex flex-col items-end space-y-2" ]
                [ viewPresetSelector model
                , if frozenCount > 0 then
                    button
                        [ onClick ReprintAllFrozen
                        , class "bg-frost-500 hover:bg-frost-600 text-white font-medium px-4 py-2 rounded-lg transition-colors"
                        ]
                        [ text ("Imprimir todas (" ++ String.fromInt frozenCount ++ ")") ]

                  else
                    text ""
                ]
            ]
        ]


viewPresetSelector : Model -> Html Msg
viewPresetSelector model =
    div [ class "flex items-center space-x-2" ]
        [ label [ class "text-sm text-gray-600" ] [ text "Etiqueta:" ]
        , select
            [ class "border border-gray-300 rounded px-2 py-1 text-sm"
            , onInput SelectPreset
            , Attr.value (Maybe.map .name model.selectedPreset |> Maybe.withDefault "")
            ]
            (List.map
                (\preset ->
                    Html.option
                        [ Attr.value preset.name
                        , Attr.selected (Maybe.map .name model.selectedPreset == Just preset.name)
                        ]
                        [ text preset.name ]
                )
                model.labelPresets
            )
        ]


{-| Render hidden SVG labels for pending print jobs.
-}
viewHiddenLabels : Model -> Html Msg
viewHiddenLabels model =
    case model.selectedPreset of
        Just preset ->
            let
                labelSettings =
                    { name = preset.name
                    , width = preset.width
                    , height = preset.height
                    , qrSize = preset.qrSize
                    , padding = preset.padding
                    , titleFontSize = preset.titleFontSize
                    , dateFontSize = preset.dateFontSize
                    , smallFontSize = preset.smallFontSize
                    , fontFamily = preset.fontFamily
                    , showTitle = preset.showTitle
                    , showIngredients = preset.showIngredients
                    , showExpiryDate = preset.showExpiryDate
                    , showBestBefore = preset.showBestBefore
                    , showQr = preset.showQr
                    , showBranding = preset.showBranding
                    , verticalSpacing = preset.verticalSpacing
                    , showSeparator = preset.showSeparator
                    , separatorThickness = preset.separatorThickness
                    , separatorColor = preset.separatorColor
                    , cornerRadius = preset.cornerRadius
                    , titleMaxChars = preset.titleMaxChars
                    , ingredientsMaxChars = preset.ingredientsMaxChars
                    }
            in
            div
                [ Attr.style "position" "absolute"
                , Attr.style "left" "-9999px"
                , Attr.style "top" "-9999px"
                ]
                (List.map
                    (\printData ->
                        Label.viewLabel labelSettings
                            { portionId = printData.portionId
                            , name = printData.name
                            , ingredients = printData.ingredients
                            , expiryDate = printData.expiryDate
                            , bestBeforeDate = printData.bestBeforeDate
                            , appHost = model.appHost
                            }
                    )
                    model.pendingPrintData
                )

        Nothing ->
            text ""


viewPortionsTable : BatchSummary -> List PortionInBatch -> Html Msg
viewPortionsTable batch portions =
    div [ class "card overflow-hidden" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 p-4 border-b" ] [ text "Porciones" ]
        , div [ class "overflow-x-auto" ]
            [ table [ class "w-full" ]
                [ thead [ class "bg-gray-50" ]
                    [ tr []
                        [ th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "#" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Estado" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Congelado" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Caduca" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Acciones" ]
                        ]
                    ]
                , tbody [ class "divide-y divide-gray-200" ]
                    (List.indexedMap (viewPortionRow batch) portions)
                ]
            ]
        ]


viewPortionRow : BatchSummary -> Int -> PortionInBatch -> Html Msg
viewPortionRow batch index portion =
    let
        printData =
            { portionId = portion.portionId
            , name = batch.name
            , ingredients = batch.ingredients
            , containerId = batch.containerId
            , expiryDate = portion.expiryDate
            , bestBeforeDate = batch.bestBeforeDate
            }
    in
    tr [ class "hover:bg-gray-50" ]
        [ td [ class "px-4 py-3 text-gray-600" ] [ text (String.fromInt (index + 1)) ]
        , td [ class "px-4 py-3" ]
            [ if portion.status == "FROZEN" then
                span [ class "inline-block bg-frost-100 text-frost-700 px-2 py-1 rounded text-sm" ]
                    [ text "Congelada" ]

              else
                span [ class "inline-block bg-green-100 text-green-700 px-2 py-1 rounded text-sm" ]
                    [ text "Consumida" ]
            ]
        , td [ class "px-4 py-3 text-gray-600" ] [ text portion.createdAt ]
        , td [ class "px-4 py-3 text-gray-600" ] [ text portion.expiryDate ]
        , td [ class "px-4 py-3" ]
            [ if portion.status == "FROZEN" then
                div [ class "flex space-x-2" ]
                    [ a
                        [ href ("/item/" ++ portion.portionId)
                        , class "text-2xl hover:scale-110 transition-transform"
                        , title "Consumir"
                        ]
                        [ text "🍴" ]
                    , button
                        [ onClick (OpenPreviewModal printData)
                        , class "text-2xl hover:scale-110 transition-transform"
                        , title "Vista previa"
                        ]
                        [ text "👁️" ]
                    , button
                        [ onClick (ReprintPortion portion)
                        , class "text-2xl hover:scale-110 transition-transform"
                        , title "Reimprimir"
                        ]
                        [ text "🖨️" ]
                    ]

              else
                button
                    [ onClick (ReturnToFreezer portion.portionId)
                    , class "text-2xl hover:scale-110 transition-transform"
                    , title "Devolver al congelador"
                    ]
                    [ text "🔄" ]
            ]
        ]
