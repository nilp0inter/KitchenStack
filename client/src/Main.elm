module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes as Attr exposing (attribute, class, disabled, href, placeholder, required, selected, style, title, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Random
import Svg exposing (rect, svg)
import Svg.Attributes as SvgAttr
import UUID exposing (UUID)
import Url
import Url.Builder
import Url.Parser as Parser exposing ((</>), Parser)



-- MAIN


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- FLAGS


type alias Flags =
    { currentDate : String
    }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , route : Route
    , currentDate : String
    , batches : List BatchSummary
    , categories : List Category
    , containerTypes : List ContainerType
    , form : BatchForm
    , portionDetail : Maybe PortionDetail
    , batchDetail : Maybe BatchDetailData
    , historyData : List HistoryPoint
    , loading : Bool
    , error : Maybe String
    , notification : Maybe Notification
    , printingProgress : Maybe PrintingProgress
    , printWithSave : Bool
    , previewModal : Maybe PortionPrintData
    }


type alias BatchSummary =
    { batchId : String
    , name : String
    , categoryId : String
    , containerId : String
    , ingredients : String
    , batchCreatedAt : String
    , expiryDate : String
    , frozenCount : Int
    , consumedCount : Int
    , totalCount : Int
    }


type alias PortionDetail =
    { portionId : String
    , batchId : String
    , createdAt : String
    , expiryDate : String
    , status : String
    , consumedAt : Maybe String
    , name : String
    , categoryId : String
    , containerId : String
    , ingredients : String
    }


type alias Category =
    { name : String
    , safeDays : Int
    }


type alias ContainerType =
    { name : String
    , servingsPerUnit : Float
    }


type alias BatchForm =
    { name : String
    , categoryId : String
    , containerId : String
    , ingredients : String
    , quantity : String
    , createdAt : String
    , expiryDate : String
    }


type alias CreateBatchResponse =
    { batchId : String
    , portionIds : List String
    }


type alias HistoryPoint =
    { date : String
    , added : Int
    , consumed : Int
    , frozenTotal : Int
    }


type alias Notification =
    { message : String
    , notificationType : NotificationType
    }


type alias PrintingProgress =
    { total : Int
    , completed : Int
    , failed : Int
    }


type alias BatchDetailData =
    { batch : BatchSummary
    , portions : List PortionInBatch
    }


type alias PortionInBatch =
    { portionId : String
    , status : String
    , createdAt : String
    , expiryDate : String
    , consumedAt : Maybe String
    }


type NotificationType
    = Success
    | Error
    | Info


type Route
    = Dashboard
    | NewBatch
    | ItemDetail String
    | BatchDetail String
    | History
    | NotFound


emptyForm : String -> BatchForm
emptyForm currentDate =
    { name = ""
    , categoryId = ""
    , containerId = ""
    , ingredients = ""
    , quantity = "1"
    , createdAt = currentDate
    , expiryDate = ""
    }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        route =
            parseUrl url

        initialCmd =
            case route of
                ItemDetail portionId ->
                    Cmd.batch
                        [ fetchCategories
                        , fetchContainerTypes
                        , fetchPortionDetail portionId
                        ]

                BatchDetail batchId ->
                    Cmd.batch
                        [ fetchCategories
                        , fetchContainerTypes
                        , fetchBatches
                        , fetchBatchPortions batchId
                        ]

                History ->
                    Cmd.batch
                        [ fetchCategories
                        , fetchContainerTypes
                        , fetchBatches
                        , fetchHistory
                        ]

                _ ->
                    Cmd.batch
                        [ fetchCategories
                        , fetchContainerTypes
                        , fetchBatches
                        ]
    in
    ( { key = key
      , url = url
      , route = route
      , currentDate = flags.currentDate
      , batches = []
      , categories = []
      , containerTypes = []
      , form = emptyForm flags.currentDate
      , portionDetail = Nothing
      , batchDetail = Nothing
      , historyData = []
      , loading = True
      , error = Nothing
      , notification = Nothing
      , printingProgress = Nothing
      , printWithSave = True
      , previewModal = Nothing
      }
    , initialCmd
    )



-- URL PARSING


parseUrl : Url.Url -> Route
parseUrl url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Dashboard Parser.top
        , Parser.map NewBatch (Parser.s "new")
        , Parser.map ItemDetail (Parser.s "item" </> Parser.string)
        , Parser.map BatchDetail (Parser.s "batch" </> Parser.string)
        , Parser.map History (Parser.s "history")
        ]



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotCategories (Result Http.Error (List Category))
    | GotContainerTypes (Result Http.Error (List ContainerType))
    | GotBatches (Result Http.Error (List BatchSummary))
    | GotPortionDetail (Result Http.Error PortionDetail)
    | GotBatchPortions (Result Http.Error (List PortionInBatch))
    | GotHistory (Result Http.Error (List HistoryPoint))
    | FormNameChanged String
    | FormCategoryChanged String
    | FormContainerChanged String
    | FormIngredientsChanged String
    | FormQuantityChanged String
    | FormCreatedAtChanged String
    | FormExpiryDateChanged String
    | SubmitBatchOnly
    | SubmitBatchWithPrint
    | GotUuidsForBatch (List UUID)
    | BatchCreated (Result Http.Error CreateBatchResponse)
    | PrintLabelForPortion PortionPrintData
    | PrintResult String (Result Http.Error ())
    | ReprintPortion PortionInBatch
    | ReprintAllFrozen
    | NavigateToBatch String
    | ConsumePortion String
    | PortionConsumed (Result Http.Error ())
    | DismissNotification
    | OpenPreviewModal PortionPrintData
    | ClosePreviewModal


