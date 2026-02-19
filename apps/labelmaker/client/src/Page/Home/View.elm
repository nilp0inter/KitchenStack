module Page.Home.View exposing (view)

import Data.LabelObject as LO exposing (LabelObject(..), ObjectId, ShapeType(..))
import Data.LabelTypes exposing (LabelTypeSpec, isEndlessLabel, labelTypes)
import Dict
import Html exposing (..)
import Html.Attributes exposing (class, classList, for, href, id, max, min, placeholder, selected, step, style, type_, value)
import Html.Events exposing (onBlur, onClick, onInput)
import Page.Home.Types exposing (ComputedText, Model, Msg(..), PropertyChange(..))
import Types exposing (getValue)
import Svg exposing (svg)
import Svg.Attributes as SA
import Svg.Events as SE


view : Model -> Html Msg
view model =
    div []
        [ div [ class "flex items-center gap-4 mb-6" ]
            [ a
                [ href "/"
                , class "text-label-600 hover:text-label-800 transition-colors"
                ]
                [ text "\u{2190} Plantillas" ]
            , input
                [ type_ "text"
                , class "text-xl font-bold text-gray-800 border-b border-transparent hover:border-gray-300 focus:border-label-500 focus:outline-none px-1 py-0.5"
                , value (getValue model.templateName)
                , onInput TemplateNameChanged
                , onBlur CommitTemplateName
                ]
                []
            ]
        , div [ class "flex flex-col lg:flex-row gap-8" ]
            [ viewPreview model
            , viewControls model
            ]
        ]


viewPreview : Model -> Html Msg
viewPreview model =
    let
        labelH =
            getValue model.labelHeight

        displayWidth =
            if model.rotate then
                labelH

            else
                model.labelWidth

        displayHeight =
            if model.rotate then
                model.labelWidth

            else
                labelH

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
                    , SE.onClick (SelectObject Nothing)
                    ]
                    []
                 ]
                    ++ renderObjects model (toFloat displayWidth) (toFloat displayHeight) (getValue model.content)
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
        isSelected =
            model.selectedObjectId == Just (LO.objectId obj)

        selectionAttrs objId =
            [ SE.onClick (SelectObject (Just objId)) ]
    in
    case obj of
        Container r ->
            [ Svg.g
                ([ SA.transform ("translate(" ++ String.fromFloat r.x ++ "," ++ String.fromFloat r.y ++ ")")
                 ]
                    ++ selectionAttrs r.id
                )
                (renderObjects model r.width r.height r.content
                    ++ (if isSelected then
                            [ Svg.rect
                                [ SA.x "0"
                                , SA.y "0"
                                , SA.width (String.fromFloat r.width)
                                , SA.height (String.fromFloat r.height)
                                , SA.fill "none"
                                , SA.stroke "#3b82f6"
                                , SA.strokeWidth "2"
                                , SA.strokeDasharray "6,3"
                                ]
                                []
                            ]

                        else
                            []
                       )
                )
            ]

        TextObj r ->
            renderTextSvg model parentW parentH r.id r.content r.properties isSelected

        VariableObj r ->
            let
                sampleText =
                    Dict.get r.name model.sampleValues
                        |> Maybe.map getValue
                        |> Maybe.withDefault ("{{" ++ r.name ++ "}}")
            in
            renderTextSvg model parentW parentH r.id sampleText r.properties isSelected

        ShapeObj r ->
            renderShapeSvg model parentW parentH r.id r.properties isSelected

        ImageObj r ->
            [ Svg.image
                ([ SA.xlinkHref r.url
                 , SA.x "0"
                 , SA.y "0"
                 , SA.width (String.fromFloat parentW)
                 , SA.height (String.fromFloat parentH)
                 , SA.preserveAspectRatio "xMidYMid meet"
                 ]
                    ++ selectionAttrs r.id
                )
                []
            ]
                ++ selectionOverlay parentW parentH isSelected


