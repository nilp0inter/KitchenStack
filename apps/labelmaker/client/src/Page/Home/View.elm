module Page.Home.View exposing (view)

import Data.LabelObject as LO exposing (LabelObject(..), ObjectId, ShapeType(..))
import Data.LabelTypes exposing (LabelTypeSpec, isEndlessLabel, labelTypes)
import Dict
import Html exposing (..)
import Html.Attributes exposing (checked, class, classList, for, href, id, max, min, placeholder, rows, selected, step, style, type_, value)
import Html.Events exposing (onBlur, onCheck, onClick, onInput)
import Json.Decode as Decode
import Page.Home.Types exposing (ComputedText, DragMode(..), DropTarget(..), Handle(..), Model, Msg(..), PropertyChange(..))
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
                    ++ [ Svg.g
                            [ SA.transform ("translate(" ++ String.fromInt model.offsetX ++ "," ++ String.fromInt model.offsetY ++ ")") ]
                            (renderObjects model (toFloat displayWidth) (toFloat displayHeight) (getValue model.content))
                       ]
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
                                , SA.fill "rgba(59,130,246,0.05)"
                                , SA.stroke "#3b82f6"
                                , SA.strokeWidth "2"
                                , SA.strokeDasharray "6,3"
                                , SA.cursor "move"
                                , onSvgMouseDown r.id Moving
                                ]
                                []
                            ]
                                ++ resizeHandles r.id r.width r.height

                        else
                            []
                       )
                )
            ]

        VSplit r ->
            let
                topH =
                    parentH * r.split / 100

                bottomH =
                    parentH - topH
            in
            [ Svg.g
                (selectionAttrs r.id)
                (renderMaybeSlot model parentW topH r.top
                    ++ [ Svg.g
                            [ SA.transform ("translate(0," ++ String.fromFloat topH ++ ")") ]
                            (renderMaybeSlot model parentW bottomH r.bottom)
                       ]
                    ++ [ Svg.line
                            [ SA.x1 "0"
                            , SA.y1 (String.fromFloat topH)
                            , SA.x2 (String.fromFloat parentW)
                            , SA.y2 (String.fromFloat topH)
                            , SA.stroke "#999"
                            , SA.strokeWidth "1"
                            , SA.strokeDasharray "4,2"
                            , SA.pointerEvents "none"
                            ]
                            []
                       ]
                    ++ (if isSelected then
                            [ Svg.rect
                                [ SA.x "0"
                                , SA.y "0"
                                , SA.width (String.fromFloat parentW)
                                , SA.height (String.fromFloat parentH)
                                , SA.fill "rgba(59,130,246,0.05)"
                                , SA.stroke "#3b82f6"
                                , SA.strokeWidth "2"
                                , SA.strokeDasharray "6,3"
                                ]
                                []
                            , Svg.line
                                [ SA.x1 "0"
                                , SA.y1 (String.fromFloat topH)
                                , SA.x2 (String.fromFloat parentW)
                                , SA.y2 (String.fromFloat topH)
                                , SA.stroke "#3b82f6"
                                , SA.strokeWidth "3"
                                , SA.strokeDasharray "6,3"
                                , SA.cursor "row-resize"
                                , onSplitDragStart r.id parentW parentH
                                ]
                                []
                            , Svg.circle
                                [ SA.cx (String.fromFloat (parentW / 2))
                                , SA.cy (String.fromFloat topH)
                                , SA.r "5"
                                , SA.fill "#3b82f6"
                                , SA.stroke "white"
                                , SA.strokeWidth "1"
                                , SA.cursor "row-resize"
                                , onSplitDragStart r.id parentW parentH
                                ]
                                []
                            ]

                        else
                            []
                       )
                )
            ]

        HSplit r ->
            let
                leftW =
                    parentW * r.split / 100

                rightW =
                    parentW - leftW
            in
            [ Svg.g
                (selectionAttrs r.id)
                (renderMaybeSlot model leftW parentH r.left
                    ++ [ Svg.g
                            [ SA.transform ("translate(" ++ String.fromFloat leftW ++ ",0)") ]
                            (renderMaybeSlot model rightW parentH r.right)
                       ]
                    ++ [ Svg.line
                            [ SA.x1 (String.fromFloat leftW)
                            , SA.y1 "0"
                            , SA.x2 (String.fromFloat leftW)
                            , SA.y2 (String.fromFloat parentH)
                            , SA.stroke "#999"
                            , SA.strokeWidth "1"
                            , SA.strokeDasharray "4,2"
                            , SA.pointerEvents "none"
                            ]
                            []
                       ]
                    ++ (if isSelected then
                            [ Svg.rect
                                [ SA.x "0"
                                , SA.y "0"
                                , SA.width (String.fromFloat parentW)
                                , SA.height (String.fromFloat parentH)
                                , SA.fill "rgba(59,130,246,0.05)"
                                , SA.stroke "#3b82f6"
                                , SA.strokeWidth "2"
                                , SA.strokeDasharray "6,3"
                                ]
                                []
                            , Svg.line
                                [ SA.x1 (String.fromFloat leftW)
                                , SA.y1 "0"
                                , SA.x2 (String.fromFloat leftW)
                                , SA.y2 (String.fromFloat parentH)
                                , SA.stroke "#3b82f6"
                                , SA.strokeWidth "3"
                                , SA.strokeDasharray "6,3"
                                , SA.cursor "col-resize"
                                , onSplitDragStart r.id parentW parentH
                                ]
                                []
                            , Svg.circle
                                [ SA.cx (String.fromFloat leftW)
                                , SA.cy (String.fromFloat (parentH / 2))
                                , SA.r "5"
                                , SA.fill "#3b82f6"
                                , SA.stroke "white"
                                , SA.strokeWidth "1"
                                , SA.cursor "col-resize"
                                , onSplitDragStart r.id parentW parentH
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


renderMaybeSlot : Model -> Float -> Float -> Maybe LabelObject -> List (Svg.Svg Msg)
renderMaybeSlot model w h slot =
    case slot of
        Just child ->
            renderObjects model w h [ child ]

        Nothing ->
            []


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
                pad =
                    toFloat (getValue model.padding)

                lineHeight =
                    toFloat computed.fittedFontSize * props.lineHeight

                totalTextHeight =
                    lineHeight * toFloat (List.length computed.lines)

                ( xPos, anchor ) =
                    case props.hAlign of
                        LO.AlignLeft ->
                            ( pad, "start" )

                        LO.AlignCenter ->
                            ( parentW / 2, "middle" )

                        LO.AlignRight ->
                            ( parentW - pad, "end" )

                startY =
                    case props.vAlign of
                        LO.AlignTop ->
                            pad + lineHeight / 2

                        LO.AlignMiddle ->
                            (parentH - totalTextHeight) / 2 + lineHeight / 2

                        LO.AlignBottom ->
                            parentH - pad - totalTextHeight + lineHeight / 2
            in
            List.indexedMap
                (\i line ->
                    Svg.text_
                        [ SA.x (String.fromFloat xPos)
                        , SA.y (String.fromFloat (startY + toFloat i * lineHeight))
                        , SA.textAnchor anchor
                        , SA.dominantBaseline "central"
                        , SA.fontFamily props.fontFamily
                        , SA.fontSize (String.fromInt computed.fittedFontSize)
                        , SA.fontWeight props.fontWeight
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
        , viewOffsetInputs model
        , viewCheckbox "Rotar 90° para impresión" model.rotate RotateChanged
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



viewOffsetInputs : Model -> Html Msg
viewOffsetInputs model =
    div [ class "flex gap-3" ]
        [ div [ class "flex-1" ]
            [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Desplazamiento X" ]
            , input
                [ type_ "number"
                , class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
                , value (String.fromInt model.offsetX)
                , onInput OffsetXChanged
                ]
                []
            ]
        , div [ class "flex-1" ]
            [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Desplazamiento Y" ]
            , input
                [ type_ "number"
                , class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
                , value (String.fromInt model.offsetY)
                , onInput OffsetYChanged
                ]
                []
            ]
        ]


viewCheckbox : String -> Bool -> (Bool -> Msg) -> Html Msg
viewCheckbox labelText isChecked onChange =
    label [ class "flex items-center space-x-2 cursor-pointer" ]
        [ input
            [ type_ "checkbox"
            , class "w-4 h-4 text-label-600 rounded border-gray-300 focus:ring-label-500"
            , checked isChecked
            , onCheck onChange
            ]
            []
        , span [ class "text-sm text-gray-700" ] [ text labelText ]
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
            div [ class "space-y-1" ] (List.map (viewTreeItem model 0 True) content)
        ]


viewTreeItem : Model -> Int -> Bool -> LabelObject -> Html Msg
viewTreeItem model depth deletable obj =
    let
        objIdVal =
            LO.objectId obj

        isSelected =
            model.selectedObjectId == Just objIdVal

        icon =
            case obj of
                Container _ ->
                    "\u{1F4E6}"

                VSplit _ ->
                    "\u{2B12}"

                HSplit _ ->
                    "\u{2B13}"

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
                Container r_ ->
                    if String.isEmpty r_.name then
                        "Contenedor"

                    else
                        r_.name

                VSplit r_ ->
                    if String.isEmpty r_.name then
                        "V-Split"

                    else
                        r_.name

                HSplit r_ ->
                    if String.isEmpty r_.name then
                        "H-Split"

                    else
                        r_.name

                TextObj r ->
                    truncateStr 20 r.content

                VariableObj r ->
                    "{{" ++ r.name ++ "}}"

                ImageObj _ ->
                    "Imagen"

                ShapeObj r ->
                    shapeTypeName r.properties.shapeType

        isDragged =
            case model.treeDragState of
                Just tds ->
                    tds.draggedId == objIdVal

                Nothing ->
                    False

        dropTargetHere =
            case model.treeDragState of
                Just tds ->
                    tds.dropTarget

                Nothing ->
                    Nothing

        isDropBefore =
            dropTargetHere == Just (DropBefore objIdVal)

        isDropAfter =
            dropTargetHere == Just (DropAfter objIdVal)

        isDropInto =
            dropTargetHere == Just (DropInto objIdVal)

        isContainer =
            case obj of
                Container _ ->
                    True

                _ ->
                    False
    in
    div []
        [ if isDropBefore then
            div
                [ class "h-0.5 bg-blue-500 rounded mx-2"
                , style "margin-left" (String.fromInt (depth * 16 + 8) ++ "px")
                ]
                []

          else
            text ""
        , div
            [ class "flex items-center gap-1 px-2 py-1 rounded cursor-pointer text-sm hover:bg-gray-100"
            , classList
                [ ( "bg-blue-50 ring-1 ring-blue-300", isSelected )
                , ( "opacity-50", isDragged )
                , ( "ring-2 ring-blue-400 bg-blue-50", isDropInto )
                ]
            , style "padding-left" (String.fromInt (depth * 16 + 8) ++ "px")
            , onClick (SelectObject (Just objIdVal))
            , Html.Attributes.draggable "true"
            , onDragStart (TreeDragStart objIdVal)
            , onDragOver model objIdVal isContainer
            , onDrop TreeDrop
            , onDragEnd TreeDragEnd
            ]
            [ span [ class "w-5 text-center flex-shrink-0" ] [ text icon ]
            , span [ class "flex-1 truncate" ] [ text label_ ]
            , if deletable then
                button
                    [ class "text-gray-400 hover:text-red-500 flex-shrink-0 px-1"
                    , onClick (RemoveObject objIdVal)
                    ]
                    [ text "\u{00D7}" ]

              else
                text ""
            ]
        , if isDropAfter then
            div
                [ class "h-0.5 bg-blue-500 rounded mx-2"
                , style "margin-left" (String.fromInt (depth * 16 + 8) ++ "px")
                ]
                []

          else
            text ""
        , case obj of
            Container r ->
                div [] (List.map (viewTreeItem model (depth + 1) True) r.content)

            VSplit r ->
                div []
                    [ viewSlotLabel model (depth + 1) "Arriba" r.id LO.TopSlot r.top
                    , viewSlotLabel model (depth + 1) "Abajo" r.id LO.BottomSlot r.bottom
                    ]

            HSplit r ->
                div []
                    [ viewSlotLabel model (depth + 1) "Izq." r.id LO.LeftSlot r.left
                    , viewSlotLabel model (depth + 1) "Der." r.id LO.RightSlot r.right
                    ]

            _ ->
                text ""
        ]


viewSlotLabel : Model -> Int -> String -> ObjectId -> LO.SlotPosition -> Maybe LabelObject -> Html Msg
viewSlotLabel model depth slotName splitId slotPosition maybeChild =
    let
        dropTargetHere =
            case model.treeDragState of
                Just tds ->
                    tds.dropTarget

                Nothing ->
                    Nothing

        isSlotDropTarget =
            dropTargetHere == Just (DropIntoSlot splitId slotPosition)
    in
    div []
        [ div
            [ class "text-xs text-gray-400 italic"
            , style "padding-left" (String.fromInt (depth * 16 + 8) ++ "px")
            ]
            [ text slotName ]
        , case maybeChild of
            Just child ->
                viewTreeItem model (depth + 1) True child

            Nothing ->
                div
                    [ class "text-xs text-gray-300 italic"
                    , classList [ ( "bg-blue-50 ring-1 ring-blue-300 rounded", isSlotDropTarget ) ]
                    , style "padding-left" (String.fromInt ((depth + 1) * 16 + 8) ++ "px")
                    , style "padding-top" "2px"
                    , style "padding-bottom" "2px"
                    , Html.Attributes.attribute "dropzone" "move"
                    , onDragOverSlot splitId slotPosition
                    , onDrop TreeDrop
                    ]
                    [ text "(vac\u{00ED}o)" ]
        ]


onDragOverSlot : ObjectId -> LO.SlotPosition -> Html.Attribute Msg
onDragOverSlot splitId slot =
    Html.Events.preventDefaultOn "dragover"
        (Decode.succeed ( TreeDragOver (DropIntoSlot splitId slot), True ))


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
            , addButton "V-Split" (AddObject (LO.newVSplit model.nextId))
            , addButton "H-Split" (AddObject (LO.newHSplit model.nextId))
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
                        , viewMoveToDropdown model selId obj
                        ]


viewMoveToDropdown : Model -> ObjectId -> LabelObject -> Html Msg
viewMoveToDropdown model objId obj =
    let
        allContainers =
            LO.allContainerIds (getValue model.content)

        -- Filter out self and descendants
        validTargets =
            List.filter
                (\( cId, _ ) ->
                    cId
                        /= objId
                        && not (LO.isDescendantOf cId objId (getValue model.content))
                )
                allContainers

        -- Slot targets (empty VSplit/HSplit slots)
        allSlots =
            LO.allSlotTargets (getValue model.content)

        validSlots =
            List.filter
                (\( sId, _, _ ) ->
                    sId
                        /= objId
                        && not (LO.isDescendantOf sId objId (getValue model.content))
                )
                allSlots

        -- Find current parent
        currentParent =
            findParentId objId (getValue model.content)
    in
    propField "Mover a"
        (select
            [ class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
            , onInput
                (\v ->
                    if v == "__root__" then
                        MoveObjectToParent objId Nothing

                    else
                        case parseSlotValue v of
                            Just ( splitId, slot ) ->
                                MoveObjectToSlot objId splitId slot

                            Nothing ->
                                MoveObjectToParent objId (Just v)
                )
            ]
            (option [ value "__root__", selected (currentParent == Nothing) ] [ text "Ra\u{00ED}z" ]
                :: List.map
                    (\( cId, cName ) ->
                        option [ value cId, selected (currentParent == Just cId) ] [ text cName ]
                    )
                    validTargets
                ++ List.map
                    (\( sId, slot, sName ) ->
                        option [ value (slotValue sId slot) ] [ text sName ]
                    )
                    validSlots
            )
        )


slotValue : ObjectId -> LO.SlotPosition -> String
slotValue splitId slot =
    "slot:" ++ splitId ++ ":" ++ slotPositionToString slot


slotPositionToString : LO.SlotPosition -> String
slotPositionToString slot =
    case slot of
        LO.TopSlot ->
            "top"

        LO.BottomSlot ->
            "bottom"

        LO.LeftSlot ->
            "left"

        LO.RightSlot ->
            "right"


parseSlotValue : String -> Maybe ( ObjectId, LO.SlotPosition )
parseSlotValue v =
    case String.split ":" v of
        [ "slot", splitId, posStr ] ->
            case posStr of
                "top" ->
                    Just ( splitId, LO.TopSlot )

                "bottom" ->
                    Just ( splitId, LO.BottomSlot )

                "left" ->
                    Just ( splitId, LO.LeftSlot )

                "right" ->
                    Just ( splitId, LO.RightSlot )

                _ ->
                    Nothing

        _ ->
            Nothing


findParentId : ObjectId -> List LabelObject -> Maybe ObjectId
findParentId targetId objects =
    findParentIdHelper Nothing targetId objects


findParentIdHelper : Maybe ObjectId -> ObjectId -> List LabelObject -> Maybe ObjectId
findParentIdHelper parentId targetId objects =
    case objects of
        [] ->
            Nothing

        obj :: rest ->
            if LO.objectId obj == targetId then
                parentId

            else
                case obj of
                    Container r ->
                        case findParentIdHelper (Just r.id) targetId r.content of
                            Just found ->
                                Just found

                            Nothing ->
                                findParentIdHelper parentId targetId rest

                    VSplit r ->
                        case findParentIdHelper (Just r.id) targetId (List.filterMap identity [ r.top, r.bottom ]) of
                            Just found ->
                                Just found

                            Nothing ->
                                findParentIdHelper parentId targetId rest

                    HSplit r ->
                        case findParentIdHelper (Just r.id) targetId (List.filterMap identity [ r.left, r.right ]) of
                            Just found ->
                                Just found

                            Nothing ->
                                findParentIdHelper parentId targetId rest

                    _ ->
                        findParentIdHelper parentId targetId rest


viewPropertiesFor : Model -> ObjectId -> LabelObject -> Html Msg
viewPropertiesFor model objId obj =
    case obj of
        Container r ->
            div [ class "space-y-2" ]
                [ propField "Nombre"
                    (propTextInput r.name (\v -> UpdateObjectProperty objId (SetContainerName v)) CommitContent)
                , propRow "X"
                    (propNumberInput (String.fromFloat r.x) (\v -> UpdateObjectProperty objId (SetContainerX v)) CommitContent)
                    "Y"
                    (propNumberInput (String.fromFloat r.y) (\v -> UpdateObjectProperty objId (SetContainerY v)) CommitContent)
                , propRow "Ancho"
                    (propNumberInput (String.fromFloat r.width) (\v -> UpdateObjectProperty objId (SetContainerWidth v)) CommitContent)
                    "Alto"
                    (propNumberInput (String.fromFloat r.height) (\v -> UpdateObjectProperty objId (SetContainerHeight v)) CommitContent)
                ]

        VSplit r ->
            div [ class "space-y-2" ]
                [ propField "Nombre"
                    (propTextInput r.name (\v -> UpdateObjectProperty objId (SetContainerName v)) CommitContent)
                , propField "Divisi\u{00F3}n (%)"
                    (propNumberInput (String.fromFloat r.split) (\v -> UpdateObjectProperty objId (SetSplitPercent v)) CommitContent)
                ]

        HSplit r ->
            div [ class "space-y-2" ]
                [ propField "Nombre"
                    (propTextInput r.name (\v -> UpdateObjectProperty objId (SetContainerName v)) CommitContent)
                , propField "Divisi\u{00F3}n (%)"
                    (propNumberInput (String.fromFloat r.split) (\v -> UpdateObjectProperty objId (SetSplitPercent v)) CommitContent)
                ]

        TextObj r ->
            div [ class "space-y-2" ]
                [ propField "Contenido"
                    (propTextArea r.content (\v -> UpdateObjectProperty objId (SetTextContent v)) CommitContent)
                , viewTextPropertiesInputs objId r.properties
                ]

        VariableObj r ->
            div [ class "space-y-2" ]
                [ propField "Variable"
                    (propTextInput r.name (\v -> UpdateObjectProperty objId (SetVariableName v)) CommitContent)
                , propField "Valor de ejemplo"
                    (propTextArea
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
                [ if String.isEmpty r.url then
                    button
                        [ class "w-full px-3 py-2 text-sm font-medium bg-label-100 text-label-700 rounded-lg hover:bg-label-200 transition-colors"
                        , onClick (SelectImage objId)
                        ]
                        [ text "Subir imagen" ]

                  else
                    div [ class "space-y-2" ]
                        [ img
                            [ Html.Attributes.src r.url
                            , class "w-full h-24 object-contain rounded border border-gray-200 bg-gray-50"
                            ]
                            []
                        , div [ class "flex gap-2" ]
                            [ button
                                [ class "flex-1 px-3 py-1.5 text-xs font-medium bg-label-100 text-label-700 rounded-lg hover:bg-label-200 transition-colors"
                                , onClick (SelectImage objId)
                                ]
                                [ text "Cambiar" ]
                            , button
                                [ class "flex-1 px-3 py-1.5 text-xs font-medium bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors"
                                , onClick (UpdateObjectProperty objId (SetImageUrl ""))
                                ]
                                [ text "Eliminar" ]
                            ]
                        ]
                , propField "URL"
                    (propTextInput r.url (\v -> UpdateObjectProperty objId (SetImageUrl v)) CommitContent)
                ]


viewTextPropertiesInputs : ObjectId -> LO.TextProperties -> Html Msg
viewTextPropertiesInputs objId props =
    div [ class "space-y-2" ]
        [ propField "Fuente"
            (propTextInput props.fontFamily (\v -> UpdateObjectProperty objId (SetFontFamily v)) CommitContent)
        , viewFontWeightButtons objId props.fontWeight
        , propField "Tama\u{00F1}o m\u{00E1}x."
            (propNumberInput (String.fromFloat props.fontSize) (\v -> UpdateObjectProperty objId (SetFontSize v)) CommitContent)
        , propField "Interlineado"
            (input
                [ type_ "number"
                , class "w-full border border-gray-300 rounded px-2 py-1 text-sm"
                , value (String.fromFloat props.lineHeight)
                , Html.Attributes.min "0.5"
                , Html.Attributes.max "3.0"
                , step "0.1"
                , onInput (\v -> UpdateObjectProperty objId (SetLineHeight v))
                , onBlur CommitContent
                ]
                []
            )
        , viewHAlignButtons objId props.hAlign
        , viewVAlignButtons objId props.vAlign
        , viewColorInputs objId props.color
        ]


viewFontWeightButtons : ObjectId -> String -> Html Msg
viewFontWeightButtons objId current =
    div []
        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Grosor" ]
        , div [ class "flex rounded-lg overflow-hidden border border-gray-300" ]
            [ alignButton "Normal" (current == "normal") (UpdateObjectProperty objId (SetFontWeight "normal"))
            , alignButton "Negrita" (current == "bold") (UpdateObjectProperty objId (SetFontWeight "bold"))
            ]
        ]


viewHAlignButtons : ObjectId -> LO.HAlign -> Html Msg
viewHAlignButtons objId current =
    div []
        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Alineaci\u{00F3}n horizontal" ]
        , div [ class "flex rounded-lg overflow-hidden border border-gray-300" ]
            [ alignButton "Izq." (current == LO.AlignLeft) (UpdateObjectProperty objId (SetHAlign LO.AlignLeft))
            , alignButton "Centro" (current == LO.AlignCenter) (UpdateObjectProperty objId (SetHAlign LO.AlignCenter))
            , alignButton "Der." (current == LO.AlignRight) (UpdateObjectProperty objId (SetHAlign LO.AlignRight))
            ]
        ]


viewVAlignButtons : ObjectId -> LO.VAlign -> Html Msg
viewVAlignButtons objId current =
    div []
        [ label [ class "block text-xs text-gray-500 mb-1" ] [ text "Alineaci\u{00F3}n vertical" ]
        , div [ class "flex rounded-lg overflow-hidden border border-gray-300" ]
            [ alignButton "Arriba" (current == LO.AlignTop) (UpdateObjectProperty objId (SetVAlign LO.AlignTop))
            , alignButton "Medio" (current == LO.AlignMiddle) (UpdateObjectProperty objId (SetVAlign LO.AlignMiddle))
            , alignButton "Abajo" (current == LO.AlignBottom) (UpdateObjectProperty objId (SetVAlign LO.AlignBottom))
            ]
        ]


alignButton : String -> Bool -> Msg -> Html Msg
alignButton lbl isActive msg =
    button
        [ class
            (if isActive then
                "flex-1 px-2 py-1.5 text-xs font-medium bg-label-600 text-white"

             else
                "flex-1 px-2 py-1.5 text-xs font-medium bg-gray-100 text-gray-600 hover:bg-gray-200"
            )
        , onClick msg
        ]
        [ text lbl ]


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


propTextArea : String -> (String -> Msg) -> Msg -> Html Msg
propTextArea val toMsg blurMsg =
    textarea
        [ rows 2
        , class "w-full border border-gray-300 rounded px-2 py-1 text-sm resize-y"
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


resizeHandles : ObjectId -> Float -> Float -> List (Svg.Svg Msg)
resizeHandles objId w h =
    let
        hs =
            8

        half =
            hs / 2

        handle cx cy cursor handleType =
            Svg.rect
                [ SA.x (String.fromFloat (cx - half))
                , SA.y (String.fromFloat (cy - half))
                , SA.width (String.fromFloat hs)
                , SA.height (String.fromFloat hs)
                , SA.fill "#3b82f6"
                , SA.stroke "white"
                , SA.strokeWidth "1"
                , SA.cursor cursor
                , onSvgMouseDown objId (ResizingHandle handleType)
                ]
                []
    in
    [ handle 0 0 "nwse-resize" TopLeft
    , handle w 0 "nesw-resize" TopRight
    , handle 0 h "nesw-resize" BottomLeft
    , handle w h "nwse-resize" BottomRight
    ]


onSvgMouseDown : ObjectId -> DragMode -> Svg.Attribute Msg
onSvgMouseDown objId mode =
    Html.Events.custom "mousedown"
        (Decode.map2
            (\cx cy ->
                { message = SvgMouseDown objId mode cx cy
                , stopPropagation = True
                , preventDefault = True
                }
            )
            (Decode.field "clientX" Decode.float)
            (Decode.field "clientY" Decode.float)
        )


onSplitDragStart : ObjectId -> Float -> Float -> Svg.Attribute Msg
onSplitDragStart objId containerW containerH =
    Html.Events.custom "mousedown"
        (Decode.map2
            (\cx cy ->
                { message = SplitDragStart objId cx cy containerW containerH
                , stopPropagation = True
                , preventDefault = True
                }
            )
            (Decode.field "clientX" Decode.float)
            (Decode.field "clientY" Decode.float)
        )


onDragStart : Msg -> Html.Attribute Msg
onDragStart msg =
    Html.Events.on "dragstart" (Decode.succeed msg)


onDragOver : Model -> ObjectId -> Bool -> Html.Attribute Msg
onDragOver model objId isContainer =
    Html.Events.preventDefaultOn "dragover"
        (Decode.map2
            (\offsetY targetHeight ->
                let
                    ratio =
                        offsetY / targetHeight

                    target =
                        if ratio < 0.25 then
                            DropBefore objId

                        else if ratio > 0.75 then
                            DropAfter objId

                        else if isContainer then
                            DropInto objId

                        else if ratio < 0.5 then
                            DropBefore objId

                        else
                            DropAfter objId
                in
                ( TreeDragOver target, True )
            )
            (Decode.field "offsetY" Decode.float)
            (Decode.at [ "currentTarget", "offsetHeight" ] Decode.float)
        )


onDrop : Msg -> Html.Attribute Msg
onDrop msg =
    Html.Events.preventDefaultOn "drop" (Decode.succeed ( msg, True ))


onDragEnd : Msg -> Html.Attribute Msg
onDragEnd msg =
    Html.Events.on "dragend" (Decode.succeed msg)