type alias PortionPrintData =
    { portionId : String
    , name : String
    , ingredients : String
    , containerId : String
    , expiryDate : String
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            let
                route =
                    parseUrl url

                cmd =
                    case route of
                        ItemDetail portionId ->
                            fetchPortionDetail portionId

                        BatchDetail batchId ->
                            Cmd.batch [ fetchBatches, fetchBatchPortions batchId ]

                        History ->
                            fetchHistory

                        Dashboard ->
                            fetchBatches

                        _ ->
                            Cmd.none
            in
            ( { model | url = url, route = route, portionDetail = Nothing, batchDetail = Nothing }, cmd )

        GotCategories result ->
            case result of
                Ok categories ->
                    let
                        form =
                            model.form

                        newForm =
                            if form.categoryId == "" && not (List.isEmpty categories) then
                                { form | categoryId = Maybe.withDefault "" (Maybe.map .name (List.head categories)) }

                            else
                                form
                    in
                    ( { model | categories = categories, form = newForm }, Cmd.none )

                Err _ ->
                    ( { model | error = Just "Failed to load categories" }, Cmd.none )

        GotContainerTypes result ->
            case result of
                Ok containerTypes ->
                    let
                        form =
                            model.form

                        newForm =
                            if form.containerId == "" && not (List.isEmpty containerTypes) then
                                { form | containerId = Maybe.withDefault "" (Maybe.map .name (List.head containerTypes)) }

                            else
                                form
                    in
                    ( { model | containerTypes = containerTypes, form = newForm, loading = False }, Cmd.none )

                Err _ ->
                    ( { model | error = Just "Failed to load container types", loading = False }, Cmd.none )

        GotBatches result ->
            case result of
                Ok batches ->
                    ( { model | batches = batches, loading = False }, Cmd.none )

                Err _ ->
                    ( { model | error = Just "Failed to load batches", loading = False }, Cmd.none )

        GotPortionDetail result ->
            case result of
                Ok detail ->
                    ( { model | portionDetail = Just detail, loading = False }, Cmd.none )

                Err _ ->
                    ( { model | error = Just "Failed to load portion details", loading = False }, Cmd.none )

        GotHistory result ->
            case result of
                Ok history ->
                    ( { model | historyData = history, loading = False }, Cmd.none )

                Err _ ->
                    ( { model | error = Just "Failed to load history", loading = False }, Cmd.none )

        FormNameChanged name ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | name = name } }, Cmd.none )

        FormCategoryChanged categoryId ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | categoryId = categoryId } }, Cmd.none )

        FormContainerChanged containerId ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | containerId = containerId } }, Cmd.none )

        FormIngredientsChanged ingredients ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | ingredients = ingredients } }, Cmd.none )

        FormQuantityChanged quantity ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | quantity = quantity } }, Cmd.none )

        FormCreatedAtChanged createdAt ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | createdAt = createdAt } }, Cmd.none )

        FormExpiryDateChanged expiryDate ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | expiryDate = expiryDate } }, Cmd.none )

        SubmitBatchOnly ->
            let
                quantity =
                    Maybe.withDefault 1 (String.toInt model.form.quantity)

                -- Generate 1 UUID for batch + N UUIDs for portions
                uuidCount =
                    1 + quantity
            in
            ( { model | loading = True, printWithSave = False }
            , Random.generate GotUuidsForBatch (Random.list uuidCount UUID.generator)
            )

        SubmitBatchWithPrint ->
            let
                quantity =
                    Maybe.withDefault 1 (String.toInt model.form.quantity)

                uuidCount =
                    1 + quantity
            in
            ( { model | loading = True, printWithSave = True }
            , Random.generate GotUuidsForBatch (Random.list uuidCount UUID.generator)
            )

        GotUuidsForBatch uuids ->
            case uuids of
                batchUuid :: portionUuids ->
                    ( model
                    , createBatch model.form batchUuid portionUuids
                    )

                [] ->
                    -- Should never happen
                    ( { model | loading = False, error = Just "Failed to generate UUIDs" }
                    , Cmd.none
                    )

        BatchCreated result ->
            case result of
                Ok response ->
                    if model.printWithSave then
                        let
                            quantity =
                                List.length response.portionIds

                            printData =
                                List.map
                                    (\portionId ->
                                        { portionId = portionId
                                        , name = model.form.name
                                        , ingredients = model.form.ingredients
                                        , containerId = model.form.containerId
                                        , expiryDate = model.form.expiryDate
                                        }
                                    )
                                    response.portionIds

                            printCommands =
                                List.map printLabel printData
                        in
                        ( { model
                            | form = emptyForm model.currentDate
                            , loading = False
                            , notification = Just { message = "Batch created! Printing " ++ String.fromInt quantity ++ " labels...", notificationType = Info }
                            , printingProgress = Just { total = quantity, completed = 0, failed = 0 }
                          }
                        , Cmd.batch (printCommands ++ [ Nav.pushUrl model.key "/" ])
                        )

                    else
                        ( { model
                            | form = emptyForm model.currentDate
                            , loading = False
                            , notification = Just { message = "Batch guardado correctamente", notificationType = Success }
                          }
                        , Nav.pushUrl model.key ("/batch/" ++ response.batchId)
                        )

                Err _ ->
                    ( { model
                        | loading = False
                        , notification = Just { message = "Failed to create batch", notificationType = Error }
                      }
                    , Cmd.none
                    )

        PrintLabelForPortion data ->
            ( { model | notification = Just { message = "Printing label...", notificationType = Info } }
            , printLabel data
            )

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

                notification =
                    if allDone then
                        case newProgress of
                            Just p ->
                                if p.failed > 0 then
                                    Just { message = String.fromInt p.completed ++ " labels printed, " ++ String.fromInt p.failed ++ " failed", notificationType = Error }

                                else
                                    Just { message = String.fromInt p.completed ++ " labels printed successfully!", notificationType = Success }

                            Nothing ->
                                model.notification

                    else
                        model.notification

                finalProgress =
                    if allDone then
                        Nothing

                    else
                        newProgress
            in
            ( { model | printingProgress = finalProgress, notification = notification }
            , if allDone then
                fetchBatches

              else
                Cmd.none
            )

        ConsumePortion portionId ->
            ( { model | loading = True }, consumePortion portionId )

        PortionConsumed result ->
            case result of
                Ok _ ->
                    ( { model
                        | loading = False
                        , notification = Just { message = "Portion marked as consumed!", notificationType = Success }
                      }
                    , case model.portionDetail of
                        Just detail ->
                            fetchPortionDetail detail.portionId

                        Nothing ->
                            Cmd.none
                    )

                Err _ ->
                    ( { model
                        | loading = False
                        , notification = Just { message = "Failed to consume portion", notificationType = Error }
                      }
                    , Cmd.none
                    )

        DismissNotification ->
            ( { model | notification = Nothing }, Cmd.none )

        OpenPreviewModal portionPrintData ->
            ( { model | previewModal = Just portionPrintData }, Cmd.none )

        ClosePreviewModal ->
            ( { model | previewModal = Nothing }, Cmd.none )

        GotBatchPortions result ->
            case result of
                Ok portions ->
                    let
                        -- Find the batch from model.batches using the URL
                        maybeBatchId =
                            case model.route of
                                BatchDetail batchId ->
                                    Just batchId

                                _ ->
                                    Nothing

                        maybeBatch =
                            maybeBatchId
                                |> Maybe.andThen
                                    (\batchId ->
                                        List.filter (\b -> b.batchId == batchId) model.batches
                                            |> List.head
                                    )

                        newBatchDetail =
                            maybeBatch
                                |> Maybe.map (\batch -> { batch = batch, portions = portions })
                    in
                    ( { model | batchDetail = newBatchDetail, loading = False }, Cmd.none )

                Err _ ->
                    ( { model | error = Just "Failed to load batch portions", loading = False }, Cmd.none )

        NavigateToBatch batchId ->
            ( model, Nav.pushUrl model.key ("/batch/" ++ batchId) )

        ReprintPortion portion ->
            case model.batchDetail of
                Just batchData ->
                    let
                        printData =
                            { portionId = portion.portionId
                            , name = batchData.batch.name
                            , ingredients = batchData.batch.ingredients
                            , containerId = batchData.batch.containerId
                            , expiryDate = portion.expiryDate
                            }
                    in
                    ( { model
                        | notification = Just { message = "Imprimiendo etiqueta...", notificationType = Info }
                        , printingProgress = Just { total = 1, completed = 0, failed = 0 }
                      }
                    , printLabel printData
                    )

                Nothing ->
                    ( model, Cmd.none )

        ReprintAllFrozen ->
            case model.batchDetail of
                Just batchData ->
                    let
                        frozenPortions =
                            List.filter (\p -> p.status == "FROZEN") batchData.portions

                        quantity =
                            List.length frozenPortions

                        printData =
                            List.map
                                (\portion ->
                                    { portionId = portion.portionId
                                    , name = batchData.batch.name
                                    , ingredients = batchData.batch.ingredients
                                    , containerId = batchData.batch.containerId
                                    , expiryDate = portion.expiryDate
                                    }
                                )
                                frozenPortions

                        printCommands =
                            List.map printLabel printData
                    in
                    if quantity > 0 then
                        ( { model
                            | notification = Just { message = "Imprimiendo " ++ String.fromInt quantity ++ " etiquetas...", notificationType = Info }
                            , printingProgress = Just { total = quantity, completed = 0, failed = 0 }
                          }
                        , Cmd.batch printCommands
                        )

                    else
                        ( { model | notification = Just { message = "No hay porciones congeladas para imprimir", notificationType = Info } }
                        , Cmd.none
                        )

                Nothing ->
                    ( model, Cmd.none )



