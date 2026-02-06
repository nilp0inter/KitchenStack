module Page.Dashboard exposing
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
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)
import Http
import Types exposing (..)


type alias Model =
    { batches : List BatchSummary
    , containerTypes : List ContainerType
    , loading : Bool
    , error : Maybe String
    }


type Msg
    = GotBatches (Result Http.Error (List BatchSummary))


type OutMsg
    = NoOp
    | NavigateToBatch String
    | ShowError String


init : List BatchSummary -> List ContainerType -> ( Model, Cmd Msg )
init batches containerTypes =
    ( { batches = batches
      , containerTypes = containerTypes
      , loading = List.isEmpty batches
      , error = Nothing
      }
    , if List.isEmpty batches then
        Api.fetchBatches GotBatches

      else
        Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotBatches result ->
            case result of
                Ok batches ->
                    ( { model | batches = batches, loading = False }, Cmd.none, NoOp )

                Err _ ->
                    ( { model | error = Just "Failed to load batches", loading = False }
                    , Cmd.none
                    , ShowError "Failed to load batches"
                    )


view : Model -> (String -> msg) -> Html msg
view model navigateMsg =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Inventario del Congelador" ]
        , if model.loading then
            Components.viewLoading

          else if List.isEmpty model.batches then
            div [ class "card text-center py-12" ]
                [ span [ class "text-6xl" ] [ text "❄️" ]
                , p [ class "mt-4 text-gray-600" ] [ text "No hay porciones en el congelador" ]
                , a [ href "/new", class "btn-primary inline-block mt-4" ] [ text "Añadir primera porción" ]
                ]

          else
            viewBatchesTable model navigateMsg
        ]


viewBatchesTable : Model -> (String -> msg) -> Html msg
viewBatchesTable model navigateMsg =
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
                                , onClick (navigateMsg batch.batchId)
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
