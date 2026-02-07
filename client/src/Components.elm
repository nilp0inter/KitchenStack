module Components exposing
    ( viewDeleteConfirm
    , viewHeader
    , viewLoading
    , viewNotification
    , viewPreviewModal
    , viewPreviewModalSvg
    , viewPrintingProgress
    )

import Html exposing (..)
import Html.Attributes as Attr exposing (class, href, style, title)
import Html.Events exposing (onClick)
import Label
import Route exposing (Route(..))
import Types exposing (..)
import Url.Builder


viewHeader : Route -> Bool -> msg -> Html msg
viewHeader currentRoute mobileMenuOpen toggleMsg =
    header [ class "bg-frost-600 text-white shadow-lg relative" ]
        [ div [ class "container mx-auto px-4 py-4" ]
            [ div [ class "flex items-center justify-between" ]
                [ a [ href "/", class "flex items-center space-x-2" ]
                    [ span [ class "text-3xl" ] [ text "❄️" ]
                    , span [ class "text-2xl font-bold" ] [ text "FrostByte" ]
                    ]
                , -- Desktop navigation (hidden on mobile)
                  nav [ class "hidden md:flex space-x-4" ]
                    [ navLink "/" "Inventario" (currentRoute == Dashboard)
                    , navLink "/new" "+ Nuevo" (currentRoute == NewBatch)
                    , navLink "/history" "Historial" (currentRoute == History)
                    , navLink "/recipes" "Recetas" (currentRoute == Recipes)
                    , navLink "/ingredients" "Ingredientes" (currentRoute == Ingredients)
                    , navLink "/containers" "Envases" (currentRoute == ContainerTypes)
                    , navLink "/labels" "Etiquetas" (currentRoute == LabelDesigner)
                    ]
                , -- Hamburger button (visible on mobile only)
                  button
                    [ class "md:hidden p-2 rounded-lg hover:bg-frost-700 transition-colors"
                    , onClick toggleMsg
                    , Attr.attribute "aria-label" "Toggle menu"
                    ]
                    [ div [ class "w-6 h-5 flex flex-col justify-between" ]
                        [ span [ class "block w-full h-0.5 bg-white rounded" ] []
                        , span [ class "block w-full h-0.5 bg-white rounded" ] []
                        , span [ class "block w-full h-0.5 bg-white rounded" ] []
                        ]
                    ]
                ]
            ]
        , -- Mobile menu dropdown
          if mobileMenuOpen then
            div [ class "md:hidden absolute top-full left-0 right-0 bg-frost-600 shadow-lg z-50" ]
                [ nav [ class "container mx-auto px-4 py-2 flex flex-col space-y-1" ]
                    [ mobileNavLink "/" "Inventario" (currentRoute == Dashboard)
                    , mobileNavLink "/new" "+ Nuevo" (currentRoute == NewBatch)
                    , mobileNavLink "/history" "Historial" (currentRoute == History)
                    , mobileNavLink "/recipes" "Recetas" (currentRoute == Recipes)
                    , mobileNavLink "/ingredients" "Ingredientes" (currentRoute == Ingredients)
                    , mobileNavLink "/containers" "Envases" (currentRoute == ContainerTypes)
                    , mobileNavLink "/labels" "Etiquetas" (currentRoute == LabelDesigner)
                    ]
                ]

          else
            text ""
        ]


navLink : String -> String -> Bool -> Html msg
navLink url label isActive =
    a
        [ href url
        , class
            (if isActive then
                "bg-frost-700 px-4 py-2 rounded-lg"

             else
                "hover:bg-frost-700 px-4 py-2 rounded-lg transition-colors"
            )
        ]
        [ text label ]


mobileNavLink : String -> String -> Bool -> Html msg
mobileNavLink url label isActive =
    a
        [ href url
        , class
            (if isActive then
                "bg-frost-700 px-4 py-3 rounded-lg block"

             else
                "hover:bg-frost-700 px-4 py-3 rounded-lg transition-colors block"
            )
        ]
        [ text label ]


viewNotification : Maybe Notification -> msg -> Html msg
viewNotification maybeNotification dismissMsg =
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
                , button [ onClick dismissMsg, class "text-white hover:text-gray-200" ] [ text "✕" ]
                ]

        Nothing ->
            text ""


viewPrintingProgress : Maybe PrintingProgress -> Html msg
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