-- HTTP


fetchCategories : Cmd Msg
fetchCategories =
    Http.get
        { url = "/api/db/category"
        , expect = Http.expectJson GotCategories (Decode.list categoryDecoder)
        }


fetchContainerTypes : Cmd Msg
fetchContainerTypes =
    Http.get
        { url = "/api/db/container_type"
        , expect = Http.expectJson GotContainerTypes (Decode.list containerTypeDecoder)
        }


fetchBatches : Cmd Msg
fetchBatches =
    Http.get
        { url = "/api/db/batch_summary?frozen_count=gt.0&order=expiry_date.asc"
        , expect = Http.expectJson GotBatches (Decode.list batchSummaryDecoder)
        }


fetchPortionDetail : String -> Cmd Msg
fetchPortionDetail portionId =
    Http.get
        { url = "/api/db/portion_detail?portion_id=eq." ++ portionId
        , expect = Http.expectJson GotPortionDetail (Decode.index 0 portionDetailDecoder)
        }


fetchHistory : Cmd Msg
fetchHistory =
    Http.get
        { url = "/api/db/freezer_history"
        , expect = Http.expectJson GotHistory (Decode.list historyPointDecoder)
        }


fetchBatchPortions : String -> Cmd Msg
fetchBatchPortions batchId =
    Http.get
        { url = "/api/db/portion?batch_id=eq." ++ batchId ++ "&order=created_at.asc"
        , expect = Http.expectJson GotBatchPortions (Decode.list portionInBatchDecoder)
        }


