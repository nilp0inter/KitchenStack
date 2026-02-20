module Page.Home exposing (Model, Msg, OutMsg, init, subscriptions, update, view)

import Api
import Api.Encoders as Encoders
import Browser.Events
import Data.LabelObject as LO exposing (LabelObject(..), ObjectId)
import Data.LabelTypes exposing (LabelTypeSpec, labelTypes, silverRatioHeight)
import Dict
import Html exposing (Html)
import Json.Decode as Decode
import Page.Home.Types as Types exposing (DragMode(..), DropTarget(..), PropertyChange(..))
import Types exposing (Committable(..), getValue)
import Page.Home.View as View
import Ports


type alias Model =
    Types.Model


type alias Msg =
    Types.Msg


type alias OutMsg =
    Types.OutMsg


init : String -> ( Model, Cmd Msg, OutMsg )
init templateId =
    ( Types.initialModel templateId
    , Api.fetchTemplateDetail templateId Types.GotTemplateDetail
    , Types.NoOutMsg
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.dragState of
        Nothing ->
            Sub.none

        Just _ ->
            Sub.batch
                [ Browser.Events.onMouseMove
                    (Decode.map2 Types.SvgMouseMove
                        (Decode.field "clientX" Decode.float)
                        (Decode.field "clientY" Decode.float)
                    )
                , Browser.Events.onMouseUp (Decode.succeed Types.SvgMouseUp)
                ]


computeScaleFactor : Model -> Float
computeScaleFactor model =
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
    in
    Basics.min 1.0 (500.0 / toFloat displayWidth)


applyDrag : Types.DragState -> Float -> Float -> { x : Float, y : Float, width : Float, height : Float }
applyDrag drag mouseX mouseY =
    let
        dx =
            mouseX - drag.startMouse.x

        dy =
            mouseY - drag.startMouse.y

        sr =
            drag.startRect

        clampMin v =
            Basics.max 10 v
    in
    case drag.mode of
        Moving ->
            { x = sr.x + dx, y = sr.y + dy, width = sr.width, height = sr.height }

        ResizingHandle Types.TopLeft ->
            { x = sr.x + dx
            , y = sr.y + dy
            , width = clampMin (sr.width - dx)
            , height = clampMin (sr.height - dy)
            }

        ResizingHandle Types.TopRight ->
            { x = sr.x
            , y = sr.y + dy
            , width = clampMin (sr.width + dx)
            , height = clampMin (sr.height - dy)
            }

        ResizingHandle Types.BottomLeft ->
            { x = sr.x + dx
            , y = sr.y
            , width = clampMin (sr.width - dx)
            , height = clampMin (sr.height + dy)
            }

        ResizingHandle Types.BottomRight ->
            { x = sr.x
            , y = sr.y
            , width = clampMin (sr.width + dx)
            , height = clampMin (sr.height + dy)
            }

        Types.DraggingSplit ->
            -- DraggingSplit is handled separately in SvgMouseMove; this is a fallback
            { x = sr.x, y = sr.y, width = sr.width, height = sr.height }


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        Types.GotTemplateDetail (Ok (Just detail)) ->
            let
                newModel =
                    Types.applyTemplateDetail detail model
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

        Types.GotTemplateDetail (Ok Nothing) ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.GotTemplateDetail (Err _) ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.LabelTypeChanged newId ->
            let
                maybeSpec =
                    List.head (List.filter (\s -> s.id == newId) labelTypes)

                newModel =
                    case maybeSpec of
                        Just spec ->
                            { model
                                | labelTypeId = spec.id
                                , labelWidth = spec.width
                                , labelHeight =
                                    Clean
                                        (case spec.height of
                                            Just h ->
                                                h

                                            Nothing ->
                                                silverRatioHeight spec.width
                                        )
                                , cornerRadius =
                                    if spec.isRound then
                                        spec.width // 2

                                    else
                                        0
                                , rotate = not spec.isEndless && not spec.isRound
                                , computedTexts = Dict.empty
                            }

                        Nothing ->
                            model
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )
                |> withCmd
                    (Api.setTemplateLabelType model.templateId
                        newModel.labelTypeId
                        newModel.labelWidth
                        (getValue newModel.labelHeight)
                        newModel.cornerRadius
                        newModel.rotate
                        Types.EventEmitted
                    )

        Types.HeightChanged str ->
            case String.toInt str of
                Just h ->
                    let
                        newModel =
                            { model | labelHeight = Dirty h, computedTexts = Dict.empty }
                    in
                    ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.PaddingChanged str ->
            case String.toInt str of
                Just p ->
                    let
                        newModel =
                            { model | padding = Dirty p, computedTexts = Dict.empty }
                    in
                    ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.RotateChanged newRotate ->
            let
                newModel =
                    { model | rotate = newRotate, computedTexts = Dict.empty }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )
                |> withCmd
                    (Api.setTemplateLabelType model.templateId
                        newModel.labelTypeId
                        newModel.labelWidth
                        (getValue newModel.labelHeight)
                        newModel.cornerRadius
                        newModel.rotate
                        Types.EventEmitted
                    )

        Types.SelectObject maybeId ->
            ( { model | selectedObjectId = maybeId }, Cmd.none, Types.NoOutMsg )

        Types.AddObject newObj ->
            let
                parentId =
                    case model.selectedObjectId of
                        Just selId ->
                            case LO.findObject selId (getValue model.content) of
                                Just (Container _) ->
                                    Just selId

                                _ ->
                                    Nothing

                        Nothing ->
                            Nothing

                newContent =
                    LO.addObjectTo parentId newObj (getValue model.content)

                newModel =
                    { model
                        | content = Clean newContent
                        , nextId = model.nextId + 1
                        , computedTexts = Dict.empty
                    }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )
                |> withContentCmd newModel

        Types.RemoveObject targetId ->
            let
                newContent =
                    LO.removeObjectFromTree targetId (getValue model.content)

                newModel =
                    { model
                        | content = Clean newContent
                        , selectedObjectId =
                            if model.selectedObjectId == Just targetId then
                                Nothing

                            else
                                model.selectedObjectId
                        , computedTexts = Dict.remove targetId model.computedTexts
                    }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )
                |> withContentCmd newModel

        Types.UpdateObjectProperty targetId change ->
            let
                newContent =
                    LO.updateObjectInTree targetId (applyPropertyChange change) (getValue model.content)

                needsRemeasure =
                    case change of
                        SetTextContent _ ->
                            True

                        SetVariableName _ ->
                            True

                        SetFontSize _ ->
                            True

                        SetFontFamily _ ->
                            True

                        SetContainerName _ ->
                            False

                        SetContainerX _ ->
                            False

                        SetContainerY _ ->
                            False

                        SetContainerWidth _ ->
                            True

                        SetContainerHeight _ ->
                            True

                        SetSplitPercent _ ->
                            True

                        _ ->
                            False

                isImmediate =
                    case change of
                        SetShapeType _ ->
                            True

                        SetHAlign _ ->
                            True

                        SetVAlign _ ->
                            True

                        _ ->
                            False

                wrappedContent =
                    if isImmediate then
                        Clean newContent

                    else
                        Dirty newContent

                newModel =
                    { model
                        | content = wrappedContent
                        , computedTexts =
                            if needsRemeasure then
                                Dict.empty

                            else
                                model.computedTexts
                    }

                result =
                    if needsRemeasure then
                        ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

                    else
                        ( newModel, Cmd.none, Types.NoOutMsg )
            in
            if isImmediate then
                result |> withContentCmd newModel

            else
                result

        Types.UpdateSampleValue varName val ->
            let
                newModel =
                    { model
                        | sampleValues = Dict.insert varName (Dirty val) model.sampleValues
                        , computedTexts = Dict.empty
                    }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

        Types.TemplateNameChanged name ->
            ( { model | templateName = Dirty name }, Cmd.none, Types.NoOutMsg )

        Types.GotTextMeasureResult result ->
            ( { model
                | computedTexts =
                    Dict.insert result.requestId
                        { fittedFontSize = result.fittedFontSize
                        , lines = result.lines
                        }
                        model.computedTexts
              }
            , Cmd.none
            , Types.NoOutMsg
            )

        Types.CommitTemplateName ->
            case model.templateName of
                Dirty name ->
                    ( { model | templateName = Clean name }
                    , Api.setTemplateName model.templateId name Types.EventEmitted
                    , Types.NoOutMsg
                    )

                Clean _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.CommitHeight ->
            case model.labelHeight of
                Dirty h ->
                    ( { model | labelHeight = Clean h }
                    , Api.setTemplateHeight model.templateId h Types.EventEmitted
                    , Types.NoOutMsg
                    )

                Clean _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.CommitPadding ->
            case model.padding of
                Dirty p ->
                    ( { model | padding = Clean p }
                    , Api.setTemplatePadding model.templateId p Types.EventEmitted
                    , Types.NoOutMsg
                    )

                Clean _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.CommitContent ->
            case model.content of
                Dirty content ->
                    let
                        newModel =
                            { model | content = Clean content }
                    in
                    ( newModel, Cmd.none, Types.NoOutMsg )
                        |> withContentCmd newModel

                Clean _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.CommitSampleValue varName ->
            case Dict.get varName model.sampleValues of
                Just (Dirty val) ->
                    ( { model | sampleValues = Dict.insert varName (Clean val) model.sampleValues }
                    , Api.setTemplateSampleValue model.templateId varName val Types.EventEmitted
                    , Types.NoOutMsg
                    )

                _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.SvgMouseDown targetId mode mouseX mouseY ->
            case LO.findObject targetId (getValue model.content) of
                Just (Container r) ->
                    let
                        drag =
                            { mode = mode
                            , targetId = targetId
                            , startMouse = { x = mouseX, y = mouseY }
                            , startRect = { x = r.x, y = r.y, width = r.width, height = r.height }
                            , startSplit = 0
                            }
                    in
                    ( { model | dragState = Just drag, selectedObjectId = Just targetId }
                    , Cmd.none
                    , Types.NoOutMsg
                    )

                _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.SplitDragStart targetId mouseX mouseY containerW containerH ->
            case LO.findObject targetId (getValue model.content) of
                Just (VSplit r) ->
                    let
                        drag =
                            { mode = Types.DraggingSplit
                            , targetId = targetId
                            , startMouse = { x = mouseX, y = mouseY }
                            , startRect = { x = 0, y = 0, width = containerW, height = containerH }
                            , startSplit = r.split
                            }
                    in
                    ( { model | dragState = Just drag, selectedObjectId = Just targetId }
                    , Cmd.none
                    , Types.NoOutMsg
                    )

                Just (HSplit r) ->
                    let
                        drag =
                            { mode = Types.DraggingSplit
                            , targetId = targetId
                            , startMouse = { x = mouseX, y = mouseY }
                            , startRect = { x = 0, y = 0, width = containerW, height = containerH }
                            , startSplit = r.split
                            }
                    in
                    ( { model | dragState = Just drag, selectedObjectId = Just targetId }
                    , Cmd.none
                    , Types.NoOutMsg
                    )

                _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.SvgMouseMove mouseX mouseY ->
            case model.dragState of
                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

                Just drag ->
                    let
                        sf =
                            computeScaleFactor model

                        svgDx =
                            (mouseX - drag.startMouse.x) / sf

                        svgDy =
                            (mouseY - drag.startMouse.y) / sf
                    in
                    case drag.mode of
                        Types.DraggingSplit ->
                            let
                                newContent =
                                    LO.updateObjectInTree drag.targetId
                                        (\obj ->
                                            case obj of
                                                VSplit r ->
                                                    let
                                                        initialSplitPx =
                                                            drag.startRect.height * drag.startSplit / 100

                                                        newSplit =
                                                            clamp 5 95 ((initialSplitPx + svgDy) / drag.startRect.height * 100)
                                                    in
                                                    VSplit { r | split = newSplit }

                                                HSplit r ->
                                                    let
                                                        initialSplitPx =
                                                            drag.startRect.width * drag.startSplit / 100

                                                        newSplit =
                                                            clamp 5 95 ((initialSplitPx + svgDx) / drag.startRect.width * 100)
                                                    in
                                                    HSplit { r | split = newSplit }

                                                _ ->
                                                    obj
                                        )
                                        (getValue model.content)
                            in
                            ( { model | content = Dirty newContent }
                            , Cmd.none
                            , Types.NoOutMsg
                            )

                        _ ->
                            let
                                svgRect =
                                    applyDrag { drag | startMouse = { x = 0, y = 0 } } svgDx svgDy

                                newContent =
                                    LO.updateObjectInTree drag.targetId
                                        (\obj ->
                                            case obj of
                                                Container r ->
                                                    Container
                                                        { r
                                                            | x = svgRect.x
                                                            , y = svgRect.y
                                                            , width = svgRect.width
                                                            , height = svgRect.height
                                                        }

                                                _ ->
                                                    obj
                                        )
                                        (getValue model.content)
                            in
                            ( { model | content = Dirty newContent }
                            , Cmd.none
                            , Types.NoOutMsg
                            )

        Types.SvgMouseUp ->
            case model.dragState of
                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

                Just drag ->
                    let
                        needsRemeasure =
                            case drag.mode of
                                Moving ->
                                    False

                                ResizingHandle _ ->
                                    True

                                Types.DraggingSplit ->
                                    True

                        newModel =
                            { model
                                | dragState = Nothing
                                , computedTexts =
                                    if needsRemeasure then
                                        Dict.empty

                                    else
                                        model.computedTexts
                            }
                    in
                    case newModel.content of
                        Dirty content ->
                            let
                                committedModel =
                                    { newModel | content = Clean content }
                            in
                            if needsRemeasure then
                                ( committedModel, Cmd.none, Types.requestAllMeasurements committedModel )
                                    |> withContentCmd committedModel

                            else
                                ( committedModel, Cmd.none, Types.NoOutMsg )
                                    |> withContentCmd committedModel

                        Clean _ ->
                            ( newModel, Cmd.none, Types.NoOutMsg )

        Types.TreeDragStart draggedId ->
            ( { model | treeDragState = Just { draggedId = draggedId, dropTarget = Nothing } }
            , Cmd.none
            , Types.NoOutMsg
            )

        Types.TreeDragOver dropTarget ->
            case model.treeDragState of
                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

                Just tds ->
                    ( { model | treeDragState = Just { tds | dropTarget = Just dropTarget } }
                    , Cmd.none
                    , Types.NoOutMsg
                    )

        Types.TreeDrop ->
            case model.treeDragState of
                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

                Just tds ->
                    case tds.dropTarget of
                        Nothing ->
                            ( { model | treeDragState = Nothing }, Cmd.none, Types.NoOutMsg )

                        Just target ->
                            let
                                currentContent =
                                    getValue model.content

                                targetId =
                                    case target of
                                        DropBefore tid ->
                                            tid

                                        DropAfter tid ->
                                            tid

                                        DropInto tid ->
                                            tid

                                        DropIntoSlot tid _ ->
                                            tid

                                -- Prevent dropping into own descendants
                                isSelfOrDescendant =
                                    (tds.draggedId == targetId)
                                        || LO.isDescendantOf targetId tds.draggedId currentContent

                                ( maybeObj, withoutObj ) =
                                    LO.removeAndReturn tds.draggedId currentContent
                            in
                            case ( maybeObj, isSelfOrDescendant ) of
                                ( Just obj, False ) ->
                                    let
                                        newContent =
                                            case target of
                                                DropBefore tid ->
                                                    LO.insertAtTarget tid True obj withoutObj

                                                DropAfter tid ->
                                                    LO.insertAtTarget tid False obj withoutObj

                                                DropInto tid ->
                                                    LO.addObjectTo (Just tid) obj withoutObj

                                                DropIntoSlot splitId slot ->
                                                    LO.addObjectToSlot splitId slot obj withoutObj

                                        newModel =
                                            { model
                                                | content = Clean newContent
                                                , treeDragState = Nothing
                                            }
                                    in
                                    ( newModel, Cmd.none, Types.NoOutMsg )
                                        |> withContentCmd newModel

                                _ ->
                                    ( { model | treeDragState = Nothing }, Cmd.none, Types.NoOutMsg )

        Types.TreeDragEnd ->
            ( { model | treeDragState = Nothing }, Cmd.none, Types.NoOutMsg )

        Types.MoveObjectToParent objId maybeParentId ->
            let
                currentContent =
                    getValue model.content

                ( maybeObj, withoutObj ) =
                    LO.removeAndReturn objId currentContent
            in
            case maybeObj of
                Just obj ->
                    let
                        newContent =
                            LO.addObjectTo maybeParentId obj withoutObj

                        newModel =
                            { model | content = Clean newContent }
                    in
                    ( newModel, Cmd.none, Types.NoOutMsg )
                        |> withContentCmd newModel

                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.MoveObjectToSlot objId splitId slotPosition ->
            let
                currentContent =
                    getValue model.content

                ( maybeObj, withoutObj ) =
                    LO.removeAndReturn objId currentContent
            in
            case maybeObj of
                Just obj ->
                    let
                        newContent =
                            LO.addObjectToSlot splitId slotPosition obj withoutObj

                        newModel =
                            { model | content = Clean newContent }
                    in
                    ( newModel, Cmd.none, Types.NoOutMsg )
                        |> withContentCmd newModel

                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.AutoSave ->
            let
                ( m1, c1, _ ) =
                    update Types.CommitTemplateName model

                ( m2, c2, _ ) =
                    update Types.CommitHeight m1

                ( m3, c3, _ ) =
                    update Types.CommitPadding m2

                ( m4, c4, _ ) =
                    update Types.CommitContent m3

                dirtyVarNames =
                    Dict.toList m4.sampleValues
                        |> List.filterMap
                            (\( k, v ) ->
                                case v of
                                    Dirty _ ->
                                        Just k

                                    Clean _ ->
                                        Nothing
                            )

                ( m5, c5s ) =
                    List.foldl
                        (\varName ( accModel, accCmds ) ->
                            let
                                ( nm, nc, _ ) =
                                    update (Types.CommitSampleValue varName) accModel
                            in
                            ( nm, nc :: accCmds )
                        )
                        ( m4, [] )
                        dirtyVarNames
            in
            ( m5, Cmd.batch (c1 :: c2 :: c3 :: c4 :: c5s), Types.NoOutMsg )

        Types.SelectImage objId ->
            ( model
            , Cmd.none
            , Types.RequestFileSelect
                { requestId = objId
                , maxSizeKb = 500
                , acceptTypes = [ "image/png", "image/jpeg", "image/webp" ]
                }
            )

        Types.GotImageResult result ->
            case result.dataUrl of
                Just url ->
                    let
                        newContent =
                            LO.updateObjectInTree result.requestId
                                (\obj ->
                                    case obj of
                                        ImageObj r ->
                                            ImageObj { r | url = url }

                                        _ ->
                                            obj
                                )
                                (getValue model.content)

                        newModel =
                            { model | content = Clean newContent }
                    in
                    ( newModel, Cmd.none, Types.NoOutMsg )
                        |> withContentCmd newModel

                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.EventEmitted _ ->
            ( model, Cmd.none, Types.NoOutMsg )


