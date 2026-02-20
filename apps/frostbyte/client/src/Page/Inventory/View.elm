module Page.Inventory.View exposing (view)

import Components
import Html exposing (..)
import Html.Attributes exposing (alt, class, href, src)
import Html.Events exposing (onClick)
import Page.Inventory.Types exposing (..)
import Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Inventario del Congelador" ]
        , if model.loading then
            Components.viewLoading

          else if List.isEmpty model.batches then
            div [ class "card text-center py-12" ]
                [ span [ class "text-6xl" ] [ text "❄️" ]
                , p [ class "mt-4 text-gray-600" ] [ text "No hay porciones en el congelador" ]
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

        truncateIngredients ingredients =
            if String.length ingredients > 30 then
                String.left 27 ingredients ++ "..."

            else
                ingredients
    in
    div [ class "card overflow-hidden" ]
        [ div [ class "flex items-center justify-between mb-4 px-4 pt-4" ]
            [ h2 [ class "text-lg font-semibold text-gray-800" ] [ text "Lotes existentes" ]
            , a [ href "/new", class "btn-primary" ] [ text "+ Nuevo Lote" ]
            ]
        , div [ class "overflow-x-auto" ]
            [ table [ class "w-full" ]
                [ thead [ class "bg-gray-50" ]
                    [ tr []
                        [ th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600 w-16" ] [ text "" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Nombre" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Ingredientes" ]
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
                                , onClick (SelectBatch batch.batchId)
                                ]
                                [ td [ class "px-4 py-3" ]
                                    [ case batch.image of
                                        Just imageData ->
                                            img
                                                [ src imageData
                                                , alt batch.name
                                                , class "w-12 h-12 object-cover rounded-lg"
                                                ]
                                                []

                                        Nothing ->
                                            div [ class "w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center text-gray-400" ]
                                                [ text "📷" ]
                                    ]
                                , td [ class "px-4 py-3 font-medium text-gray-900" ] [ text batch.name ]
                                , td [ class "px-4 py-3 text-gray-600 text-sm" ]
                                    [ span [ class "text-gray-500" ]
                                        [ text (truncateIngredients batch.ingredients) ]
                                    ]
                                , td [ class "px-4 py-3 text-gray-600 text-sm" ] [ text batch.containerId ]
                                , td [ class "px-4 py-3 text-gray-600" ]
                                    [ span [ class "font-semibold text-frost-600" ] [ text (String.fromInt batch.frozenCount) ]
                                    , span [ class "text-gray-400" ] [ text (" / " ++ String.fromInt batch.totalCount) ]
                                    ]
                                , td [ class "px-4 py-3 text-gray-600" ]
                                    [ text (String.fromFloat (totalServings batch)) ]
                                , td [ class "px-4 py-3" ]
                                    [ span [ class "text-gray-900 font-medium" ] [ text (Maybe.withDefault "-" batch.expiryDate) ]
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