createBatch : BatchForm -> UUID -> List UUID -> Cmd Msg
createBatch form batchUuid portionUuids =
    let
        body =
            Encode.object
                ([ ( "p_batch_id", Encode.string (UUID.toString batchUuid) )
                 , ( "p_portion_ids", Encode.list (Encode.string << UUID.toString) portionUuids )
                 , ( "p_name", Encode.string form.name )
                 , ( "p_category_id", Encode.string form.categoryId )
                 , ( "p_container_id", Encode.string form.containerId )
                 , ( "p_ingredients", Encode.string form.ingredients )
                 , ( "p_created_at", Encode.string form.createdAt )
                 ]
                    ++ (if form.expiryDate /= "" then
                            [ ( "p_expiry_date", Encode.string form.expiryDate ) ]

                        else
                            []
                       )
                )
    in
    Http.post
        { url = "/api/db/rpc/create_batch"
        , body = Http.jsonBody body
        , expect = Http.expectJson BatchCreated createBatchResponseDecoder
        }


printLabel : PortionPrintData -> Cmd Msg
printLabel data =
    let
        body =
            Encode.object
                [ ( "id", Encode.string data.portionId )
                , ( "name", Encode.string data.name )
                , ( "ingredients", Encode.string data.ingredients )
                , ( "container", Encode.string data.containerId )
                , ( "expiry_date", Encode.string data.expiryDate )
                ]
    in
    Http.post
        { url = "/api/printer/print"
        , body = Http.jsonBody body
        , expect = Http.expectWhatever (PrintResult data.portionId)
        }


consumePortion : String -> Cmd Msg
consumePortion portionId =
    let
        body =
            Encode.object
                [ ( "status", Encode.string "CONSUMED" )
                , ( "consumed_at", Encode.string "now()" )
                ]
    in
    Http.request
        { method = "PATCH"
        , headers = []
        , url = "/api/db/portion?id=eq." ++ portionId
        , body = Http.jsonBody body
        , expect = Http.expectWhatever PortionConsumed
        , timeout = Nothing
        , tracker = Nothing
        }



-- DECODERS


categoryDecoder : Decoder Category
categoryDecoder =
    Decode.map2 Category
        (Decode.field "name" Decode.string)
        (Decode.field "safe_days" Decode.int)


containerTypeDecoder : Decoder ContainerType
containerTypeDecoder =
    Decode.map2 ContainerType
        (Decode.field "name" Decode.string)
        (Decode.field "servings_per_unit" Decode.float)


batchSummaryDecoder : Decoder BatchSummary
batchSummaryDecoder =
    Decode.succeed BatchSummary
        |> andMap (Decode.field "batch_id" Decode.string)
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "category_id" Decode.string)
        |> andMap (Decode.field "container_id" Decode.string)
        |> andMap (Decode.field "ingredients" Decode.string)
        |> andMap (Decode.field "batch_created_at" Decode.string)
        |> andMap (Decode.field "expiry_date" Decode.string)
        |> andMap (Decode.field "frozen_count" Decode.int)
        |> andMap (Decode.field "consumed_count" Decode.int)
        |> andMap (Decode.field "total_count" Decode.int)


andMap : Decoder a -> Decoder (a -> b) -> Decoder b
andMap =
    Decode.map2 (|>)


portionDetailDecoder : Decoder PortionDetail
portionDetailDecoder =
    Decode.succeed PortionDetail
        |> andMap (Decode.field "portion_id" Decode.string)
        |> andMap (Decode.field "batch_id" Decode.string)
        |> andMap (Decode.field "created_at" Decode.string)
        |> andMap (Decode.field "expiry_date" Decode.string)
        |> andMap (Decode.field "status" Decode.string)
        |> andMap (Decode.field "consumed_at" (Decode.nullable Decode.string))
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "category_id" Decode.string)
        |> andMap (Decode.field "container_id" Decode.string)
        |> andMap (Decode.field "ingredients" Decode.string)


createBatchResponseDecoder : Decoder CreateBatchResponse
createBatchResponseDecoder =
    Decode.index 0
        (Decode.map2 CreateBatchResponse
            (Decode.field "batch_id" Decode.string)
            (Decode.field "portion_ids" (Decode.list Decode.string))
        )


historyPointDecoder : Decoder HistoryPoint
historyPointDecoder =
    Decode.map4 HistoryPoint
        (Decode.field "date" Decode.string)
        (Decode.field "added" Decode.int)
        (Decode.field "consumed" Decode.int)
        (Decode.field "frozen_total" Decode.int)


portionInBatchDecoder : Decoder PortionInBatch
portionInBatchDecoder =
    Decode.map5 PortionInBatch
        (Decode.field "id" Decode.string)
        (Decode.field "status" Decode.string)
        (Decode.field "created_at" Decode.string)
        (Decode.field "expiry_date" Decode.string)
        (Decode.field "consumed_at" (Decode.nullable Decode.string))



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "FrostByte"
    , body =
        [ div [ class "min-h-screen bg-gray-100" ]
            [ viewHeader model
            , viewNotification model.notification
            , viewPrintingProgress model.printingProgress
            , viewPreviewModal model.previewModal
            , main_ [ class "container mx-auto px-4 py-8" ]
                [ case model.route of
                    Dashboard ->
                        viewDashboard model

                    NewBatch ->
                        viewNewBatchForm model

                    ItemDetail _ ->
                        viewItemDetail model

                    BatchDetail _ ->
                        viewBatchDetail model

                    History ->
                        viewHistory model

                    NotFound ->
                        viewNotFound
                ]
            ]
        ]
    }


