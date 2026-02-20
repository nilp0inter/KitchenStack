module Page.Menu.View exposing (view)

import Html exposing (..)
import Html.Attributes exposing (alt, class, href, src, style)
import Page.Menu.Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "text-3xl font-bold text-gray-800 mb-6" ] [ text "Menu del Congelador" ]
        , if List.isEmpty model.menuItems then
            viewEmpty

          else
            viewGrid model.menuItems
        ]


viewEmpty : Html Msg
viewEmpty =
    div [ class "card text-center py-12" ]
        [ span [ class "text-6xl" ] [ text "❄️" ]
        , p [ class "mt-4 text-gray-600 text-lg" ] [ text "El congelador está vacío" ]
        , a [ href "/new", class "btn-primary inline-block mt-4" ] [ text "Crear nuevo lote" ]
        ]


viewGrid : List MenuItem -> Html Msg
viewGrid items =
    div [ class "grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6" ]
        (List.map viewCard items)


viewCard : MenuItem -> Html Msg
viewCard item =
    div [ class "bg-white rounded-xl shadow-md overflow-hidden hover:shadow-lg transition-shadow" ]
        [ viewCardImage item
        , div [ class "p-4" ]
            [ div [ class "flex items-center justify-between mb-2" ]
                [ h2 [ class "text-lg font-bold text-gray-800 truncate flex-1 mr-2" ] [ text item.name ]
                , span [ class "bg-frost-100 text-frost-700 text-sm font-semibold px-2 py-0.5 rounded-full whitespace-nowrap" ]
                    [ text (String.fromInt item.frozenCount) ]
                ]
            , if not (String.isEmpty item.ingredients) then
                p [ class "text-sm text-gray-500 truncate mb-2" ] [ text item.ingredients ]

              else
                text ""
            , p [ class "text-xs text-gray-400" ] [ text ("Caduca: " ++ item.nearestExpiry) ]
            ]
        ]


viewCardImage : MenuItem -> Html Msg
viewCardImage item =
    div [ class "relative w-full", style "padding-bottom" "75%" ]
        [ case item.image of
            Just imageData ->
                img
                    [ src imageData
                    , alt item.name
                    , class "absolute inset-0 w-full h-full object-cover"
                    ]
                    []

            Nothing ->
                div [ class "absolute inset-0 bg-frost-50 flex items-center justify-center" ]
                    [ span [ class "text-5xl" ] [ text "\u{1F37D}\u{FE0F}" ] ]
        ]
