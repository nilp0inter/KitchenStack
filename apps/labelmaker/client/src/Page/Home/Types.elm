module Page.Home.Types exposing
    ( ComputedText
    , DragMode(..)
    , DragState
    , DropTarget(..)
    , Handle(..)
    , Model
    , Msg(..)
    , OutMsg(..)
    , PropertyChange(..)
    , TreeDragState
    , applyTemplateDetail
    , initialModel
    , requestAllMeasurements
    )

import Api.Decoders exposing (TemplateDetail)
import Data.LabelObject as LO exposing (LabelObject(..), ObjectId)
import Data.LabelTypes exposing (LabelTypeSpec, labelTypes, silverRatioHeight)
import Dict exposing (Dict)
import Http
import Ports
import Types exposing (Committable(..), getValue)


type alias ComputedText =
    { fittedFontSize : Int
    , lines : List String
    }


type DragMode
    = Moving
    | ResizingHandle Handle
    | DraggingSplit


type Handle
    = TopLeft
    | TopRight
    | BottomLeft
    | BottomRight


type alias DragState =
    { mode : DragMode
    , targetId : ObjectId
    , startMouse : { x : Float, y : Float }
    , startRect : { x : Float, y : Float, width : Float, height : Float }
    , startSplit : Float
    }


type alias TreeDragState =
    { draggedId : ObjectId
    , dropTarget : Maybe DropTarget
    }


type DropTarget
    = DropBefore ObjectId
    | DropAfter ObjectId
    | DropInto ObjectId
    | DropIntoSlot ObjectId LO.SlotPosition


type alias Model =
    { templateId : String
    , templateName : Committable String
    , labelTypeId : String
    , labelWidth : Int
    , labelHeight : Committable Int
    , cornerRadius : Int
    , rotate : Bool
    , content : Committable (List LabelObject)
    , selectedObjectId : Maybe ObjectId
    , sampleValues : Dict String (Committable String)
    , computedTexts : Dict ObjectId ComputedText
    , nextId : Int
    , padding : Committable Int
    , dragState : Maybe DragState
    , treeDragState : Maybe TreeDragState
    }


type Msg
    = LabelTypeChanged String
    | HeightChanged String
    | PaddingChanged String
    | RotateChanged Bool
    | SelectObject (Maybe ObjectId)
    | AddObject LabelObject
    | RemoveObject ObjectId
    | UpdateObjectProperty ObjectId PropertyChange
    | UpdateSampleValue String String
    | GotTextMeasureResult Ports.TextMeasureResult
    | GotTemplateDetail (Result Http.Error (Maybe TemplateDetail))
    | TemplateNameChanged String
    | EventEmitted (Result Http.Error ())
    | CommitTemplateName
    | CommitHeight
    | CommitPadding
    | CommitContent
    | CommitSampleValue String
    | SvgMouseDown ObjectId DragMode Float Float
    | SplitDragStart ObjectId Float Float Float Float
    | SvgMouseMove Float Float
    | SvgMouseUp
    | TreeDragStart ObjectId
    | TreeDragOver DropTarget
    | TreeDrop
    | TreeDragEnd
    | MoveObjectToParent ObjectId (Maybe ObjectId)
    | MoveObjectToSlot ObjectId ObjectId LO.SlotPosition
    | AutoSave
    | SelectImage ObjectId
    | GotImageResult Ports.FileSelectResult


type PropertyChange
    = SetTextContent String
    | SetVariableName String
    | SetFontSize String
    | SetFontFamily String
    | SetColorR String
    | SetColorG String
    | SetColorB String
    | SetContainerX String
    | SetContainerY String
    | SetContainerWidth String
    | SetContainerHeight String
    | SetContainerName String
    | SetShapeType LO.ShapeType
    | SetImageUrl String
    | SetHAlign LO.HAlign
    | SetVAlign LO.VAlign
    | SetSplitPercent String


type OutMsg
    = NoOutMsg
    | RequestTextMeasures (List Ports.TextMeasureRequest)
    | RequestFileSelect Ports.FileSelectRequest