viewHeader : Model -> Html Msg
viewHeader model =
    header [ class "bg-frost-600 text-white shadow-lg" ]
        [ div [ class "container mx-auto px-4 py-4" ]
            [ div [ class "flex items-center justify-between" ]
                [ a [ href "/", class "flex items-center space-x-2" ]
                    [ span [ class "text-3xl" ] [ text "❄️" ]
                    , span [ class "text-2xl font-bold" ] [ text "FrostByte" ]
                    ]
                , nav [ class "flex space-x-4" ]
                    [ a
                        [ href "/"
                        , class
                            (if model.route == Dashboard then
                                "bg-frost-700 px-4 py-2 rounded-lg"

                             else
                                "hover:bg-frost-700 px-4 py-2 rounded-lg transition-colors"
                            )
                        ]
                        [ text "Inventario" ]
                    , a
                        [ href "/new"
                        , class
                            (if model.route == NewBatch then
                                "bg-frost-700 px-4 py-2 rounded-lg"

                             else
                                "hover:bg-frost-700 px-4 py-2 rounded-lg transition-colors"
                            )
                        ]
                        [ text "+ Nuevo" ]
                    , a
                        [ href "/history"
                        , class
                            (if model.route == History then
                                "bg-frost-700 px-4 py-2 rounded-lg"

                             else
                                "hover:bg-frost-700 px-4 py-2 rounded-lg transition-colors"
                            )
                        ]
                        [ text "Historial" ]
                    ]
                ]
            ]
        ]


viewNotification : Maybe Notification -> Html Msg
viewNotification maybeNotification =
    case maybeNotification of
        Just notification ->
            let
                bgColor =
                    case notification.notificationType of
                        Success ->
                            "bg-green-500"

                        Error ->
                            "bg-red-500"

                        Info ->
                            "bg-blue-500"
            in
            div [ class ("fixed top-20 right-4 z-50 " ++ bgColor ++ " text-white px-6 py-3 rounded-lg shadow-lg flex items-center space-x-4") ]
                [ span [] [ text notification.message ]
                , button [ onClick DismissNotification, class "text-white hover:text-gray-200" ] [ text "✕" ]
                ]

        Nothing ->
            text ""


viewPrintingProgress : Maybe PrintingProgress -> Html Msg
viewPrintingProgress maybeProgress =
    case maybeProgress of
        Just progress ->
            div [ class "fixed bottom-4 right-4 z-50 bg-white p-4 rounded-lg shadow-lg" ]
                [ div [ class "text-sm text-gray-600 mb-2" ]
                    [ text ("Printing: " ++ String.fromInt progress.completed ++ "/" ++ String.fromInt progress.total) ]
                , div [ class "w-48 bg-gray-200 rounded-full h-2" ]
                    [ div
                        [ class "bg-frost-500 h-2 rounded-full transition-all"
                        , style "width" (String.fromFloat (toFloat progress.completed / toFloat progress.total * 100) ++ "%")
                        ]
                        []
                    ]
                ]

        Nothing ->
            text ""


viewPreviewModal : Maybe PortionPrintData -> Html Msg
viewPreviewModal maybePreview =
    case maybePreview of
        Just portionData ->
            let
                previewUrl =
                    Url.Builder.absolute [ "api", "printer", "preview" ]
                        [ Url.Builder.string "id" portionData.portionId
                        , Url.Builder.string "name" portionData.name
                        , Url.Builder.string "ingredients" portionData.ingredients
                        , Url.Builder.string "container" portionData.containerId
                        , Url.Builder.string "expiry_date" portionData.expiryDate
                        ]
            in
            div [ class "fixed inset-0 z-50 flex items-center justify-center" ]
                [ div
                    [ class "absolute inset-0 bg-black bg-opacity-50"
                    , onClick ClosePreviewModal
                    ]
                    []
                , div [ class "relative bg-white rounded-xl shadow-2xl max-w-3xl w-full mx-4 overflow-hidden" ]
                    [ div [ class "flex justify-between items-center px-6 py-4 border-b" ]
                        [ h3 [ class "text-lg font-semibold text-gray-800" ]
                            [ text "Vista previa de etiqueta" ]
                        , button
                            [ onClick ClosePreviewModal
                            , class "text-gray-400 hover:text-gray-600 text-2xl font-bold"
                            ]
                            [ text "×" ]
                        ]
                    , div [ class "p-6 flex justify-center" ]
                        [ img
                            [ Attr.src previewUrl
                            , Attr.alt "Vista previa de la etiqueta"
                            , class "max-w-full border border-gray-200 rounded shadow-sm"
                            ]
                            []
                        ]
                    , div [ class "flex justify-end px-6 py-4 bg-gray-50 border-t" ]
                        [ button
                            [ onClick ClosePreviewModal
                            , class "px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-medium"
                            ]
                            [ text "Cerrar" ]
                        ]
                    ]
                ]

        Nothing ->
            text ""


