module Page.Label.View exposing (view)

import Data.LabelObject as LO exposing (LabelObject(..), ObjectId, ShapeType(..))
import Dict
import Html exposing (..)
import Html.Attributes exposing (class, disabled, href, id, type_, value)
import Html.Events exposing (onBlur, onClick, onInput)
import Page.Label.Types exposing (ComputedText, Model, Msg(..))
import Svg exposing (svg)
import Svg.Attributes as SA
import Types exposing (getValue)


view : Model -> Html Msg
view model =
    div []
        [ div [ class "flex items-center gap-4 mb-6" ]
            [ a
                [ href "/labels"
                , class "text-label-600 hover:text-label-800 transition-colors"
                ]
                [ text "\u{2190} Etiquetas" ]
            , span [ class "text-xl font-bold text-gray-800" ]
                [ text model.templateName ]
            ]
        , div [ class "flex flex-col lg:flex-row gap-8" ]
            [ viewPreview model
            , viewControls model
            ]
        ]


viewPreview : Model -> Html Msg
viewPreview model =
    let
        displayWidth =
            if model.rotate then
                model.labelHeight

            else
                model.labelWidth

        displayHeight =
            if model.rotate then
                model.labelWidth

            else
                model.labelHeight

        scaleFactor =
            Basics.min 1.0 (500.0 / toFloat displayWidth)

        scaledWidth =
            round (toFloat displayWidth * scaleFactor)

        scaledHeight =
            round (toFloat displayHeight * scaleFactor)
    in
    div [ class "flex-1" ]
        [ h2 [ class "text-lg font-semibold text-gray-700 mb-4" ] [ text "Vista previa" ]
        , div [ class "flex justify-center" ]
            [ svg
                [ SA.width (String.fromInt scaledWidth)
                , SA.height (String.fromInt scaledHeight)
                , SA.viewBox ("0 0 " ++ String.fromInt displayWidth ++ " " ++ String.fromInt displayHeight)
                , id "label-preview"
                ]
                ([ Svg.rect
                    [ SA.x "0"
                    , SA.y "0"
                    , SA.width (String.fromInt displayWidth)
                    , SA.height (String.fromInt displayHeight)
                    , SA.rx (String.fromInt model.cornerRadius)
                    , SA.ry (String.fromInt model.cornerRadius)
                    , SA.fill "white"
                    , SA.stroke "#ccc"
                    , SA.strokeWidth "2"
                    ]
                    []
                 ]
                    ++ renderObjects model (toFloat displayWidth) (toFloat displayHeight) model.content
                )
            ]
        , p [ class "text-sm text-gray-500 text-center mt-2" ]
            [ text
                (String.fromInt displayWidth
                    ++ " x "
                    ++ String.fromInt displayHeight
                    ++ " px"
                    ++ (if model.rotate then
                            " (rotada)"

                        else
                            ""
                       )
                )
            ]
        ]



-- SVG Rendering


renderObjects : Model -> Float -> Float -> List LabelObject -> List (Svg.Svg Msg)
renderObjects model parentW parentH objects =
    List.concatMap (renderObject model parentW parentH) objects


renderObject : Model -> Float -> Float -> LabelObject -> List (Svg.Svg Msg)
renderObject model parentW parentH obj =
    case obj of
        Container r ->
            [ Svg.g
                [ SA.transform ("translate(" ++ String.fromFloat r.x ++ "," ++ String.fromFloat r.y ++ ")")
                ]
                (renderObjects model r.width r.height r.content)
            ]

        TextObj r ->
            renderTextSvg model parentW parentH r.id r.content r.properties

        VariableObj r ->
            let
                displayText =
                    Dict.get r.name model.values
                        |> Maybe.map getValue
                        |> Maybe.withDefault ("{{" ++ r.name ++ "}}")
            in
            renderTextSvg model parentW parentH r.id displayText r.properties

        ShapeObj r ->
            renderShapeSvg parentW parentH r.properties

        ImageObj r ->
            [ Svg.image
                [ SA.xlinkHref r.url
                , SA.x "0"
                , SA.y "0"
                , SA.width (String.fromFloat parentW)
                , SA.height (String.fromFloat parentH)
                , SA.preserveAspectRatio "xMidYMid meet"
                ]
                []
            ]


