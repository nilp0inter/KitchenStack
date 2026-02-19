module Components exposing
    ( viewHeader
    , viewLoading
    , viewNotification
    )

import Html exposing (..)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)
import Route exposing (Route(..))
import Types exposing (..)


viewHeader : Route -> Html msg
viewHeader currentRoute =
    header [ class "bg-label-600 text-white shadow-lg" ]
        [ div [ class "container mx-auto px-4 py-4" ]
            [ div [ class "flex items-center justify-between" ]
                [ a [ href "/", class "flex items-center space-x-2" ]
                    [ span [ class "text-3xl" ] [ text "\u{1F3F7}\u{FE0F}" ]
                    , span [ class "text-2xl font-bold" ] [ text "LabelMaker" ]
                    ]
                , nav [ class "flex space-x-4 items-center" ]
                    [ navLink "/" "Plantillas" (currentRoute == TemplateList)
                    , navLink "/labels" "Etiquetas" (currentRoute == LabelList)
                    ]
                ]
            ]
        ]


navLink : String -> String -> Bool -> Html msg
navLink url label isActive =
    a
        [ href url
        , class
            (if isActive then
                "px-3 py-2 rounded-lg bg-label-700 text-white font-medium"

             else
                "px-3 py-2 rounded-lg hover:bg-label-500 text-white/80 hover:text-white transition-colors"
            )
        ]
        [ text label ]


viewNotification : Maybe Notification -> (Int -> msg) -> Html msg
viewNotification maybeNotification dismissMsg =
    case maybeNotification of
        Nothing ->
            text ""

        Just notification ->
            let
                ( bgColor, icon ) =
                    case notification.notificationType of
                        Success ->
                            ( "bg-green-500", "\u{2713}" )

                        Info ->
                            ( "bg-blue-500", "\u{2139}" )

                        Error ->
                            ( "bg-red-500", "\u{2715}" )
            in
            div [ class ("fixed top-4 right-4 z-50 " ++ bgColor ++ " text-white px-4 py-3 rounded-lg shadow-lg flex items-center space-x-2") ]
                [ span [] [ text icon ]
                , span [] [ text notification.message ]
                , button
                    [ class "ml-4 hover:opacity-75"
                    , onClick (dismissMsg notification.id)
                    ]
                    [ text "\u{2715}" ]
                ]


viewLoading : Html msg
viewLoading =
    div [ class "flex justify-center items-center py-12" ]
        [ div [ class "text-gray-500 text-lg" ] [ text "Cargando..." ]
        ]