viewDashboard : Model -> Html Msg
viewDashboard model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Inventario del Congelador" ]
        , if model.loading then
            div [ class "text-center py-12" ]
                [ div [ class "animate-spin inline-block w-8 h-8 border-4 border-frost-500 border-t-transparent rounded-full" ] []
                , p [ class "mt-4 text-gray-600" ] [ text "Cargando..." ]
                ]

          else if List.isEmpty model.batches then
            div [ class "card text-center py-12" ]
                [ span [ class "text-6xl" ] [ text "❄️" ]
                , p [ class "mt-4 text-gray-600" ] [ text "No hay porciones en el congelador" ]
                , a [ href "/new", class "btn-primary inline-block mt-4" ] [ text "Añadir primera porción" ]
                ]

          else
            viewBatchesTable model
        ]


viewBatchesTable : Model -> Html Msg
viewBatchesTable model =
    let
        totalServings batch =
            let
                container =
                    List.filter (\c -> c.name == batch.containerId) model.containerTypes
                        |> List.head
                        |> Maybe.map .servingsPerUnit
                        |> Maybe.withDefault 1.0
            in
            toFloat batch.frozenCount * container
    in
    div [ class "card overflow-hidden" ]
        [ div [ class "overflow-x-auto" ]
            [ table [ class "w-full" ]
                [ thead [ class "bg-gray-50" ]
                    [ tr []
                        [ th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Nombre" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Categoría" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Envase" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Congeladas" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Raciones" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Caduca" ]
                        ]
                    ]
                , tbody [ class "divide-y divide-gray-200" ]
                    (List.map
                        (\batch ->
                            tr
                                [ class "hover:bg-gray-50 cursor-pointer"
                                , onClick (NavigateToBatch batch.batchId)
                                ]
                                [ td [ class "px-4 py-3 font-medium text-gray-900" ] [ text batch.name ]
                                , td [ class "px-4 py-3 text-gray-600" ]
                                    [ span [ class "inline-block bg-frost-100 text-frost-700 px-2 py-1 rounded text-sm" ]
                                        [ text batch.categoryId ]
                                    ]
                                , td [ class "px-4 py-3 text-gray-600 text-sm" ] [ text batch.containerId ]
                                , td [ class "px-4 py-3 text-gray-600" ]
                                    [ span [ class "font-semibold text-frost-600" ] [ text (String.fromInt batch.frozenCount) ]
                                    , span [ class "text-gray-400" ] [ text (" / " ++ String.fromInt batch.totalCount) ]
                                    ]
                                , td [ class "px-4 py-3 text-gray-600" ]
                                    [ text (String.fromFloat (totalServings batch)) ]
                                , td [ class "px-4 py-3" ]
                                    [ span [ class "text-gray-900 font-medium" ] [ text batch.expiryDate ]
                                    ]
                                ]
                        )
                        model.batches
                    )
                ]
            ]
        , div [ class "bg-gray-50 px-4 py-3 text-sm text-gray-500" ]
            [ text "Para consumir una porción, escanea el código QR de su etiqueta" ]
        ]


viewNewBatchForm : Model -> Html Msg
viewNewBatchForm model =
    div [ class "max-w-2xl mx-auto" ]
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Añadir Nuevas Porciones" ]
        , div [ class "card" ]
            [ Html.form [ onSubmit SubmitBatchWithPrint, class "space-y-6" ]
                [ div []
                    [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Nombre" ]
                    , input
                        [ type_ "text"
                        , class "input-field"
                        , placeholder "Ej: Arroz Japonés Sushi"
                        , value model.form.name
                        , onInput FormNameChanged
                        , required True
                        ]
                        []
                    ]
                , div [ class "grid grid-cols-2 gap-4" ]
                    [ div []
                        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Categoría" ]
                        , select
                            [ class "input-field"
                            , onInput FormCategoryChanged
                            , value model.form.categoryId
                            ]
                            (List.map
                                (\cat ->
                                    option [ value cat.name, selected (cat.name == model.form.categoryId) ]
                                        [ text (cat.name ++ " (" ++ String.fromInt cat.safeDays ++ " días)") ]
                                )
                                model.categories
                            )
                        ]
                    , div []
                        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Tipo de Envase" ]
                        , select
                            [ class "input-field"
                            , onInput FormContainerChanged
                            , value model.form.containerId
                            ]
                            (List.map
                                (\cont ->
                                    option [ value cont.name, selected (cont.name == model.form.containerId) ]
                                        [ text cont.name ]
                                )
                                model.containerTypes
                            )
                        ]
                    ]
                , div []
                    [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Ingredientes" ]
                    , input
                        [ type_ "text"
                        , class "input-field"
                        , placeholder "Ej: arroz, agua, sal, vinagre"
                        , value model.form.ingredients
                        , onInput FormIngredientsChanged
                        ]
                        []
                    , p [ class "text-xs text-gray-500 mt-1" ] [ text "Se imprimirán en la etiqueta" ]
                    ]
                , div []
                    [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Cantidad de Porciones" ]
                    , input
                        [ type_ "number"
                        , class "input-field"
                        , Attr.min "1"
                        , value model.form.quantity
                        , onInput FormQuantityChanged
                        , required True
                        ]
                        []
                    , p [ class "text-xs text-gray-500 mt-1" ] [ text "Se imprimirá una etiqueta por cada porción" ]
                    ]
                , div [ class "grid grid-cols-2 gap-4" ]
                    [ div []
                        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Fecha de Congelación" ]
                        , input
                            [ type_ "date"
                            , class "input-field"
                            , value model.form.createdAt
                            , onInput FormCreatedAtChanged
                            , required True
                            ]
                            []
                        ]
                    , div []
                        [ label [ class "block text-sm font-medium text-gray-700 mb-1" ] [ text "Fecha de Caducidad (opcional)" ]
                        , input
                            [ type_ "date"
                            , class "input-field"
                            , value model.form.expiryDate
                            , onInput FormExpiryDateChanged
                            ]
                            []
                        , p [ class "text-xs text-gray-500 mt-1" ] [ text "Se calculará automáticamente si se deja en blanco" ]
                        ]
                    ]
                , div [ class "flex justify-end space-x-4 pt-4" ]
                    [ a [ href "/", class "btn-secondary" ] [ text "Cancelar" ]
                    , button
                        [ type_ "button"
                        , class "px-6 py-2 bg-gray-500 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors"
                        , disabled model.loading
                        , onClick SubmitBatchOnly
                        ]
                        [ if model.loading then
                            text "Guardando..."

                          else
                            text "Guardar"
                        ]
                    , button
                        [ type_ "submit"
                        , class "btn-primary"
                        , disabled model.loading
                        ]
                        [ if model.loading then
                            text "Guardando..."

                          else
                            text "Guardar e Imprimir"
                        ]
                    ]
                ]
            ]
        ]


