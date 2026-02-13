module Page.BatchDetail.View exposing (view)

import Components
import Data.Label
import Data.LabelPreset
import Dict
import Html exposing (..)
import Html.Attributes as Attr exposing (alt, class, href, src, title)
import Html.Events exposing (onClick, onInput)
import Label
import Markdown.Parser
import Markdown.Renderer
import Page.BatchDetail.Types exposing (..)
import Types exposing (..)


view : Model -> Html Msg
view model =
    div []
        [ viewPreviewModal model
        , Components.viewPrintingProgress model.printingProgress
        , viewContent model
        , viewHiddenLabels model
        ]


{-| Use SVG-based preview modal with the selected preset settings.
-}
viewPreviewModal : Model -> Html Msg
viewPreviewModal model =
    case model.selectedPreset of
        Just preset ->
            let
                labelSettings =
                    Data.LabelPreset.presetToSettings preset

                -- Look up computed data for the previewed portion
                previewComputed =
                    model.previewModal
                        |> Maybe.andThen (\p -> Dict.get p.portionId model.computedLabelData)
            in
            Components.viewPreviewModalSvg labelSettings model.appHost model.previewModal previewComputed ClosePreviewModal

        Nothing ->
            Components.viewPreviewModal model.previewModal ClosePreviewModal


viewContent : Model -> Html Msg
viewContent model =
    case model.batch of
        Nothing ->
            if model.loading then
                Components.viewLoading

            else
                div [ class "text-center py-12" ]
                    [ span [ class "text-6xl" ] [ text "❓" ]
                    , h1 [ class "text-3xl font-bold text-gray-800 mt-4" ] [ text "Batch no encontrado" ]
                    , a [ href "/", class "btn-primary inline-block mt-4" ] [ text "Volver al inicio" ]
                    ]

        Just batch ->
            let
                frozenCount =
                    List.filter (\p -> p.status == "FROZEN") model.portions
                        |> List.length
            in
            div [ class "max-w-4xl mx-auto" ]
                [ viewBatchHeader model batch frozenCount
                , viewPortionsTable batch model.portions
                , div [ class "mt-6" ]
                    [ a [ href "/", class "text-frost-600 hover:text-frost-800" ] [ text "← Volver al inventario" ]
                    ]
                ]


viewBatchHeader : Model -> BatchSummary -> Int -> Html Msg
viewBatchHeader model batch frozenCount =
    div [ class "card mb-6" ]
        [ div [ class "flex justify-between items-start" ]
            [ div [ class "flex items-start space-x-4" ]
                [ case batch.image of
                    Just imageData ->
                        img
                            [ src ("data:image/png;base64," ++ imageData)
                            , alt batch.name
                            , class "w-24 h-24 object-cover rounded-lg flex-shrink-0"
                            ]
                            []

                    Nothing ->
                        text ""
                , div []
                    [ h1 [ class "text-2xl font-bold text-gray-800" ] [ text batch.name ]
                , p [ class "text-gray-600 mt-1" ]
                    [ text batch.containerId ]
                , if batch.ingredients /= "" then
                    p [ class "text-gray-500 mt-1 text-sm" ]
                        [ span [ class "font-medium" ] [ text "Ingredientes: " ]
                        , text batch.ingredients
                        ]

                  else
                    text ""
                , p [ class "text-gray-500 mt-2" ]
                    [ text ("Caduca: " ++ batch.expiryDate) ]
                , case batch.bestBeforeDate of
                    Just bbDate ->
                        p [ class "text-gray-500 text-sm" ]
                            [ text ("Consumo preferente: " ++ bbDate) ]

                    Nothing ->
                        text ""
                ]
                ]
            , div [ class "flex flex-col items-end space-y-2" ]
                [ viewPresetSelector model
                , if frozenCount > 0 then
                    button
                        [ onClick ReprintAllFrozen
                        , class "bg-frost-500 hover:bg-frost-600 text-white font-medium px-4 py-2 rounded-lg transition-colors"
                        ]
                        [ text ("Imprimir todas (" ++ String.fromInt frozenCount ++ ")") ]

                  else
                    text ""
                ]
            ]
        , viewMarkdownDetails batch.details
        ]


viewMarkdownDetails : Maybe String -> Html Msg
viewMarkdownDetails maybeDetails =
    case maybeDetails of
        Just details ->
            if String.trim details /= "" then
                div [ class "border-t pt-4 mt-4" ]
                    [ p [ class "text-sm font-medium text-gray-700 mb-2" ] [ text "Detalles:" ]
                    , renderMarkdown details
                    ]

            else
                text ""

        Nothing ->
            text ""


renderMarkdown : String -> Html Msg
renderMarkdown markdown =
    case
        markdown
            |> Markdown.Parser.parse
            |> Result.mapError (\_ -> "Markdown parse error")
            |> Result.andThen (Markdown.Renderer.render Markdown.Renderer.defaultHtmlRenderer)
    of
        Ok rendered ->
            div [ class "prose prose-sm max-w-none text-gray-600" ] rendered

        Err _ ->
            div [ class "text-gray-600 whitespace-pre-wrap" ] [ text markdown ]


