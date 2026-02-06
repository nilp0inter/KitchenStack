module Page.BatchDetail exposing
    ( Model
    , Msg
    , OutMsg(..)
    , init
    , update
    , view
    )

import Api
import Components
import Html exposing (..)
import Html.Attributes exposing (class, href, title)
import Html.Events exposing (onClick)
import Http
import Types exposing (..)


type alias Model =
    { batchId : String
    , batch : Maybe BatchSummary
    , portions : List PortionInBatch
    , loading : Bool
    , error : Maybe String
    , previewModal : Maybe PortionPrintData
    , printingProgress : Maybe PrintingProgress
    }


type Msg
    = GotBatches (Result Http.Error (List BatchSummary))
    | GotBatchPortions (Result Http.Error (List PortionInBatch))
    | ReprintPortion PortionInBatch
    | ReprintAllFrozen
    | PrintResult String (Result Http.Error ())
    | OpenPreviewModal PortionPrintData
    | ClosePreviewModal
    | ReturnToFreezer String
    | ReturnToFreezerResult (Result Http.Error ())


type OutMsg
    = NoOp
    | ShowNotification Notification


init : String -> List BatchSummary -> ( Model, Cmd Msg )
init batchId batches =
    let
        maybeBatch =
            List.filter (\b -> b.batchId == batchId) batches
                |> List.head
    in
    ( { batchId = batchId
      , batch = maybeBatch
      , portions = []
      , loading = True
      , error = Nothing
      , previewModal = Nothing
      , printingProgress = Nothing
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
            case model.batch of
                Just batch ->
                    let
                        printData =
                            { portionId = portion.portionId
                            , name = batch.name
                            , ingredients = batch.ingredients
                            , containerId = batch.containerId
                            , expiryDate = portion.expiryDate
                            }
                    in
                    ( { model
                        | printingProgress = Just { total = 1, completed = 0, failed = 0 }
                      }
                    , Api.printLabel printData PrintResult
                    , ShowNotification { message = "Imprimiendo etiqueta...", notificationType = Info }
                    )

                Nothing ->
                    ( model, Cmd.none, NoOp )

        ReprintAllFrozen ->
            case model.batch of
                Just batch ->
                    let
                        frozenPortions =
                            List.filter (\p -> p.status == "FROZEN") model.portions

                        quantity =
                            List.length frozenPortions

                        printCommands =
                            List.map
                                (\portion ->
                                    Api.printLabel
                                        { portionId = portion.portionId
                                        , name = batch.name
                                        , ingredients = batch.ingredients
                                        , containerId = batch.containerId
                                        , expiryDate = portion.expiryDate
                                        }
                                        PrintResult
                                )
                                frozenPortions
                    in
                    if quantity > 0 then
                        ( { model | printingProgress = Just { total = quantity, completed = 0, failed = 0 } }
                        , Cmd.batch printCommands
                        , ShowNotification { message = "Imprimiendo " ++ String.fromInt quantity ++ " etiquetas...", notificationType = Info }
                        )

                    else
                        ( model
                        , Cmd.none
                        , ShowNotification { message = "No hay porciones congeladas para imprimir", notificationType = Info }
                        )

                Nothing ->
                    ( model, Cmd.none, NoOp )

        PrintResult _ result ->
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
                                    ShowNotification { message = String.fromInt p.completed ++ " labels printed, " ++ String.fromInt p.failed ++ " failed", notificationType = Error }

                                else
                                    ShowNotification { message = String.fromInt p.completed ++ " labels printed successfully!", notificationType = Success }

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
        [ Components.viewPreviewModal model.previewModal ClosePreviewModal
        , Components.viewPrintingProgress model.printingProgress
        , viewContent model
        ]


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
                [ viewBatchHeader batch frozenCount
                , viewPortionsTable batch model.portions
                , div [ class "mt-6" ]
                    [ a [ href "/", class "text-frost-600 hover:text-frost-800" ] [ text "← Volver al inventario" ]
                    ]
                ]


viewBatchHeader : BatchSummary -> Int -> Html Msg
viewBatchHeader batch frozenCount =
    div [ class "card mb-6" ]
        [ div [ class "flex justify-between items-start" ]
            [ div []
                [ h1 [ class "text-2xl font-bold text-gray-800" ] [ text batch.name ]
                , p [ class "text-gray-600 mt-1" ]
                    [ span [ class "inline-block bg-frost-100 text-frost-700 px-2 py-1 rounded text-sm mr-2" ]
                        [ text batch.categoryId ]
                    , text batch.containerId
                    ]
                , p [ class "text-gray-500 mt-2" ]
                    [ text ("Caduca: " ++ batch.expiryDate) ]
                ]
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
