module Page.NotFound exposing (view)

import Html exposing (..)
import Html.Attributes exposing (class, href)


view : Html msg
view =
    div [ class "text-center py-12" ]
        [ span [ class "text-6xl" ] [ text "❄️" ]
        , h1 [ class "text-3xl font-bold text-gray-800 mt-4" ] [ text "Página no encontrada" ]
        , p [ class "text-gray-600 mt-2" ] [ text "La página que buscas no existe" ]
        , a [ href "/", class "btn-primary inline-block mt-4" ] [ text "Volver al inicio" ]
        ]