viewItemDetail : Model -> Html Msg
viewItemDetail model =
    case model.portionDetail of
        Nothing ->
            if model.loading then
                div [ class "text-center py-12" ]
                    [ div [ class "animate-spin inline-block w-8 h-8 border-4 border-frost-500 border-t-transparent rounded-full" ] []
                    , p [ class "mt-4 text-gray-600" ] [ text "Cargando..." ]
                    ]

            else
                div [ class "text-center py-12" ]
                    [ span [ class "text-6xl" ] [ text "❓" ]
                    , h1 [ class "text-3xl font-bold text-gray-800 mt-4" ] [ text "Porción no encontrada" ]
                    , a [ href "/", class "btn-primary inline-block mt-4" ] [ text "Volver al inicio" ]
                    ]

        Just portion ->
            div [ class "max-w-lg mx-auto" ]
                [ div [ class "card text-center" ]
                    [ if portion.status == "CONSUMED" then
                        div []
                            [ span [ class "text-6xl" ] [ text "✅" ]
                            , h1 [ class "text-2xl font-bold text-gray-800 mt-4" ] [ text "Porción ya consumida" ]
                            , p [ class "text-gray-500 mt-2" ]
                                [ text ("Consumida el: " ++ Maybe.withDefault "?" portion.consumedAt) ]
                            ]

                      else
                        div []
                            [ span [ class "text-6xl" ] [ text "❄️" ]
                            , h1 [ class "text-2xl font-bold text-gray-800 mt-4" ] [ text portion.name ]
                            ]
                    , div [ class "mt-6 space-y-3 text-left" ]
                        [ div [ class "flex justify-between py-2 border-b" ]
                            [ span [ class "text-gray-500" ] [ text "Categoría" ]
                            , span [ class "font-medium" ] [ text portion.categoryId ]
                            ]
                        , div [ class "flex justify-between py-2 border-b" ]
                            [ span [ class "text-gray-500" ] [ text "Envase" ]
                            , span [ class "font-medium" ] [ text portion.containerId ]
                            ]
                        , div [ class "flex justify-between py-2 border-b" ]
                            [ span [ class "text-gray-500" ] [ text "Congelado" ]
                            , span [ class "font-medium" ] [ text portion.createdAt ]
                            ]
                        , div [ class "flex justify-between py-2 border-b" ]
                            [ span [ class "text-gray-500" ] [ text "Caduca" ]
                            , span [ class "font-medium" ] [ text portion.expiryDate ]
                            ]
                        , div [ class "flex justify-between py-2" ]
                            [ span [ class "text-gray-500" ] [ text "Estado" ]
                            , span
                                [ class
                                    (if portion.status == "FROZEN" then
                                        "font-medium text-frost-600"

                                     else
                                        "font-medium text-green-600"
                                    )
                                ]
                                [ text
                                    (if portion.status == "FROZEN" then
                                        "Congelada"

                                     else
                                        "Consumida"
                                    )
                                ]
                            ]
                        ]
                    , if portion.status == "FROZEN" then
                        div [ class "mt-8" ]
                            [ button
                                [ onClick (ConsumePortion portion.portionId)
                                , class "w-full bg-green-500 hover:bg-green-600 text-white font-bold py-4 px-6 rounded-lg text-lg transition-colors"
                                , disabled model.loading
                                ]
                                [ if model.loading then
                                    text "Procesando..."

                                  else
                                    text "🍽️ Confirmar Consumo"
                                ]
                            ]

                      else
                        text ""
                    , div [ class "mt-4" ]
                        [ a [ href "/", class "text-frost-600 hover:text-frost-800" ] [ text "← Volver al inventario" ]
                        ]
                    ]
                ]