renderTextSvg : Model -> Float -> Float -> ObjectId -> String -> LO.TextProperties -> Bool -> List (Svg.Svg Msg)
renderTextSvg model parentW parentH objId displayText props isSelected =
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
                , SE.onClick (SelectObject (Just objId))
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
                        , SE.onClick (SelectObject (Just objId))
                        ]
                        [ Svg.text line ]
                )
                computed.lines
                ++ selectionOverlay parentW parentH isSelected


renderShapeSvg : Model -> Float -> Float -> ObjectId -> LO.ShapeProperties -> Bool -> List (Svg.Svg Msg)
renderShapeSvg model parentW parentH objId props isSelected =
    let
        colorStr =
            "rgb(" ++ String.fromInt props.color.r ++ "," ++ String.fromInt props.color.g ++ "," ++ String.fromInt props.color.b ++ ")"

        shapeEl =
            case props.shapeType of
                Rectangle ->
                    Svg.rect
                        [ SA.x "0"
                        , SA.y "0"
                        , SA.width (String.fromFloat parentW)
                        , SA.height (String.fromFloat parentH)
                        , SA.fill colorStr
                        , SA.fillOpacity (String.fromFloat props.color.a)
                        , SE.onClick (SelectObject (Just objId))
                        ]
                        []

                Circle ->
                    let
                        rx =
                            parentW / 2

                        ry =
                            parentH / 2
                    in
                    Svg.ellipse
                        [ SA.cx (String.fromFloat rx)
                        , SA.cy (String.fromFloat ry)
                        , SA.rx (String.fromFloat rx)
                        , SA.ry (String.fromFloat ry)
                        , SA.fill colorStr
                        , SA.fillOpacity (String.fromFloat props.color.a)
                        , SE.onClick (SelectObject (Just objId))
                        ]
                        []

                Line ->
                    Svg.line
                        [ SA.x1 "0"
                        , SA.y1 "0"
                        , SA.x2 (String.fromFloat parentW)
                        , SA.y2 (String.fromFloat parentH)
                        , SA.stroke colorStr
                        , SA.strokeWidth "2"
                        , SA.strokeOpacity (String.fromFloat props.color.a)
                        , SE.onClick (SelectObject (Just objId))
                        ]
                        []
    in
    [ shapeEl ] ++ selectionOverlay parentW parentH isSelected


selectionOverlay : Float -> Float -> Bool -> List (Svg.Svg Msg)
selectionOverlay w h isSelected =
    if isSelected then
        [ Svg.rect
            [ SA.x "0"
            , SA.y "0"
            , SA.width (String.fromFloat w)
            , SA.height (String.fromFloat h)
            , SA.fill "none"
            , SA.stroke "#3b82f6"
            , SA.strokeWidth "2"
            , SA.strokeDasharray "6,3"
            , SA.pointerEvents "none"
            ]
            []
        ]

    else
        []



-- Controls


viewControls : Model -> Html Msg
viewControls model =
    div [ class "w-full lg:w-96 space-y-4 overflow-y-auto", style "max-height" "80vh" ]
        [ viewLabelSettings model
        , viewObjectTree model
        , viewAddToolbar model
        , viewPropertyEditor model
        ]


viewLabelSettings : Model -> Html Msg
viewLabelSettings model =
    div [ class "bg-white rounded-lg p-4 shadow-sm space-y-3" ]
        [ h3 [ class "text-sm font-semibold text-gray-700 uppercase tracking-wide" ] [ text "Etiqueta" ]
        , viewLabelTypeSelect model
        , viewDimensions model
        , viewPaddingInput model
        ]


viewLabelTypeSelect : Model -> Html Msg
viewLabelTypeSelect model =
    div []
        [ label [ for "label-type", class "block text-sm font-medium text-gray-600 mb-1" ]
            [ text "Tipo" ]
        , select
            [ id "label-type"
            , class "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-label-500 focus:border-label-500"
            , onInput LabelTypeChanged
            ]
            (List.map
                (\spec ->
                    option
                        [ value spec.id
                        , selected (spec.id == model.labelTypeId)
                        ]
                        [ text spec.description ]
                )
                labelTypes
            )
        ]


