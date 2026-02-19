module Page.LabelSet.View exposing (view)

import Data.LabelObject as LO exposing (LabelObject(..), ObjectId, ShapeType(..))
import Dict
import Html exposing (..)
import Html.Attributes exposing (class, disabled, href, id, type_, value)
import Html.Events exposing (onBlur, onClick, onInput)
import Page.LabelSet.Types exposing (ComputedText, Model, Msg(..), selectedRowValues)
import Svg exposing (svg)
import Svg.Attributes as SA
import Types exposing (getValue)


view : Model -> Html Msg
view model =
    div []
        [ viewHeader model
        , div [ class "flex flex-col lg:flex-row gap-8" ]
            [ viewPreview model
            , viewControls model
            ]
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    div [ class "flex items-center gap-4 mb-6" ]
        [ a
            [ href "/sets"
            , class "text-label-600 hover:text-label-800 transition-colors"
            ]
            [ text "\u{2190} Conjuntos" ]
        , input
            [ type_ "text"
            , class "text-xl font-bold text-gray-800 bg-transparent border-b border-transparent hover:border-gray-300 focus:border-label-500 focus:outline-none px-1"
            , value (getValue model.labelsetName)
            , onInput UpdateName
            , onBlur CommitName
            ]
            []
        , span [ class "text-sm text-gray-400" ] [ text model.templateName ]
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
    let
        values =
            selectedRowValues model
    in
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
                    Dict.get r.name values
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
    div [ class "w-full lg:w-auto lg:flex-1 space-y-4" ]
        [ viewSpreadsheet model
        , viewPrintControls model
        ]


viewSpreadsheet : Model -> Html Msg
viewSpreadsheet model =
    let
        currentRows =
            getValue model.rows
    in
    div [ class "bg-white rounded-lg p-4 shadow-sm overflow-x-auto" ]
        [ h3 [ class "text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3" ] [ text "Datos" ]
        , if List.isEmpty model.variableNames then
            p [ class "text-sm text-gray-400 italic" ] [ text "Sin variables en la plantilla" ]

          else
            div []
                [ table [ class "w-full border-collapse text-sm" ]
                    [ thead []
                        [ tr [ class "bg-gray-50" ]
                            (th [ class "border border-gray-200 px-2 py-1 text-left font-medium text-gray-600 w-10" ] [ text "#" ]
                                :: List.map
                                    (\varName ->
                                        th [ class "border border-gray-200 px-2 py-1 text-left font-medium text-gray-600" ] [ text varName ]
                                    )
                                    model.variableNames
                                ++ [ th [ class "border border-gray-200 px-2 py-1 w-10" ] [] ]
                            )
                        ]
                    , tbody []
                        (List.indexedMap (viewRow model) currentRows)
                    ]
                , button
                    [ class "mt-3 px-3 py-1 text-sm text-label-600 hover:text-label-800 hover:bg-label-50 rounded transition-colors"
                    , onClick AddRow
                    ]
                    [ text "+ Agregar fila" ]
                ]
        ]


viewRow : Model -> Int -> Dict.Dict String String -> Html Msg
viewRow model rowIndex rowValues =
    let
        isSelected =
            rowIndex == model.selectedRowIndex

        rowClass =
            if isSelected then
                "bg-label-50"

            else
                "hover:bg-gray-50"

        rowCount =
            List.length (getValue model.rows)
    in
    tr [ class rowClass ]
        (td
            [ class "border border-gray-200 px-2 py-1 text-center text-gray-500 cursor-pointer font-medium"
            , onClick (SelectRow rowIndex)
            ]
            [ text (String.fromInt (rowIndex + 1)) ]
            :: List.map
                (\varName ->
                    td [ class "border border-gray-200 px-1 py-0" ]
                        [ input
                            [ type_ "text"
                            , class "w-full px-1 py-1 text-sm border-none focus:outline-none focus:ring-1 focus:ring-label-500 bg-transparent"
                            , value (Dict.get varName rowValues |> Maybe.withDefault "")
                            , onInput (UpdateCell rowIndex varName)
                            , onBlur CommitRows
                            ]
                            []
                        ]
                )
                model.variableNames
            ++ [ td [ class "border border-gray-200 px-2 py-1 text-center" ]
                    [ if rowCount > 1 then
                        button
                            [ class "text-red-400 hover:text-red-600 text-xs"
                            , onClick (DeleteRow rowIndex)
                            ]
                            [ text "\u{2715}" ]

                      else
                        text ""
                    ]
               ]
        )


viewPrintControls : Model -> Html Msg
viewPrintControls model =
    let
        rowCount =
            List.length (getValue model.rows)

        progressText =
            case model.printProgress of
                Just progress ->
                    " (" ++ String.fromInt progress.current ++ "/" ++ String.fromInt progress.total ++ ")"

                Nothing ->
                    ""
    in
    div [ class "bg-white rounded-lg p-4 shadow-sm space-y-2" ]
        [ button
            [ class "w-full px-4 py-3 bg-label-600 text-white rounded-lg hover:bg-label-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            , onClick RequestPrint
            , disabled (model.printing || model.printingAll || List.isEmpty (getValue model.rows))
            ]
            [ if model.printing && not model.printingAll then
                span [ class "animate-spin" ] [ text "\u{23F3}" ]

              else
                text ""
            , text
                (if model.printing && not model.printingAll then
                    "Imprimiendo..."

                 else
                    "Imprimir fila"
                )
            ]
        , button
            [ class "w-full px-4 py-3 bg-label-700 text-white rounded-lg hover:bg-label-800 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            , onClick RequestPrintAll
            , disabled (model.printing || model.printingAll || List.isEmpty (getValue model.rows))
            ]
            [ if model.printingAll then
                span [ class "animate-spin" ] [ text "\u{23F3}" ]

              else
                text ""
            , text
                (if model.printingAll then
                    "Imprimiendo todo" ++ progressText ++ "..."

                 else
                    "Imprimir todo (" ++ String.fromInt rowCount ++ ")"
                )
            ]
        ]