viewPresetSelector : Model -> Html Msg
viewPresetSelector model =
    div [ class "flex items-center space-x-2" ]
        [ label [ class "text-sm text-gray-600" ] [ text "Etiqueta:" ]
        , select
            [ class "border border-gray-300 rounded px-2 py-1 text-sm"
            , onInput SelectPreset
            , Attr.value (Maybe.map .name model.selectedPreset |> Maybe.withDefault "")
            ]
            (List.map
                (\preset ->
                    Html.option
                        [ Attr.value preset.name
                        , Attr.selected (Maybe.map .name model.selectedPreset == Just preset.name)
                        ]
                        [ text preset.name ]
                )
                model.labelPresets
            )
        ]


{-| Render hidden SVG labels for pending print jobs.
-}
viewHiddenLabels : Model -> Html Msg
viewHiddenLabels model =
    case model.selectedPreset of
        Just preset ->
            let
                labelSettings =
                    Data.LabelPreset.presetToSettings preset
            in
            div
                [ Attr.style "position" "absolute"
                , Attr.style "left" "-9999px"
                , Attr.style "top" "-9999px"
                ]
                (List.filterMap
                    (\printData ->
                        -- Only render labels that have computed data
                        case Dict.get printData.portionId model.computedLabelData of
                            Just computed ->
                                Just
                                    (Label.viewLabelWithComputed labelSettings
                                        { portionId = printData.portionId
                                        , name = printData.name
                                        , ingredients = printData.ingredients
                                        , expiryDate = printData.expiryDate
                                        , bestBeforeDate = printData.bestBeforeDate
                                        , appHost = model.appHost
                                        }
                                        computed
                                    )

                            Nothing ->
                                -- Label not yet measured, skip rendering
                                Nothing
                    )
                    model.pendingPrintData
                )

        Nothing ->
            text ""


viewPortionsTable : BatchSummary -> List PortionInBatch -> Html Msg
viewPortionsTable batch portions =
    div [ class "card overflow-hidden" ]
        [ h2 [ class "text-lg font-semibold text-gray-800 p-4 border-b" ] [ text "Porciones" ]
        , div [ class "overflow-x-auto" ]
            [ table [ class "w-full" ]
                [ thead [ class "bg-gray-50" ]
                    [ tr []
                        [ th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "#" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Estado" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Congelado" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Caduca" ]
                        , th [ class "px-4 py-3 text-left text-sm font-semibold text-gray-600" ] [ text "Acciones" ]
                        ]
                    ]
                , tbody [ class "divide-y divide-gray-200" ]
                    (List.indexedMap (viewPortionRow batch) portions)
                ]
            ]
        ]


viewPortionRow : BatchSummary -> Int -> PortionInBatch -> Html Msg
viewPortionRow batch index portion =
    let
        printData =
            { portionId = portion.portionId
            , name = batch.name
            , ingredients = batch.ingredients
            , containerId = batch.containerId
            , expiryDate = portion.expiryDate
            , bestBeforeDate = batch.bestBeforeDate
            }
    in
    tr [ class "hover:bg-gray-50" ]
        [ td [ class "px-4 py-3 text-gray-600" ] [ text (String.fromInt (index + 1)) ]
        , td [ class "px-4 py-3" ]
            [ if portion.status == "FROZEN" then
                span [ class "inline-block bg-frost-100 text-frost-700 px-2 py-1 rounded text-sm" ]
                    [ text "Congelada" ]

              else
                span [ class "inline-block bg-green-100 text-green-700 px-2 py-1 rounded text-sm" ]
                    [ text "Consumida" ]
            ]
        , td [ class "px-4 py-3 text-gray-600" ] [ text portion.createdAt ]
        , td [ class "px-4 py-3 text-gray-600" ] [ text portion.expiryDate ]
        , td [ class "px-4 py-3" ]
            [ if portion.status == "FROZEN" then
                div [ class "flex space-x-2" ]
                    [ a
                        [ href ("/item/" ++ portion.portionId)
                        , class "text-2xl hover:scale-110 transition-transform"
                        , title "Consumir"
                        ]
                        [ text "🍴" ]
                    , button
                        [ onClick (OpenPreviewModal printData)
                        , class "text-2xl hover:scale-110 transition-transform"
                        , title "Vista previa"
                        ]
                        [ text "👁️" ]
                    , button
                        [ onClick (ReprintPortion portion)
                        , class "text-2xl hover:scale-110 transition-transform"
                        , title "Reimprimir"
                        ]
                        [ text "🖨️" ]
                    ]

              else
                button
                    [ onClick (ReturnToFreezer portion.portionId)
                    , class "text-2xl hover:scale-110 transition-transform"
                    , title "Devolver al congelador"
                    ]
                    [ text "🔄" ]
            ]
        ]
