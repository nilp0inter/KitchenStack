module Page.History exposing
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
import Html.Attributes exposing (class)
import Http
import Svg exposing (rect, svg)
import Svg.Attributes as SvgAttr
import Types exposing (..)


type alias Model =
    { historyData : List HistoryPoint
    , loading : Bool
    , error : Maybe String
    }


type Msg
    = GotHistory (Result Http.Error (List HistoryPoint))


type OutMsg
    = NoOp
    | ShowError String


init : ( Model, Cmd Msg )
init =
    ( { historyData = []
      , loading = True
      , error = Nothing
      }
    , Api.fetchHistory GotHistory
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotHistory result ->
            case result of
                Ok history ->
                    ( { model | historyData = history, loading = False }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( { model | error = Just "Failed to load history", loading = False }
                    , Cmd.none
                    , ShowError "Failed to load history"
                    )


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Historial del Congelador" ]
        , if model.loading then
            Components.viewLoading

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
