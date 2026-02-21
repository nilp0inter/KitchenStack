module Page.LabelSet.Types exposing
    ( CellMode(..)
    , ComputedText
    , Model
    , Msg(..)
    , OutMsg(..)
    , PrintProgress
    , cellId
    , collectMeasurements
    , initialModel
    , requestAllMeasurements
    , selectedRowValues
    )

import Api.Decoders exposing (LabelSetDetail)
import Browser.Dom
import Data.LabelObject as LO exposing (LabelObject(..), ObjectId)
import Dict exposing (Dict)
import Http
import Ports
import Types exposing (Committable(..), NotificationType, getValue)


type CellMode
    = Navigating
    | Editing


type alias ComputedText =
    { fittedFontSize : Int
    , lines : List String
    }


type alias PrintProgress =
    { current : Int
    , total : Int
    }


type alias Model =
    { labelsetId : String
    , templateId : String
    , templateName : String
    , labelTypeId : String
    , labelWidth : Int
    , labelHeight : Int
    , cornerRadius : Int
    , rotate : Bool
    , padding : Int
    , offsetX : Int
    , offsetY : Int
    , content : List LabelObject
    , labelsetName : Committable String
    , rows : Committable (List (Dict String String))
    , variableNames : List String
    , selectedRowIndex : Int
    , computedTexts : Dict ObjectId ComputedText
    , printing : Bool
    , printingAll : Bool
    , printProgress : Maybe PrintProgress
    , printQueue : List Int
    , focusedCell : Maybe ( Int, Int )
    , cellMode : CellMode
    , csvMode : Bool
    , csvText : String
    , csvError : Maybe String
    , fieldSeparator : Char
    }


type Msg
    = GotLabelSetDetail (Result Http.Error (Maybe LabelSetDetail))
    | SelectRow Int
    | UpdateCell Int String String
    | CommitRows
    | AddRow
    | DeleteRow Int
    | UpdateName String
    | CommitName
    | GotTextMeasureResult Ports.TextMeasureResult
    | RequestPrint
    | RequestPrintAll
    | GotPngResult Ports.PngResult
    | GotPrintResult (Result Http.Error ())
    | EventEmitted (Result Http.Error ())
    | CellClicked Int Int
    | CellKeyDown String Bool Bool Int Int
    | CellBlurred Int Int
    | FocusResult (Result Browser.Dom.Error ())
    | ToggleCsvMode
    | UpdateCsvText String
    | UpdateFieldSeparator String
    | AutoSave


type OutMsg
    = NoOutMsg
    | RequestTextMeasures (List Ports.TextMeasureRequest)
    | RequestSvgToPng Ports.SvgToPngRequest
    | ShowNotification String NotificationType


initialModel : String -> Model
initialModel labelsetId =
    { labelsetId = labelsetId
    , templateId = ""
    , templateName = "Cargando..."
    , labelTypeId = "62"
    , labelWidth = 696
    , labelHeight = 1680
    , cornerRadius = 0
    , rotate = False
    , padding = 20
    , offsetX = 0
    , offsetY = 0
    , content = []
    , labelsetName = Clean ""
    , rows = Clean []
    , variableNames = []
    , selectedRowIndex = 0
    , computedTexts = Dict.empty
    , printing = False
    , printingAll = False
    , printProgress = Nothing
    , printQueue = []
    , focusedCell = Nothing
    , cellMode = Navigating
    , csvMode = False
    , csvText = ""
    , csvError = Nothing
    , fieldSeparator = ','
    }


cellId : Int -> Int -> String
cellId row col =
    "cell-" ++ String.fromInt row ++ "-" ++ String.fromInt col


selectedRowValues : Model -> Dict String String
selectedRowValues model =
    List.drop model.selectedRowIndex (getValue model.rows)
        |> List.head
        |> Maybe.withDefault Dict.empty


requestAllMeasurements : Model -> OutMsg
requestAllMeasurements model =
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

        requests =
            collectMeasurements model (toFloat displayWidth) (toFloat displayHeight) model.content
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
        values =
            selectedRowValues model
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
                    round (parentW - toFloat (model.padding * 2))

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
              , maxHeight = round (parentH - toFloat (model.padding * 2))
              , fontWeight = r.properties.fontWeight
              , lineHeight = r.properties.lineHeight
              }
            ]

        VariableObj r ->
            let
                displayText =
                    Dict.get r.name values
                        |> Maybe.withDefault ("{{" ++ r.name ++ "}}")

                maxWidth =
                    round (parentW - toFloat (model.padding * 2))

                maxFontSize =
                    round r.properties.fontSize

                minFontSize =
                    Basics.max 6 (maxFontSize // 3)
            in
            [ { requestId = r.id
              , text = displayText
              , fontFamily = r.properties.fontFamily
              , maxFontSize = maxFontSize
              , minFontSize = minFontSize
              , maxWidth = maxWidth
              , maxHeight = round (parentH - toFloat (model.padding * 2))
              , fontWeight = r.properties.fontWeight
              , lineHeight = r.properties.lineHeight
              }
            ]

        ImageObj _ ->
            []

        ShapeObj _ ->
            []