viewBatchDetail : Model -> Html Msg
viewBatchDetail model =
    case model.batchDetail of
        Nothing ->
            if model.loading then
                div [ class "text-center py-12" ]
                    [ div [ class "animate-spin inline-block w-8 h-8 border-4 border-frost-500 border-t-transparent rounded-full" ] []
                    , p [ class "mt-4 text-gray-600" ] [ text "Cargando..." ]
                    ]

            else
                div [ class "text-center py-12" ]
                    [ span [ class "text-6xl" ] [ text "❓" ]
                    , h1 [ class "text-3xl font-bold text-gray-800 mt-4" ] [ text "Batch no encontrado" ]
                    , a [ href "/", class "btn-primary inline-block mt-4" ] [ text "Volver al inicio" ]
                    ]

        Just batchData ->
            let
                frozenCount =
                    List.filter (\p -> p.status == "FROZEN") batchData.portions
                        |> List.length
            in
            div [ class "max-w-4xl mx-auto" ]
                [ -- Header with batch info
                  div [ class "card mb-6" ]
                    [ div [ class "flex justify-between items-start" ]
                        [ div []
                            [ h1 [ class "text-2xl font-bold text-gray-800" ] [ text batchData.batch.name ]
                            , p [ class "text-gray-600 mt-1" ]
                                [ span [ class "inline-block bg-frost-100 text-frost-700 px-2 py-1 rounded text-sm mr-2" ]
                                    [ text batchData.batch.categoryId ]
                                , text batchData.batch.containerId
                                ]
                            , p [ class "text-gray-500 mt-2" ]
                                [ text ("Caduca: " ++ batchData.batch.expiryDate) ]
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

                -- Portions table
                , div [ class "card overflow-hidden" ]
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
                                (List.indexedMap (viewPortionRow batchData.batch) batchData.portions)
                            ]
                        ]
                    ]

                -- Back link
                , div [ class "mt-6" ]
                    [ a [ href "/", class "text-frost-600 hover:text-frost-800" ] [ text "← Volver al inventario" ]
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
                    [ button
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
                span [ class "text-gray-400" ] [ text "—" ]
            ]
        ]


viewHistory : Model -> Html Msg
viewHistory model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Historial del Congelador" ]
        , if model.loading then
            div [ class "text-center py-12" ]
                [ div [ class "animate-spin inline-block w-8 h-8 border-4 border-frost-500 border-t-transparent rounded-full" ] []
                , p [ class "mt-4 text-gray-600" ] [ text "Cargando..." ]
                ]

          else if List.isEmpty model.historyData then
            div [ class "card text-center py-12" ]
                [ span [ class "text-6xl" ] [ text "📊" ]
                , p [ class "mt-4 text-gray-600" ] [ text "No hay datos de historial todavía" ]
                ]

          else
            div []
                [ viewHistoryChart model.historyData
                , viewHistoryTable model.historyData
                ]
        ]


viewHistoryChart : List HistoryPoint -> Html Msg
viewHistoryChart history =
    let
        maxFrozen =
            List.map .frozenTotal history
                |> List.maximum
                |> Maybe.withDefault 1
                |> max 1

        chartHeight =
            200

        chartWidth =
            800

        barWidth =
            max 10 (chartWidth // max 1 (List.length history) - 4)

        bars =
            List.indexedMap
                (\i point ->
                    let
                        barHeight =
                            toFloat point.frozenTotal / toFloat maxFrozen * toFloat chartHeight

                        x =
                            i * (barWidth + 4) + 2
                    in
                    rect
                        [ SvgAttr.x (String.fromInt x)
                        , SvgAttr.y (String.fromFloat (toFloat chartHeight - barHeight))
                        , SvgAttr.width (String.fromInt barWidth)
                        , SvgAttr.height (String.fromFloat barHeight)
                        , SvgAttr.fill "#0ea5e9"
                        , SvgAttr.rx "2"
                        ]
                        []
                )
                history
    in
    div [ class "card mb-6" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ] [ text "Porciones en el congelador" ]
        , div [ class "overflow-x-auto" ]
            [ svg
                [ SvgAttr.viewBox ("0 0 " ++ String.fromInt (List.length history * (barWidth + 4) + 4) ++ " " ++ String.fromInt (chartHeight + 20))
                , SvgAttr.class "w-full h-48"
                ]
                bars
            ]
        ]


viewHistoryTable : List HistoryPoint -> Html Msg
viewHistoryTable history =
    div [ class "card overflow-hidden" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 p-4 border-b" ] [ text "Detalle diario" ]
        , div [ class "overflow-x-auto max-h-64" ]
            [ table [ class "w-full" ]
                [ thead [ class "bg-gray-50 sticky top-0" ]
                    [ tr []
                        [ th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Fecha" ]
                        , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Añadidas" ]
                        , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Consumidas" ]
                        , th [ class "px-4 py-2 text-left text-sm font-semibold text-gray-600" ] [ text "Total congelado" ]
                        ]
                    ]
                , tbody [ class "divide-y divide-gray-200" ]
                    (List.map
                        (\point ->
                            tr [ class "hover:bg-gray-50" ]
                                [ td [ class "px-4 py-2 text-gray-900" ] [ text point.date ]
                                , td [ class "px-4 py-2 text-green-600" ] [ text ("+" ++ String.fromInt point.added) ]
                                , td [ class "px-4 py-2 text-red-600" ] [ text ("-" ++ String.fromInt point.consumed) ]
                                , td [ class "px-4 py-2 font-semibold text-frost-600" ] [ text (String.fromInt point.frozenTotal) ]
                                ]
                        )
                        (List.reverse history)
                    )
                ]
            ]
        ]


viewNotFound : Html Msg
viewNotFound =
    div [ class "text-center py-12" ]
        [ span [ class "text-6xl" ] [ text "❄️" ]
        , h1 [ class "text-3xl font-bold text-gray-800 mt-4" ] [ text "Página no encontrada" ]
        , p [ class "text-gray-600 mt-2" ] [ text "La página que buscas no existe" ]
        , a [ href "/", class "btn-primary inline-block mt-4" ] [ text "Volver al inicio" ]
        ]
