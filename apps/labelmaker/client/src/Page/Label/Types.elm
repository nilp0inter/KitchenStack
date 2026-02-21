module Page.Label.Types exposing
    ( ComputedText
    , Model
    , Msg(..)
    , OutMsg(..)
    , collectMeasurements
    , initialModel
    , requestAllMeasurements
    )

import Api.Decoders exposing (LabelDetail)
import Data.LabelObject as LO exposing (LabelObject(..), ObjectId)
import Dict exposing (Dict)
import Http
import Ports
import Types exposing (Committable(..), NotificationType, getValue)


type alias ComputedText =
    { fittedFontSize : Int
    , lines : List String
    }


type alias Model =
    { labelId : String
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
    , labelName : Committable String
    , values : Dict String (Committable String)
    , variableNames : List String
    , computedTexts : Dict ObjectId ComputedText
    , printing : Bool
    }


type Msg
    = GotLabelDetail (Result Http.Error (Maybe LabelDetail))
    | UpdateName String
    | CommitName
    | UpdateValue String String
    | CommitValues
    | GotTextMeasureResult Ports.TextMeasureResult
    | RequestPrint
    | GotPngResult Ports.PngResult
    | GotPrintResult (Result Http.Error ())
    | EventEmitted (Result Http.Error ())
    | AutoSave


type OutMsg
    = NoOutMsg
    | RequestTextMeasures (List Ports.TextMeasureRequest)
    | RequestSvgToPng Ports.SvgToPngRequest
    | ShowNotification String NotificationType


initialModel : String -> Model
initialModel labelId =
    { labelId = labelId
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
    , labelName = Clean ""
    , values = Dict.empty
    , variableNames = []
    , computedTexts = Dict.empty
    , printing = False
    }


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
                    Dict.get r.name model.values
                        |> Maybe.map getValue
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