viewPreviewModal : Maybe PortionPrintData -> msg -> Html msg
viewPreviewModal maybePreview closeMsg =
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
                    , onClick closeMsg
                    ]
                    []
                , div [ class "relative bg-white rounded-xl shadow-2xl max-w-3xl w-full mx-4 overflow-hidden" ]
                    [ div [ class "flex justify-between items-center px-6 py-4 border-b" ]
                        [ h3 [ class "text-lg font-semibold text-gray-800" ]
                            [ text "Vista previa de etiqueta" ]
                        , button
                            [ onClick closeMsg
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
                            [ onClick closeMsg
                            , class "px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-medium"
                            ]
                            [ text "Cerrar" ]
                        ]
                    ]
                ]

        Nothing ->
            text ""


{-| SVG-based preview modal for labels.
Uses Label.viewLabel to render the label directly instead of fetching from server.
-}
viewPreviewModalSvg : Label.LabelSettings -> String -> Maybe PortionPrintData -> msg -> Html msg
viewPreviewModalSvg settings appHost maybePreview closeMsg =
    case maybePreview of
        Just portionData ->
            let
                labelData =
                    { portionId = portionData.portionId
                    , name = portionData.name
                    , ingredients = portionData.ingredients
                    , expiryDate = portionData.expiryDate
                    , bestBeforeDate = portionData.bestBeforeDate
                    , appHost = appHost
                    }

                -- Scale preview to fit modal
                previewScale =
                    min 1.0 (600 / toFloat settings.width)
            in
            div [ class "fixed inset-0 z-50 flex items-center justify-center" ]
                [ div
                    [ class "absolute inset-0 bg-black bg-opacity-50"
                    , onClick closeMsg
                    ]
                    []
                , div [ class "relative bg-white rounded-xl shadow-2xl max-w-3xl w-full mx-4 overflow-hidden" ]
                    [ div [ class "flex justify-between items-center px-6 py-4 border-b" ]
                        [ h3 [ class "text-lg font-semibold text-gray-800" ]
                            [ text "Vista previa de etiqueta" ]
                        , button
                            [ onClick closeMsg
                            , class "text-gray-400 hover:text-gray-600 text-2xl font-bold"
                            ]
                            [ text "×" ]
                        ]
                    , div [ class "p-6 flex justify-center bg-gray-100 overflow-auto" ]
                        [ div
                            [ style "transform" ("scale(" ++ String.fromFloat previewScale ++ ")")
                            , style "transform-origin" "center center"
                            ]
                            [ Label.viewLabel settings labelData ]
                        ]
                    , div [ class "flex justify-end px-6 py-4 bg-gray-50 border-t" ]
                        [ button
                            [ onClick closeMsg
                            , class "px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-medium"
                            ]
                            [ text "Cerrar" ]
                        ]
                    ]
                ]

        Nothing ->
            text ""


viewDeleteConfirm : Maybe String -> msg -> (String -> msg) -> Html msg
viewDeleteConfirm maybeName cancelMsg confirmMsg =
    case maybeName of
        Just name ->
            div [ class "fixed inset-0 z-50 flex items-center justify-center" ]
                [ div
                    [ class "absolute inset-0 bg-black bg-opacity-50"
                    , onClick cancelMsg
                    ]
                    []
                , div [ class "relative bg-white rounded-xl shadow-2xl max-w-md w-full mx-4 overflow-hidden" ]
                    [ div [ class "px-6 py-4 border-b" ]
                        [ h3 [ class "text-lg font-semibold text-gray-800" ]
                            [ text "Confirmar eliminación" ]
                        ]
                    , div [ class "p-6" ]
                        [ p [ class "text-gray-600" ]
                            [ text "¿Estás seguro de que quieres eliminar el envase \""
                            , span [ class "font-medium" ] [ text name ]
                            , text "\"? Esta acción no se puede deshacer."
                            ]
                        ]
                    , div [ class "flex justify-end px-6 py-4 bg-gray-50 border-t space-x-4" ]
                        [ button
                            [ onClick cancelMsg
                            , class "px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-medium"
                            ]
                            [ text "Cancelar" ]
                        , button
                            [ onClick (confirmMsg name)
                            , class "px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium"
                            ]
                            [ text "Eliminar" ]
                        ]
                    ]
                ]

        Nothing ->
            text ""


viewLoading : Html msg
viewLoading =
    div [ class "text-center py-12" ]
        [ div [ class "animate-spin inline-block w-8 h-8 border-4 border-frost-500 border-t-transparent rounded-full" ] []
        , p [ class "mt-4 text-gray-600" ] [ text "Cargando..." ]
        ]