viewDimensions : Model -> Html Msg
viewDimensions model =
    div [ class "flex gap-3" ]
        [ div [ class "flex-1" ]
            [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Ancho" ]
            , input
                [ type_ "number"
                , class "w-full border border-gray-300 rounded px-2 py-1 text-sm bg-gray-50"
                , value (String.fromInt model.labelWidth)
                , Html.Attributes.disabled True
                ]
                []
            ]
        , div [ class "flex-1" ]
            [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Alto" ]
            , input
                [ type_ "number"
                , class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
                , value (String.fromInt (getValue model.labelHeight))
                , onInput HeightChanged
                , onBlur CommitHeight
                , Html.Attributes.disabled (not (isEndlessLabel model.labelTypeId))
                ]
                []
            ]
        ]


viewPaddingInput : Model -> Html Msg
viewPaddingInput model =
    div []
        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Relleno (px)" ]
        , input
            [ type_ "number"
            , class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
            , value (String.fromInt (getValue model.padding))
            , Html.Attributes.min "0"
            , Html.Attributes.max "100"
            , onInput PaddingChanged
            , onBlur CommitPadding
            ]
            []
        ]



-- Object Tree


viewObjectTree : Model -> Html Msg
viewObjectTree model =
    let
        content =
            getValue model.content
    in
    div [ class "bg-white rounded-lg p-4 shadow-sm" ]
        [ h3 [ class "text-sm font-semibold text-gray-700 uppercase tracking-wide mb-2" ] [ text "Objetos" ]
        , if List.isEmpty content then
            p [ class "text-sm text-gray-400 italic" ] [ text "Sin objetos" ]

          else
            div [ class "space-y-1" ] (List.map (viewTreeItem model 0) content)
        ]


viewTreeItem : Model -> Int -> LabelObject -> Html Msg
viewTreeItem model depth obj =
    let
        objIdVal =
            LO.objectId obj

        isSelected =
            model.selectedObjectId == Just objIdVal

        icon =
            case obj of
                Container _ ->
                    "\u{1F4E6}"

                TextObj _ ->
                    "\u{1F524}"

                VariableObj _ ->
                    "{x}"

                ImageObj _ ->
                    "\u{1F5BC}\u{FE0F}"

                ShapeObj _ ->
                    "\u{25A0}"

        label_ =
            case obj of
                Container _ ->
                    "Contenedor"

                TextObj r ->
                    truncateStr 20 r.content

                VariableObj r ->
                    "{{" ++ r.name ++ "}}"

                ImageObj _ ->
                    "Imagen"

                ShapeObj r ->
                    shapeTypeName r.properties.shapeType

        children =
            case obj of
                Container r ->
                    r.content

                _ ->
                    []
    in
    div []
        [ div
            [ class "flex items-center gap-1 px-2 py-1 rounded cursor-pointer text-sm hover:bg-gray-100"
            , classList [ ( "bg-blue-50 ring-1 ring-blue-300", isSelected ) ]
            , style "padding-left" (String.fromInt (depth * 16 + 8) ++ "px")
            , onClick (SelectObject (Just objIdVal))
            ]
            [ span [ class "w-5 text-center flex-shrink-0" ] [ text icon ]
            , span [ class "flex-1 truncate" ] [ text label_ ]
            , button
                [ class "text-gray-400 hover:text-red-500 flex-shrink-0 px-1"
                , onClick (RemoveObject objIdVal)
                ]
                [ text "\u{00D7}" ]
            ]
        , div [] (List.map (viewTreeItem model (depth + 1)) children)
        ]


truncateStr : Int -> String -> String
truncateStr maxLen s =
    if String.length s > maxLen then
        String.left maxLen s ++ "..."

    else
        s