withCmd : Cmd Msg -> ( Model, Cmd Msg, OutMsg ) -> ( Model, Cmd Msg, OutMsg )
withCmd extraCmd ( model, cmd, outMsg ) =
    ( model
    , Cmd.batch [ cmd, extraCmd ]
    , outMsg
    )


withContentCmd : Model -> ( Model, Cmd Msg, OutMsg ) -> ( Model, Cmd Msg, OutMsg )
withContentCmd newModel tuple =
    withCmd
        (Api.setTemplateContent newModel.templateId
            (Encoders.encodeLabelObjectList (getValue newModel.content))
            newModel.nextId
            Types.EventEmitted
        )
        tuple


applyPropertyChange : PropertyChange -> LabelObject -> LabelObject
applyPropertyChange change obj =
    case ( change, obj ) of
        ( SetTextContent val, TextObj r ) ->
            TextObj { r | content = val }

        ( SetVariableName val, VariableObj r ) ->
            VariableObj { r | name = val }

        ( SetFontSize val, TextObj r ) ->
            case String.toFloat val of
                Just s ->
                    TextObj { r | properties = setFontSize s r.properties }

                Nothing ->
                    obj

        ( SetFontSize val, VariableObj r ) ->
            case String.toFloat val of
                Just s ->
                    VariableObj { r | properties = setFontSize s r.properties }

                Nothing ->
                    obj

        ( SetFontFamily val, TextObj r ) ->
            TextObj { r | properties = setFontFamily val r.properties }

        ( SetFontFamily val, VariableObj r ) ->
            VariableObj { r | properties = setFontFamily val r.properties }

        ( SetColorR val, TextObj r ) ->
            case String.toInt val of
                Just v ->
                    TextObj { r | properties = setColorR v r.properties }

                Nothing ->
                    obj

        ( SetColorR val, VariableObj r ) ->
            case String.toInt val of
                Just v ->
                    VariableObj { r | properties = setColorR v r.properties }

                Nothing ->
                    obj

        ( SetColorR val, ShapeObj r ) ->
            case String.toInt val of
                Just v ->
                    ShapeObj { r | properties = setShapeColorR v r.properties }

                Nothing ->
                    obj

        ( SetColorG val, TextObj r ) ->
            case String.toInt val of
                Just v ->
                    TextObj { r | properties = setColorG v r.properties }

                Nothing ->
                    obj

        ( SetColorG val, VariableObj r ) ->
            case String.toInt val of
                Just v ->
                    VariableObj { r | properties = setColorG v r.properties }

                Nothing ->
                    obj

        ( SetColorG val, ShapeObj r ) ->
            case String.toInt val of
                Just v ->
                    ShapeObj { r | properties = setShapeColorG v r.properties }

                Nothing ->
                    obj

        ( SetColorB val, TextObj r ) ->
            case String.toInt val of
                Just v ->
                    TextObj { r | properties = setColorB v r.properties }

                Nothing ->
                    obj

        ( SetColorB val, VariableObj r ) ->
            case String.toInt val of
                Just v ->
                    VariableObj { r | properties = setColorB v r.properties }

                Nothing ->
                    obj

        ( SetColorB val, ShapeObj r ) ->
            case String.toInt val of
                Just v ->
                    ShapeObj { r | properties = setShapeColorB v r.properties }

                Nothing ->
                    obj

        ( SetContainerName val, Container r ) ->
            Container { r | name = val }

        ( SetContainerName val, VSplit r ) ->
            VSplit { r | name = val }

        ( SetContainerName val, HSplit r ) ->
            HSplit { r | name = val }

        ( SetContainerX val, Container r ) ->
            case String.toFloat val of
                Just v ->
                    Container { r | x = v }

                Nothing ->
                    obj

        ( SetContainerY val, Container r ) ->
            case String.toFloat val of
                Just v ->
                    Container { r | y = v }

                Nothing ->
                    obj

        ( SetContainerWidth val, Container r ) ->
            case String.toFloat val of
                Just v ->
                    Container { r | width = v }

                Nothing ->
                    obj

        ( SetContainerHeight val, Container r ) ->
            case String.toFloat val of
                Just v ->
                    Container { r | height = v }

                Nothing ->
                    obj

        ( SetSplitPercent val, VSplit r ) ->
            case String.toFloat val of
                Just v ->
                    VSplit { r | split = clamp 5 95 v }

                Nothing ->
                    obj

        ( SetSplitPercent val, HSplit r ) ->
            case String.toFloat val of
                Just v ->
                    HSplit { r | split = clamp 5 95 v }

                Nothing ->
                    obj

        ( SetShapeType shapeType, ShapeObj r ) ->
            let
                props =
                    r.properties
            in
            ShapeObj { r | properties = { props | shapeType = shapeType } }

        ( SetImageUrl val, ImageObj r ) ->
            ImageObj { r | url = val }

        ( SetHAlign align, TextObj r ) ->
            TextObj { r | properties = setHAlign align r.properties }

        ( SetHAlign align, VariableObj r ) ->
            VariableObj { r | properties = setHAlign align r.properties }

        ( SetVAlign align, TextObj r ) ->
            TextObj { r | properties = setVAlign align r.properties }

        ( SetVAlign align, VariableObj r ) ->
            VariableObj { r | properties = setVAlign align r.properties }

        _ ->
            obj



