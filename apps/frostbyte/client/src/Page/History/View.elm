module Page.History.View exposing (view)

import Chart as C
import Chart.Attributes as CA
import Chart.Events as CE
import Chart.Item as CI
import Components
import Data.Date as Date
import Html exposing (..)
import Html.Attributes exposing (class, style)
import Page.History.Types exposing (..)
import Types exposing (..)


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
            let
                filledData =
                    fillDateGaps model.historyData
            in
            div []
                [ viewHistoryChart filledData model.hovering
                , viewHistoryTable model.historyData
                ]
        ]



-- Date gap filling


fillDateGaps : List HistoryPoint -> List HistoryPoint
fillDateGaps history =
    case history of
        [] ->
            []

        first :: rest ->
            let
                allDates =
                    generateDateRange first.date (lastDate history)

                historyDict =
                    List.foldl
                        (\point dict -> ( point.date, point ) :: dict)
                        []
                        history
            in
            List.foldl
                (\date ( acc, lastTotal ) ->
                    case findInList date historyDict of
                        Just point ->
                            ( point :: acc, point.frozenTotal )

                        Nothing ->
                            ( { date = date
                              , added = 0
                              , consumed = 0
                              , frozenTotal = lastTotal
                              }
                                :: acc
                            , lastTotal
                            )
                )
                ( [], first.frozenTotal - first.added + first.consumed )
                allDates
                |> Tuple.first
                |> List.reverse


lastDate : List HistoryPoint -> String
lastDate history =
    List.reverse history
        |> List.head
        |> Maybe.map .date
        |> Maybe.withDefault ""


findInList : String -> List ( String, HistoryPoint ) -> Maybe HistoryPoint
findInList date list =
    case list of
        [] ->
            Nothing

        ( d, point ) :: rest ->
            if d == date then
                Just point

            else
                findInList date rest


generateDateRange : String -> String -> List String
generateDateRange startStr endStr =
    case ( Date.fromIsoString startStr, Date.fromIsoString endStr ) of
        ( Just start, Just end ) ->
            Date.range start end
                |> List.map Date.toIsoString

        _ ->
            []



-- Chart


viewHistoryChart : List HistoryPoint -> List (CI.One HistoryPoint CI.Any) -> Html Msg
viewHistoryChart history hovering =
    let
        dateToIndex : HistoryPoint -> Float
        dateToIndex point =
            List.indexedMap Tuple.pair history
                |> List.filter (\( _, p ) -> p.date == point.date)
                |> List.head
                |> Maybe.map (Tuple.first >> toFloat)
                |> Maybe.withDefault 0

        indexToDate : Float -> String
        indexToDate idx =
            List.indexedMap Tuple.pair history
                |> List.filter (\( i, _ ) -> i == round idx)
                |> List.head
                |> Maybe.map (Tuple.second >> .date >> formatDateShort)
                |> Maybe.withDefault ""

        tickCount =
            min 10 (List.length history)

        tickInterval =
            max 1 (List.length history // tickCount)

        tickValues =
            List.range 0 (List.length history - 1)
                |> List.filter (\i -> modBy tickInterval i == 0)
                |> List.map toFloat
    in
    div [ class "card mb-6" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 mb-4" ] [ text "Evolución del congelador" ]
        , div [ class "mb-4" ] [ viewLegend ]
        , div [ class "overflow-x-auto" ]
            [ div [ style "min-width" "600px" ]
                [ C.chart
                    [ CA.height 300
                    , CA.width 800
                    , CA.margin { top = 20, bottom = 30, left = 50, right = 20 }
                    , CE.onMouseMove OnHover (CE.getNearest CI.any)
                    , CE.onMouseLeave (OnHover [])
                    ]
                    [ -- Grid
                      C.xLabels
                        [ CA.withGrid
                        , CA.amount (List.length tickValues)
                        , CA.format indexToDate
                        ]
                    , C.yLabels [ CA.withGrid ]

                    -- Added bars (positive, green)
                    , C.bars
                        [ CA.x1 dateToIndex
                        , CA.noGrid
                        ]
                        [ C.bar (toFloat << .added)
                            [ CA.color "#22c55e"
                            , CA.roundTop 0.2
                            ]
                            |> C.named "Añadidas"
                        ]
                        history

                    -- Consumed bars (negative, red)
                    , C.bars
                        [ CA.x1 dateToIndex
                        , CA.noGrid
                        ]
                        [ C.bar (toFloat << negate << .consumed)
                            [ CA.color "#ef4444"
                            , CA.roundBottom 0.2
                            ]
                            |> C.named "Consumidas"
                        ]
                        history

                    -- Total line (blue)
                    , C.series dateToIndex
                        [ C.interpolated (toFloat << .frozenTotal)
                            [ CA.color "#0ea5e9"
                            , CA.width 3
                            ]
                            [ CA.circle
                            , CA.size 6
                            , CA.color "#0ea5e9"
                            ]
                            |> C.named "Total congelado"
                        ]
                        history

                    -- Zero line for reference
                    , C.withPlane
                        (\plane ->
                            [ C.line
                                [ CA.x1 plane.x.min
                                , CA.x2 plane.x.max
                                , CA.y1 0
                                , CA.color "#9ca3af"
                                , CA.dashed [ 5, 5 ]
                                ]
                            ]
                        )

                    -- Tooltip on hover
                    , C.each hovering
                        (\plane item ->
                            let
                                point =
                                    CI.getData item
                            in
                            [ C.tooltip item
                                []
                                []
                                [ Html.div [ class "bg-white p-2 rounded shadow-lg border text-sm" ]
                                    [ Html.div [ class "font-semibold text-gray-800" ]
                                        [ Html.text (formatDateFull point.date) ]
                                    , Html.div [ class "text-green-600" ]
                                        [ Html.text ("Añadidas: +" ++ String.fromInt point.added) ]
                                    , Html.div [ class "text-red-600" ]
                                        [ Html.text ("Consumidas: -" ++ String.fromInt point.consumed) ]
                                    , Html.div [ class "text-frost-600 font-semibold" ]
                                        [ Html.text ("Total: " ++ String.fromInt point.frozenTotal) ]
                                    ]
                                ]
                            ]
                        )
                    ]
                ]
            ]
        ]


viewLegend : Html msg
viewLegend =
    div [ class "flex flex-wrap gap-4 justify-center text-sm" ]
        [ div [ class "flex items-center gap-2" ]
            [ div [ class "w-4 h-4 rounded", style "background-color" "#0ea5e9" ] []
            , span [ class "text-gray-700" ] [ text "Total congelado" ]
            ]
        , div [ class "flex items-center gap-2" ]
            [ div [ class "w-4 h-4 rounded", style "background-color" "#22c55e" ] []
            , span [ class "text-gray-700" ] [ text "Añadidas" ]
            ]
        , div [ class "flex items-center gap-2" ]
            [ div [ class "w-4 h-4 rounded", style "background-color" "#ef4444" ] []
            , span [ class "text-gray-700" ] [ text "Consumidas" ]
            ]
        ]


formatDateShort : String -> String
formatDateShort dateStr =
    case Date.fromIsoString dateStr of
        Just date ->
            Date.formatShort date

        Nothing ->
            dateStr


formatDateFull : String -> String
formatDateFull dateStr =
    case Date.fromIsoString dateStr of
        Just date ->
            Date.formatDisplay date

        Nothing ->
            dateStr



-- Table


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
                                [ td [ class "px-4 py-2 text-gray-900" ] [ text (formatDateFull point.date) ]
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
