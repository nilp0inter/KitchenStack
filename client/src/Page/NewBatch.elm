module Page.NewBatch exposing
    ( Model
    , Msg
    , OutMsg(..)
    , init
    , update
    , view
    )

import Api
import Html exposing (..)
import Html.Attributes as Attr exposing (class, disabled, href, placeholder, required, selected, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Random
import Types exposing (..)
import UUID exposing (UUID)


type alias Model =
    { form : BatchForm
    , categories : List Category
    , containerTypes : List ContainerType
    , loading : Bool
    , printWithSave : Bool
    , printingProgress : Maybe PrintingProgress
    }


type Msg
    = FormNameChanged String
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
    | PrintResult String (Result Http.Error ())


type OutMsg
    = NoOp
    | ShowNotification Notification
    | NavigateToHome
    | NavigateToBatch String
    | RefreshBatches


init : String -> List Category -> List ContainerType -> ( Model, Cmd Msg )
init currentDate categories containerTypes =
    let
        form =
            emptyBatchForm currentDate

        formWithDefaults =
            { form
                | categoryId =
                    List.head categories
                        |> Maybe.map .name
                        |> Maybe.withDefault ""
                , containerId =
                    List.head containerTypes
                        |> Maybe.map .name
                        |> Maybe.withDefault ""
            }
    in
    ( { form = formWithDefaults
      , categories = categories
      , containerTypes = containerTypes
      , loading = False
      , printWithSave = True
      , printingProgress = Nothing
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
            in
            ( { model | form = { form | name = name } }, Cmd.none, NoOp )

        FormCategoryChanged categoryId ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | categoryId = categoryId } }, Cmd.none, NoOp )

        FormContainerChanged containerId ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | containerId = containerId } }, Cmd.none, NoOp )

        FormIngredientsChanged ingredients ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | ingredients = ingredients } }, Cmd.none, NoOp )

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

        SubmitBatchOnly ->
            let
                quantity =
                    Maybe.withDefault 1 (String.toInt model.form.quantity)

                uuidCount =
                    1 + quantity
            in
            ( { model | loading = True, printWithSave = False }
            , Random.generate GotUuidsForBatch (Random.list uuidCount UUID.generator)
            , NoOp
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
            , NoOp
            )

        GotUuidsForBatch uuids ->
            case uuids of
                batchUuid :: portionUuids ->
                    ( model
                    , Api.createBatch model.form batchUuid portionUuids BatchCreated
                    , NoOp
                    )

                [] ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Failed to generate UUIDs", notificationType = Error }
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
                                List.map (\data -> Api.printLabel data PrintResult) printData

                            currentDate =
                                model.form.createdAt
                        in
                        ( { model
                            | form = emptyBatchForm currentDate
                            , loading = False
                            , printingProgress = Just { total = quantity, completed = 0, failed = 0 }
                          }
                        , Cmd.batch printCommands
                        , NavigateToHome
                        )

                    else
                        let
                            currentDate =
                                model.form.createdAt
                        in
                        ( { model | form = emptyBatchForm currentDate, loading = False }
                        , Cmd.none
                        , NavigateToBatch response.batchId
                        )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { message = "Failed to create batch", notificationType = Error }
                    )

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
            ( { model | printingProgress = finalProgress }
            , Cmd.none
            , if allDone then
                RefreshBatches

              else
                outMsg
            )


view : Model -> Html Msg
view model =
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
