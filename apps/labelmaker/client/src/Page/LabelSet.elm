module Page.LabelSet exposing (Model, Msg, OutMsg, init, update, view)

import Api
import Data.LabelObject as LO
import Dict
import Html exposing (Html)
import Json.Encode as Encode
import Page.LabelSet.Types as Types
import Page.LabelSet.View as View
import Ports
import Types exposing (Committable(..), NotificationType(..), getValue)


type alias Model =
    Types.Model


type alias Msg =
    Types.Msg


type alias OutMsg =
    Types.OutMsg


init : String -> ( Model, Cmd Msg, OutMsg )
init labelsetId =
    ( Types.initialModel labelsetId
    , Api.fetchLabelSetDetail labelsetId Types.GotLabelSetDetail
    , Types.NoOutMsg
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        Types.GotLabelSetDetail (Ok (Just detail)) ->
            let
                newModel =
                    { model
                        | templateId = detail.templateId
                        , templateName = detail.templateName
                        , labelTypeId = detail.labelTypeId
                        , labelWidth = detail.labelWidth
                        , labelHeight = detail.labelHeight
                        , cornerRadius = detail.cornerRadius
                        , rotate = detail.rotate
                        , padding = detail.padding
                        , content = detail.content
                        , labelsetName = Clean detail.name
                        , rows = Clean detail.rows
                        , variableNames = LO.allVariableNames detail.content
                        , selectedRowIndex = 0
                        , computedTexts = Dict.empty
                    }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

        Types.GotLabelSetDetail (Ok Nothing) ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.GotLabelSetDetail (Err _) ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.SelectRow rowIndex ->
            let
                newModel =
                    { model
                        | selectedRowIndex = rowIndex
                        , computedTexts = Dict.empty
                    }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

        Types.UpdateCell rowIndex varName val ->
            let
                currentRows =
                    getValue model.rows

                newRows =
                    List.indexedMap
                        (\i row ->
                            if i == rowIndex then
                                Dict.insert varName val row

                            else
                                row
                        )
                        currentRows

                newModel =
                    { model | rows = Dirty newRows }

                measureOutMsg =
                    if rowIndex == model.selectedRowIndex then
                        Types.requestAllMeasurements { newModel | computedTexts = Dict.empty }

                    else
                        Types.NoOutMsg

                finalModel =
                    if rowIndex == model.selectedRowIndex then
                        { newModel | computedTexts = Dict.empty }

                    else
                        newModel
            in
            ( finalModel, Cmd.none, measureOutMsg )

        Types.CommitRows ->
            case model.rows of
                Dirty currentRows ->
                    ( { model | rows = Clean currentRows }
                    , emitRowsSet model.labelsetId currentRows
                    , Types.NoOutMsg
                    )

                Clean _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.AddRow ->
            let
                currentRows =
                    getValue model.rows

                emptyRow =
                    List.foldl (\varName dict -> Dict.insert varName "" dict) Dict.empty model.variableNames

                newRows =
                    currentRows ++ [ emptyRow ]

                newModel =
                    { model | rows = Clean newRows }
            in
            ( newModel
            , emitRowsSet model.labelsetId newRows
            , Types.NoOutMsg
            )

        Types.DeleteRow rowIndex ->
            let
                currentRows =
                    getValue model.rows

                newRows =
                    List.indexedMap Tuple.pair currentRows
                        |> List.filterMap
                            (\( i, row ) ->
                                if i == rowIndex then
                                    Nothing

                                else
                                    Just row
                            )

                newSelectedIndex =
                    if model.selectedRowIndex >= List.length newRows then
                        Basics.max 0 (List.length newRows - 1)

                    else if model.selectedRowIndex > rowIndex then
                        model.selectedRowIndex - 1

                    else
                        model.selectedRowIndex

                needsRemeasure =
                    model.selectedRowIndex == rowIndex || newSelectedIndex /= model.selectedRowIndex

                newModel =
                    { model
                        | rows = Clean newRows
                        , selectedRowIndex = newSelectedIndex
                        , computedTexts =
                            if needsRemeasure then
                                Dict.empty

                            else
                                model.computedTexts
                    }

                measureOutMsg =
                    if needsRemeasure then
                        Types.requestAllMeasurements newModel

                    else
                        Types.NoOutMsg
            in
            ( newModel
            , emitRowsSet model.labelsetId newRows
            , measureOutMsg
            )

        Types.UpdateName name ->
            ( { model | labelsetName = Dirty name }, Cmd.none, Types.NoOutMsg )

        Types.CommitName ->
            case model.labelsetName of
                Dirty name ->
                    ( { model | labelsetName = Clean name }
                    , Api.emitEvent "labelset_name_set"
                        (Encode.object
                            [ ( "labelset_id", Encode.string model.labelsetId )
                            , ( "name", Encode.string name )
                            ]
                        )
                        Types.EventEmitted
                    , Types.NoOutMsg
                    )

                Clean _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.GotTextMeasureResult result ->
            let
                newComputedTexts =
                    Dict.insert result.requestId
                        { fittedFontSize = result.fittedFontSize
                        , lines = result.lines
                        }
                        model.computedTexts

                newModel =
                    { model | computedTexts = newComputedTexts }

                allMeasured =
                    let
                        textIds =
                            LO.allTextObjectIds model.content
                    in
                    List.all (\tid -> Dict.member tid newComputedTexts) textIds
            in
            if allMeasured && model.printingAll then
                -- All texts measured during batch print — trigger SVG-to-PNG
                ( newModel
                , Cmd.none
                , Types.RequestSvgToPng
                    { svgId = "label-preview"
                    , requestId = "print"
                    , width = model.labelWidth
                    , height = model.labelHeight
                    , rotate = model.rotate
                    }
                )

            else
                ( newModel, Cmd.none, Types.NoOutMsg )

        Types.RequestPrint ->
            ( { model | printing = True }
            , Cmd.none
            , Types.RequestSvgToPng
                { svgId = "label-preview"
                , requestId = "print"
                , width = model.labelWidth
                , height = model.labelHeight
                , rotate = model.rotate
                }
            )

        Types.RequestPrintAll ->
            let
                rowCount =
                    List.length (getValue model.rows)

                newModel =
                    { model
                        | printingAll = True
                        , printing = True
                        , printProgress = Just { current = 1, total = rowCount }
                        , printQueue = List.range 1 (rowCount - 1)
                        , selectedRowIndex = 0
                        , computedTexts = Dict.empty
                    }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

        Types.GotPngResult result ->
            case result.dataUrl of
                Just dataUrl ->
                    let
                        base64 =
                            case String.split "," dataUrl of
                                _ :: rest ->
                                    String.join "," rest

                                _ ->
                                    dataUrl
                    in
                    ( model
                    , Api.printLabelPng base64 model.labelTypeId Types.GotPrintResult
                    , Types.NoOutMsg
                    )

                Nothing ->
                    ( { model | printing = False, printingAll = False, printProgress = Nothing, printQueue = [] }
                    , Cmd.none
                    , Types.ShowNotification
                        (Maybe.withDefault "Error al generar imagen" result.error)
                        Error
                    )

        Types.GotPrintResult (Ok _) ->
            if model.printingAll then
                case model.printQueue of
                    nextRowIndex :: restQueue ->
                        let
                            currentProgress =
                                model.printProgress
                                    |> Maybe.map (\p -> { p | current = p.current + 1 })

                            newModel =
                                { model
                                    | printQueue = restQueue
                                    , printProgress = currentProgress
                                    , selectedRowIndex = nextRowIndex
                                    , computedTexts = Dict.empty
                                }
                        in
                        ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

                    [] ->
                        -- All done
                        ( { model | printing = False, printingAll = False, printProgress = Nothing, printQueue = [] }
                        , Cmd.none
                        , Types.ShowNotification
                            ("Todas las etiquetas enviadas a imprimir ("
                                ++ (model.printProgress |> Maybe.map (\p -> String.fromInt p.total) |> Maybe.withDefault "")
                                ++ ")"
                            )
                            Success
                        )

            else
                ( { model | printing = False }
                , Cmd.none
                , Types.ShowNotification "Etiqueta enviada a imprimir" Success
                )

        Types.GotPrintResult (Err _) ->
            ( { model | printing = False, printingAll = False, printProgress = Nothing, printQueue = [] }
            , Cmd.none
            , Types.ShowNotification "Error al imprimir" Error
            )

        Types.EventEmitted _ ->
            ( model, Cmd.none, Types.NoOutMsg )


emitRowsSet : String -> List (Dict.Dict String String) -> Cmd Msg
emitRowsSet labelsetId rows =
    Api.emitEvent "labelset_rows_set"
        (Encode.object
            [ ( "labelset_id", Encode.string labelsetId )
            , ( "rows", Encode.list (Encode.dict identity Encode.string) rows )
            ]
        )
        Types.EventEmitted


view : Model -> Html Msg
view model =
    View.view model
