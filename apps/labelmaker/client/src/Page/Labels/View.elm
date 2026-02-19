module Page.Labels.View exposing (view)

import Api.Decoders exposing (LabelSummary, TemplateSummary)
import Components
import Dict
import Html exposing (..)
import Html.Attributes exposing (class, disabled, href, placeholder, selected, type_, value)
import Html.Events exposing (onClick, onInput)
import Page.Labels.Types exposing (Model, Msg(..))
import Types exposing (RemoteData(..))


view : Model -> Html Msg
view model =
    div []
        [ div [ class "flex items-center justify-between mb-6" ]
            [ h1 [ class "text-2xl font-bold text-gray-800" ] [ text "Etiquetas" ]
            , viewCreateControls model
            ]
        , viewBody model
        ]


viewCreateControls : Model -> Html Msg
viewCreateControls model =
    case model.templates of
        Loaded templates ->
            if List.isEmpty templates then
                text ""

            else
                div [ class "flex items-center gap-2" ]
                    [ select
                        [ class "border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-label-500 focus:border-label-500"
                        , onInput SelectTemplate
                        ]
                        (option [ value "" ] [ text "Seleccionar plantilla..." ]
                            :: List.map
                                (\t ->
                                    option
                                        [ value t.id
                                        , selected (model.selectedTemplateId == Just t.id)
                                        ]
                                        [ text t.name ]
                                )
                                templates
                        )
                    , input
                        [ type_ "text"
                        , class "border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-label-500 focus:border-label-500"
                        , placeholder "Nombre de la etiqueta..."
                        , value model.newName
                        , onInput UpdateNewName
                        ]
                        []
                    , button
                        [ class "px-4 py-2 bg-label-600 text-white rounded-lg hover:bg-label-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed"
                        , onClick CreateLabel
                        , disabled (model.selectedTemplateId == Nothing || String.isEmpty (String.trim model.newName))
                        ]
                        [ text "+ Crear etiqueta" ]
                    ]

        _ ->
            text ""


viewBody : Model -> Html Msg
viewBody model =
    case model.labels of
        NotAsked ->
            text ""

        Loading ->
            Components.viewLoading

        Failed err ->
            div [ class "text-red-500 text-center py-8" ] [ text err ]

        Loaded labels ->
            if List.isEmpty labels then
                viewEmpty

            else
                viewGrid labels


viewEmpty : Html Msg
viewEmpty =
    div [ class "text-center py-16" ]
        [ p [ class "text-gray-400 text-lg mb-4" ] [ text "No hay etiquetas" ]
        , p [ class "text-gray-400 text-sm" ] [ text "Selecciona una plantilla arriba para crear una etiqueta" ]
        ]


viewGrid : List LabelSummary -> Html Msg
viewGrid labels =
    div [ class "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" ]
        (List.map viewCard labels)


viewCard : LabelSummary -> Html Msg
viewCard label =
    let
        valuesSummary =
            Dict.toList label.values
                |> List.map (\( k, v ) -> k ++ ": " ++ v)
                |> String.join ", "
                |> truncateStr 60
    in
    div [ class "bg-white rounded-lg shadow-sm border border-gray-200 hover:shadow-md transition-shadow" ]
        [ a
            [ href ("/label/" ++ label.id)
            , class "block p-4"
            ]
            [ div []
                [ h3 [ class "font-semibold text-gray-800 mb-1" ] [ text label.name ]
                , p [ class "text-sm text-gray-500 mb-1" ] [ text label.templateName ]
                , if String.isEmpty valuesSummary then
                    text ""

                  else
                    p [ class "text-sm text-gray-500 mb-1" ] [ text valuesSummary ]
                , p [ class "text-xs text-gray-400" ] [ text ("Tipo: " ++ label.labelTypeId) ]
                ]
            ]
        , div [ class "border-t border-gray-100 px-4 py-2 flex justify-end" ]
            [ button
                [ class "text-sm text-red-400 hover:text-red-600 transition-colors"
                , onClick (DeleteLabel label.id)
                ]
                [ text "Eliminar" ]
            ]
        ]


truncateStr : Int -> String -> String
truncateStr maxLen s =
    if String.length s > maxLen then
        String.left maxLen s ++ "..."

    else
        s