shapeTypeName : ShapeType -> String
shapeTypeName st =
    case st of
        Rectangle ->
            "Rect\u{00E1}ngulo"

        Circle ->
            "C\u{00ED}rculo"

        Line ->
            "L\u{00ED}nea"



-- Add Toolbar


viewAddToolbar : Model -> Html Msg
viewAddToolbar model =
    div [ class "bg-white rounded-lg p-4 shadow-sm" ]
        [ h3 [ class "text-sm font-semibold text-gray-700 uppercase tracking-wide mb-2" ] [ text "Agregar" ]
        , div [ class "flex flex-wrap gap-2" ]
            [ addButton "Texto" (AddObject (LO.newText model.nextId))
            , addButton "Variable" (AddObject (LO.newVariable model.nextId))
            , addButton "Contenedor" (AddObject (LO.newContainer model.nextId 10 10 200 100))
            , addButton "Rect." (AddObject (LO.newShape model.nextId Rectangle))
            , addButton "C\u{00ED}rculo" (AddObject (LO.newShape model.nextId Circle))
            , addButton "L\u{00ED}nea" (AddObject (LO.newShape model.nextId Line))
            , addButton "Imagen" (AddObject (LO.newImage model.nextId))
            ]
        ]


addButton : String -> Msg -> Html Msg
addButton label_ msg =
    button
        [ class "px-3 py-1.5 text-xs font-medium bg-label-100 text-label-700 rounded-lg hover:bg-label-200 transition-colors"
        , onClick msg
        ]
        [ text label_ ]



-- Property Editor


viewPropertyEditor : Model -> Html Msg
viewPropertyEditor model =
    case model.selectedObjectId of
        Nothing ->
            div [ class "bg-white rounded-lg p-4 shadow-sm" ]
                [ h3 [ class "text-sm font-semibold text-gray-700 uppercase tracking-wide mb-2" ] [ text "Propiedades" ]
                , p [ class "text-sm text-gray-400 italic" ] [ text "Selecciona un objeto" ]
                ]

        Just selId ->
            case LO.findObject selId (getValue model.content) of
                Nothing ->
                    text ""

                Just obj ->
                    div [ class "bg-white rounded-lg p-4 shadow-sm space-y-3" ]
                        [ h3 [ class "text-sm font-semibold text-gray-700 uppercase tracking-wide mb-2" ] [ text "Propiedades" ]
                        , viewPropertiesFor model selId obj
                        ]


viewPropertiesFor : Model -> ObjectId -> LabelObject -> Html Msg
viewPropertiesFor model objId obj =
    case obj of
        Container r ->
            div [ class "space-y-2" ]
                [ propRow "X"
                    (propNumberInput (String.fromFloat r.x) (\v -> UpdateObjectProperty objId (SetContainerX v)) CommitContent)
                    "Y"
                    (propNumberInput (String.fromFloat r.y) (\v -> UpdateObjectProperty objId (SetContainerY v)) CommitContent)
                , propRow "Ancho"
                    (propNumberInput (String.fromFloat r.width) (\v -> UpdateObjectProperty objId (SetContainerWidth v)) CommitContent)
                    "Alto"
                    (propNumberInput (String.fromFloat r.height) (\v -> UpdateObjectProperty objId (SetContainerHeight v)) CommitContent)
                ]

        TextObj r ->
            div [ class "space-y-2" ]
                [ propField "Contenido"
                    (propTextInput r.content (\v -> UpdateObjectProperty objId (SetTextContent v)) CommitContent)
                , viewTextPropertiesInputs objId r.properties
                ]

        VariableObj r ->
            div [ class "space-y-2" ]
                [ propField "Variable"
                    (propTextInput r.name (\v -> UpdateObjectProperty objId (SetVariableName v)) CommitContent)
                , propField "Valor de ejemplo"
                    (propTextInput
                        (Dict.get r.name model.sampleValues |> Maybe.map getValue |> Maybe.withDefault "")
                        (\v -> UpdateSampleValue r.name v)
                        (CommitSampleValue r.name)
                    )
                , viewTextPropertiesInputs objId r.properties
                ]

        ShapeObj r ->
            div [ class "space-y-2" ]
                [ propField "Forma"
                    (select
                        [ class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
                        , onInput
                            (\v ->
                                UpdateObjectProperty objId
                                    (SetShapeType (parseShapeType v))
                            )
                        ]
                        [ option [ value "rectangle", selected (r.properties.shapeType == Rectangle) ] [ text "Rect\u{00E1}ngulo" ]
                        , option [ value "circle", selected (r.properties.shapeType == Circle) ] [ text "C\u{00ED}rculo" ]
                        , option [ value "line", selected (r.properties.shapeType == Line) ] [ text "L\u{00ED}nea" ]
                        ]
                    )
                , viewColorInputs objId r.properties.color
                ]

        ImageObj r ->
            div [ class "space-y-2" ]
                [ propField "URL"
                    (propTextInput r.url (\v -> UpdateObjectProperty objId (SetImageUrl v)) CommitContent)
                ]