renderTextSvg : Model -> Float -> Float -> ObjectId -> String -> LO.TextProperties -> List (Svg.Svg Msg)
renderTextSvg model parentW parentH objId displayText props =
    let
        colorStr =
            "rgb(" ++ String.fromInt props.color.r ++ "," ++ String.fromInt props.color.g ++ "," ++ String.fromInt props.color.b ++ ")"
    in
    case Dict.get objId model.computedTexts of
        Nothing ->
            [ Svg.text_
                [ SA.x (String.fromFloat (parentW / 2))
                , SA.y (String.fromFloat (parentH / 2))
                , SA.textAnchor "middle"
                , SA.dominantBaseline "central"
                , SA.fill "#999"
                , SA.fontSize "14"
                ]
                [ Svg.text "..." ]
            ]

        Just computed ->
            let
                lineHeight =
                    toFloat computed.fittedFontSize * 1.2

                totalTextHeight =
                    lineHeight * toFloat (List.length computed.lines)

                startY =
                    (parentH - totalTextHeight) / 2 + lineHeight / 2
            in
            List.indexedMap
                (\i line ->
                    Svg.text_
                        [ SA.x (String.fromFloat (parentW / 2))
                        , SA.y (String.fromFloat (startY + toFloat i * lineHeight))
                        , SA.textAnchor "middle"
                        , SA.dominantBaseline "central"
                        , SA.fontFamily props.fontFamily
                        , SA.fontSize (String.fromInt computed.fittedFontSize)
                        , SA.fontWeight "bold"
                        , SA.fill colorStr
                        ]
                        [ Svg.text line ]
                )
                computed.lines


renderShapeSvg : Float -> Float -> LO.ShapeProperties -> List (Svg.Svg Msg)
renderShapeSvg parentW parentH props =
    let
        colorStr =
            "rgb(" ++ String.fromInt props.color.r ++ "," ++ String.fromInt props.color.g ++ "," ++ String.fromInt props.color.b ++ ")"
    in
    case props.shapeType of
        Rectangle ->
            [ Svg.rect
                [ SA.x "0"
                , SA.y "0"
                , SA.width (String.fromFloat parentW)
                , SA.height (String.fromFloat parentH)
                , SA.fill colorStr
                , SA.fillOpacity (String.fromFloat props.color.a)
                ]
                []
            ]

        Circle ->
            let
                rx =
                    parentW / 2

                ry =
                    parentH / 2
            in
            [ Svg.ellipse
                [ SA.cx (String.fromFloat rx)
                , SA.cy (String.fromFloat ry)
                , SA.rx (String.fromFloat rx)
                , SA.ry (String.fromFloat ry)
                , SA.fill colorStr
                , SA.fillOpacity (String.fromFloat props.color.a)
                ]
                []
            ]

        Line ->
            [ Svg.line
                [ SA.x1 "0"
                , SA.y1 "0"
                , SA.x2 (String.fromFloat parentW)
                , SA.y2 (String.fromFloat parentH)
                , SA.stroke colorStr
                , SA.strokeWidth "2"
                , SA.strokeOpacity (String.fromFloat props.color.a)
                ]
                []
            ]



-- Controls


viewControls : Model -> Html Msg
viewControls model =
    div [ class "w-full lg:w-96 space-y-4" ]
        [ viewValuesForm model
        , viewPrintButton model
        ]


viewValuesForm : Model -> Html Msg
viewValuesForm model =
    div [ class "bg-white rounded-lg p-4 shadow-sm space-y-3" ]
        (h3 [ class "text-sm font-semibold text-gray-700 uppercase tracking-wide" ] [ text "Valores" ]
            :: (if List.isEmpty model.variableNames then
                    [ p [ class "text-sm text-gray-400 italic" ] [ text "Sin variables" ] ]

                else
                    List.map (viewValueInput model) model.variableNames
               )
        )


viewValueInput : Model -> String -> Html Msg
viewValueInput model varName =
    let
        currentVal =
            Dict.get varName model.values
                |> Maybe.map getValue
                |> Maybe.withDefault ""
    in
    div []
        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text varName ]
        , input
            [ type_ "text"
            , class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
            , value currentVal
            , onInput (UpdateValue varName)
            , onBlur CommitValues
            ]
            []
        ]


viewPrintButton : Model -> Html Msg
viewPrintButton model =
    div [ class "bg-white rounded-lg p-4 shadow-sm" ]
        [ button
            [ class "w-full px-4 py-3 bg-label-600 text-white rounded-lg hover:bg-label-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            , onClick RequestPrint
            , disabled model.printing
            ]
            [ if model.printing then
                span [ class "animate-spin" ] [ text "\u{23F3}" ]

              else
                text ""
            , text
                (if model.printing then
                    "Imprimiendo..."

                 else
                    "Imprimir"
                )
            ]
        ]