initialModel : String -> Model
initialModel templateId =
    let
        defaultWidth =
            696

        defaultHeight =
            silverRatioHeight defaultWidth

        defaultVar =
            VariableObj
                { id = "obj-1"
                , name = "nombre"
                , properties = LO.defaultTextProperties
                }
    in
    { templateId = templateId
    , templateName = Clean "Cargando..."
    , labelTypeId = "62"
    , labelWidth = defaultWidth
    , labelHeight = Clean defaultHeight
    , cornerRadius = 0
    , rotate = False
    , content = Clean [ defaultVar ]
    , selectedObjectId = Nothing
    , sampleValues = Dict.fromList [ ( "nombre", Clean "Hello World!" ) ]
    , computedTexts = Dict.empty
    , nextId = 2
    , padding = Clean 20
    , dragState = Nothing
    , treeDragState = Nothing
    }


applyTemplateDetail : TemplateDetail -> Model -> Model
applyTemplateDetail detail model =
    { model
        | templateName = Clean detail.name
        , labelTypeId = detail.labelTypeId
        , labelWidth = detail.labelWidth
        , labelHeight = Clean detail.labelHeight
        , cornerRadius = detail.cornerRadius
        , rotate = detail.rotate
        , padding = Clean detail.padding
        , content = Clean detail.content
        , nextId = detail.nextId
        , sampleValues = Dict.map (\_ v -> Clean v) detail.sampleValues
        , computedTexts = Dict.empty
    }


requestAllMeasurements : Model -> OutMsg
requestAllMeasurements model =
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

        requests =
            collectMeasurements model (toFloat displayWidth) (toFloat displayHeight) (getValue model.content)
    in
    if List.isEmpty requests then
        NoOutMsg

    else
        RequestTextMeasures requests


collectMeasurements : Model -> Float -> Float -> List LabelObject -> List Ports.TextMeasureRequest
collectMeasurements model parentW parentH objects =
    List.concatMap (collectForObject model parentW parentH) objects


collectForObject : Model -> Float -> Float -> LabelObject -> List Ports.TextMeasureRequest
collectForObject model parentW parentH obj =
    let
        pad =
            getValue model.padding
    in
    case obj of
        Container r ->
            collectMeasurements model r.width r.height r.content

        VSplit r ->
            let
                topH =
                    parentH * r.split / 100

                bottomH =
                    parentH - topH

                topReqs =
                    r.top |> Maybe.map (collectForObject model parentW topH) |> Maybe.withDefault []

                bottomReqs =
                    r.bottom |> Maybe.map (collectForObject model parentW bottomH) |> Maybe.withDefault []
            in
            topReqs ++ bottomReqs

        HSplit r ->
            let
                leftW =
                    parentW * r.split / 100

                rightW =
                    parentW - leftW

                leftReqs =
                    r.left |> Maybe.map (collectForObject model leftW parentH) |> Maybe.withDefault []

                rightReqs =
                    r.right |> Maybe.map (collectForObject model rightW parentH) |> Maybe.withDefault []
            in
            leftReqs ++ rightReqs

        TextObj r ->
            let
                maxWidth =
                    round (parentW - toFloat (pad * 2))

                maxFontSize =
                    round r.properties.fontSize

                minFontSize =
                    Basics.max 6 (maxFontSize // 3)
            in
            [ { requestId = r.id
              , text = r.content
              , fontFamily = r.properties.fontFamily
              , maxFontSize = maxFontSize
              , minFontSize = minFontSize
              , maxWidth = maxWidth
              , maxHeight = round (parentH - toFloat (pad * 2))
              }
            ]

        VariableObj r ->
            let
                sampleText =
                    Dict.get r.name model.sampleValues
                        |> Maybe.map getValue
                        |> Maybe.withDefault ("{{" ++ r.name ++ "}}")

                maxWidth =
                    round (parentW - toFloat (pad * 2))

                maxFontSize =
                    round r.properties.fontSize

                minFontSize =
                    Basics.max 6 (maxFontSize // 3)
            in
            [ { requestId = r.id
              , text = sampleText
              , fontFamily = r.properties.fontFamily
              , maxFontSize = maxFontSize
              , minFontSize = minFontSize
              , maxWidth = maxWidth
              , maxHeight = round (parentH - toFloat (pad * 2))
              }
            ]

        ImageObj _ ->
            []

        ShapeObj _ ->
            []