viewTextPropertiesInputs : ObjectId -> LO.TextProperties -> Html Msg
viewTextPropertiesInputs objId props =
    div [ class "space-y-2" ]
        [ propField "Fuente"
            (propTextInput props.fontFamily (\v -> UpdateObjectProperty objId (SetFontFamily v)) CommitContent)
        , propField "Tama\u{00F1}o m\u{00E1}x."
            (propNumberInput (String.fromFloat props.fontSize) (\v -> UpdateObjectProperty objId (SetFontSize v)) CommitContent)
        , viewColorInputs objId props.color
        ]


viewColorInputs : ObjectId -> LO.Color -> Html Msg
viewColorInputs objId color =
    div []
        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Color (RGB)" ]
        , div [ class "flex gap-2" ]
            [ colorInput "R" (String.fromInt color.r) (\v -> UpdateObjectProperty objId (SetColorR v)) CommitContent
            , colorInput "G" (String.fromInt color.g) (\v -> UpdateObjectProperty objId (SetColorG v)) CommitContent
            , colorInput "B" (String.fromInt color.b) (\v -> UpdateObjectProperty objId (SetColorB v)) CommitContent
            ]
        ]


colorInput : String -> String -> (String -> Msg) -> Msg -> Html Msg
colorInput lbl val toMsg blurMsg =
    div [ class "flex-1" ]
        [ label [ class "block text-xs text-gray-400" ] [ text lbl ]
        , input
            [ type_ "number"
            , class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
            , value val
            , Html.Attributes.min "0"
            , Html.Attributes.max "255"
            , onInput toMsg
            , onBlur blurMsg
            ]
            []
        ]



-- Property helpers


propField : String -> Html Msg -> Html Msg
propField lbl control =
    div []
        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text lbl ]
        , control
        ]


propRow : String -> Html Msg -> String -> Html Msg -> Html Msg
propRow lbl1 ctrl1 lbl2 ctrl2 =
    div [ class "flex gap-2" ]
        [ div [ class "flex-1" ] [ label [ class "block text-xs text-gray-500 mb-1" ] [ text lbl1 ], ctrl1 ]
        , div [ class "flex-1" ] [ label [ class "block text-xs text-gray-500 mb-1" ] [ text lbl2 ], ctrl2 ]
        ]


propTextInput : String -> (String -> Msg) -> Msg -> Html Msg
propTextInput val toMsg blurMsg =
    input
        [ type_ "text"
        , class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
        , value val
        , onInput toMsg
        , onBlur blurMsg
        ]
        []


propNumberInput : String -> (String -> Msg) -> Msg -> Html Msg
propNumberInput val toMsg blurMsg =
    input
        [ type_ "number"
        , class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
        , value val
        , onInput toMsg
        , onBlur blurMsg
        ]
        []


parseShapeType : String -> ShapeType
parseShapeType s =
    case s of
        "circle" ->
            Circle

        "line" ->
            Line

        _ ->
            Rectangle