-- Text property helpers


setFontSize : Float -> LO.TextProperties -> LO.TextProperties
setFontSize s props =
    { props | fontSize = s }


setFontFamily : String -> LO.TextProperties -> LO.TextProperties
setFontFamily f props =
    { props | fontFamily = f }


setColorR : Int -> LO.TextProperties -> LO.TextProperties
setColorR v props =
    let
        c =
            props.color
    in
    { props | color = { c | r = v } }


setColorG : Int -> LO.TextProperties -> LO.TextProperties
setColorG v props =
    let
        c =
            props.color
    in
    { props | color = { c | g = v } }


setColorB : Int -> LO.TextProperties -> LO.TextProperties
setColorB v props =
    let
        c =
            props.color
    in
    { props | color = { c | b = v } }


setHAlign : LO.HAlign -> LO.TextProperties -> LO.TextProperties
setHAlign align props =
    { props | hAlign = align }


setVAlign : LO.VAlign -> LO.TextProperties -> LO.TextProperties
setVAlign align props =
    { props | vAlign = align }



-- Shape property helpers


setShapeColorR : Int -> LO.ShapeProperties -> LO.ShapeProperties
setShapeColorR v props =
    let
        c =
            props.color
    in
    { props | color = { c | r = v } }


setShapeColorG : Int -> LO.ShapeProperties -> LO.ShapeProperties
setShapeColorG v props =
    let
        c =
            props.color
    in
    { props | color = { c | g = v } }


setShapeColorB : Int -> LO.ShapeProperties -> LO.ShapeProperties
setShapeColorB v props =
    let
        c =
            props.color
    in
    { props | color = { c | b = v } }


view : Model -> Html Msg
view model =
    View.view model
