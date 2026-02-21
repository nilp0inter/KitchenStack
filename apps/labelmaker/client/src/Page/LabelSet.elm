module Page.LabelSet exposing (Model, Msg, OutMsg, init, update, view)

import Api
import Browser.Dom
import Csv.Decode as CsvDecode
import Csv.Encode as CsvEncode
import Data.LabelObject as LO
import Dict exposing (Dict)
import Html exposing (Html)
import Page.LabelSet.Types as Types
import Page.LabelSet.View as View
import Ports
import Task
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
                        , offsetX = detail.offsetX
                        , offsetY = detail.offsetY
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
                        , focusedCell = Nothing
                        , cellMode = Types.Navigating
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
                    { model | rows = Clean newRows, focusedCell = Nothing }
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
                        , focusedCell = Nothing
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
                    , Api.setLabelsetName model.labelsetId name Types.EventEmitted
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

        Types.AutoSave ->
            let
                ( m1, c1, _ ) =
                    update Types.CommitName model

                ( m2, c2, _ ) =
                    update Types.CommitRows m1
            in
            ( m2, Cmd.batch [ c1, c2 ], Types.NoOutMsg )

        Types.EventEmitted _ ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.CellClicked rowIndex colIndex ->
            if model.focusedCell == Just ( rowIndex, colIndex ) && model.cellMode == Types.Navigating then
                ( { model | cellMode = Types.Editing }
                , focusCell rowIndex colIndex
                , Types.NoOutMsg
                )

            else if model.focusedCell == Just ( rowIndex, colIndex ) then
                ( model, Cmd.none, Types.NoOutMsg )

            else
                let
                    ( m1, cmd1 ) =
                        commitIfDirty model

                    needsRemeasure =
                        rowIndex /= m1.selectedRowIndex

                    newModel =
                        { m1
                            | focusedCell = Just ( rowIndex, colIndex )
                            , cellMode = Types.Navigating
                            , selectedRowIndex = rowIndex
                            , computedTexts =
                                if needsRemeasure then
                                    Dict.empty

                                else
                                    m1.computedTexts
                        }

                    outMsg =
                        if needsRemeasure then
                            Types.requestAllMeasurements newModel

                        else
                            Types.NoOutMsg
                in
                ( newModel
                , Cmd.batch [ cmd1, focusCell rowIndex colIndex ]
                , outMsg
                )

        Types.CellKeyDown key ctrlKey shiftKey row col ->
            let
                rowCount =
                    List.length (getValue model.rows)

                colCount =
                    List.length model.variableNames
            in
            case model.cellMode of
                Types.Navigating ->
                    case key of
                        "ArrowUp" ->
                            if row > 0 then
                                moveToCell model (row - 1) col

                            else
                                ( model, Cmd.none, Types.NoOutMsg )

                        "ArrowDown" ->
                            if row < rowCount - 1 then
                                moveToCell model (row + 1) col

                            else
                                ( model, Cmd.none, Types.NoOutMsg )

                        "ArrowLeft" ->
                            if col > 0 then
                                moveToCell model row (col - 1)

                            else
                                ( model, Cmd.none, Types.NoOutMsg )

                        "ArrowRight" ->
                            if col < colCount - 1 then
                                moveToCell model row (col + 1)

                            else
                                ( model, Cmd.none, Types.NoOutMsg )

                        "Enter" ->
                            ( { model | cellMode = Types.Editing }
                            , focusCell row col
                            , Types.NoOutMsg
                            )

                        "Tab" ->
                            if shiftKey then
                                if col > 0 then
                                    moveToCell model row (col - 1)

                                else if row > 0 then
                                    moveToCell model (row - 1) (colCount - 1)

                                else
                                    ( model, Cmd.none, Types.NoOutMsg )

                            else if col < colCount - 1 then
                                moveToCell model row (col + 1)

                            else if row < rowCount - 1 then
                                moveToCell model (row + 1) 0

                            else
                                ( model, Cmd.none, Types.NoOutMsg )

                        _ ->
                            ( model, Cmd.none, Types.NoOutMsg )

                Types.Editing ->
                    case key of
                        "Tab" ->
                            let
                                ( m1, cmd1 ) =
                                    commitIfDirty model
                            in
                            if shiftKey then
                                if col > 0 then
                                    let
                                        newModel =
                                            { m1
                                                | focusedCell = Just ( row, col - 1 )
                                                , cellMode = Types.Editing
                                            }
                                    in
                                    ( newModel
                                    , Cmd.batch [ cmd1, focusCell row (col - 1) ]
                                    , Types.NoOutMsg
                                    )

                                else if row > 0 then
                                    let
                                        newModel =
                                            { m1
                                                | focusedCell = Just ( row - 1, colCount - 1 )
                                                , cellMode = Types.Editing
                                                , selectedRowIndex = row - 1
                                                , computedTexts = Dict.empty
                                            }
                                    in
                                    ( newModel
                                    , Cmd.batch [ cmd1, focusCell (row - 1) (colCount - 1) ]
                                    , Types.requestAllMeasurements newModel
                                    )

                                else
                                    ( m1, cmd1, Types.NoOutMsg )

                            else if col < colCount - 1 then
                                let
                                    newModel =
                                        { m1
                                            | focusedCell = Just ( row, col + 1 )
                                            , cellMode = Types.Editing
                                        }
                                in
                                ( newModel
                                , Cmd.batch [ cmd1, focusCell row (col + 1) ]
                                , Types.NoOutMsg
                                )

                            else if row < rowCount - 1 then
                                let
                                    newModel =
                                        { m1
                                            | focusedCell = Just ( row + 1, 0 )
                                            , cellMode = Types.Editing
                                            , selectedRowIndex = row + 1
                                            , computedTexts = Dict.empty
                                        }
                                in
                                ( newModel
                                , Cmd.batch [ cmd1, focusCell (row + 1) 0 ]
                                , Types.requestAllMeasurements newModel
                                )

                            else
                                ( m1, cmd1, Types.NoOutMsg )

                        "Enter" ->
                            if ctrlKey then
                                let
                                    currentRows =
                                        getValue model.rows

                                    emptyRow =
                                        List.foldl (\varName dict -> Dict.insert varName "" dict) Dict.empty model.variableNames

                                    newRows =
                                        List.take (row + 1) currentRows ++ [ emptyRow ] ++ List.drop (row + 1) currentRows

                                    newModel =
                                        { model
                                            | rows = Clean newRows
                                            , focusedCell = Just ( row + 1, 0 )
                                            , cellMode = Types.Editing
                                            , selectedRowIndex = row + 1
                                            , computedTexts = Dict.empty
                                        }
                                in
                                ( newModel
                                , Cmd.batch [ emitRowsSet model.labelsetId newRows, focusCell (row + 1) 0 ]
                                , Types.requestAllMeasurements newModel
                                )

                            else
                                ( model, Cmd.none, Types.NoOutMsg )

                        "Escape" ->
                            let
                                ( m1, cmd1 ) =
                                    commitIfDirty model

                                newModel =
                                    { m1 | cellMode = Types.Navigating }
                            in
                            ( newModel
                            , Cmd.batch [ cmd1, focusCell row col ]
                            , Types.NoOutMsg
                            )

                        _ ->
                            ( model, Cmd.none, Types.NoOutMsg )

        Types.CellBlurred blurredRow blurredCol ->
            let
                ( m1, cmd1 ) =
                    commitIfDirty model
            in
            if model.focusedCell == Just ( blurredRow, blurredCol ) then
                ( { m1 | cellMode = Types.Navigating }
                , cmd1
                , Types.NoOutMsg
                )

            else
                ( m1, cmd1, Types.NoOutMsg )

        Types.ToggleCsvMode ->
            if model.csvMode then
                -- Switching to table mode
                let
                    ( m1, cmd1 ) =
                        commitIfDirty model
                in
                ( { m1 | csvMode = False, csvError = Nothing }
                , cmd1
                , Types.NoOutMsg
                )

            else
                -- Switching to CSV mode
                let
                    csvText =
                        encodeCsv model.fieldSeparator model.variableNames (getValue model.rows)
                in
                ( { model
                    | csvMode = True
                    , csvText = csvText
                    , csvError = Nothing
                    , focusedCell = Nothing
                    , cellMode = Types.Navigating
                  }
                , Cmd.none
                , Types.NoOutMsg
                )

        Types.UpdateCsvText newText ->
            case decodeCsv model.fieldSeparator model.variableNames newText of
                Ok decodedRows ->
                    let
                        newSelectedIndex =
                            Basics.min model.selectedRowIndex
                                (Basics.max 0 (List.length decodedRows - 1))

                        newModel =
                            { model
                                | csvText = newText
                                , csvError = Nothing
                                , rows = Dirty decodedRows
                                , selectedRowIndex = newSelectedIndex
                                , computedTexts = Dict.empty
                            }
                    in
                    ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

                Err errorMsg ->
                    ( { model | csvText = newText, csvError = Just errorMsg }
                    , Cmd.none
                    , Types.NoOutMsg
                    )

        Types.UpdateFieldSeparator sepStr ->
            let
                newSep =
                    String.uncons sepStr
                        |> Maybe.map Tuple.first
                        |> Maybe.withDefault ','

                csvText =
                    encodeCsv newSep model.variableNames (getValue model.rows)
            in
            ( { model | fieldSeparator = newSep, csvText = csvText, csvError = Nothing }
            , Cmd.none
            , Types.NoOutMsg
            )

        Types.FocusResult _ ->
            ( model, Cmd.none, Types.NoOutMsg )


emitRowsSet : String -> List (Dict.Dict String String) -> Cmd Msg
emitRowsSet labelsetId rows =
    Api.setLabelsetRows labelsetId rows Types.EventEmitted


focusCell : Int -> Int -> Cmd Msg
focusCell row col =
    Browser.Dom.focus (Types.cellId row col)
        |> Task.attempt Types.FocusResult


commitIfDirty : Model -> ( Model, Cmd Msg )
commitIfDirty model =
    case model.rows of
        Dirty currentRows ->
            ( { model | rows = Clean currentRows }
            , emitRowsSet model.labelsetId currentRows
            )

        Clean _ ->
            ( model, Cmd.none )


moveToCell : Model -> Int -> Int -> ( Model, Cmd Msg, Types.OutMsg )
moveToCell model row col =
    let
        needsRemeasure =
            row /= model.selectedRowIndex

        newModel =
            { model
                | focusedCell = Just ( row, col )
                , selectedRowIndex = row
                , cellMode = Types.Navigating
                , computedTexts =
                    if needsRemeasure then
                        Dict.empty

                    else
                        model.computedTexts
            }

        outMsg =
            if needsRemeasure then
                Types.requestAllMeasurements newModel

            else
                Types.NoOutMsg
    in
    ( newModel, focusCell row col, outMsg )


encodeCsv : Char -> List String -> List (Dict String String) -> String
encodeCsv separator varNames rows =
    CsvEncode.encode
        { fieldSeparator = separator
        , encoder =
            CsvEncode.withFieldNames
                (\row ->
                    List.map
                        (\name -> ( name, Dict.get name row |> Maybe.withDefault "" ))
                        varNames
                )
        }
        rows


buildRowDecoder : List String -> CsvDecode.Decoder (Dict String String)
buildRowDecoder varNames =
    case varNames of
        [] ->
            CsvDecode.into (\_ -> Dict.empty)
                |> CsvDecode.pipeline (CsvDecode.field "" CsvDecode.string)

        first :: rest ->
            List.foldl
                (\varName prevDecoder ->
                    CsvDecode.into (\dict val -> Dict.insert varName val dict)
                        |> CsvDecode.pipeline prevDecoder
                        |> CsvDecode.pipeline (CsvDecode.field varName CsvDecode.string)
                )
                (CsvDecode.into (\val -> Dict.singleton first val)
                    |> CsvDecode.pipeline (CsvDecode.field first CsvDecode.string)
                )
                rest


decodeCsv : Char -> List String -> String -> Result String (List (Dict String String))
decodeCsv separator varNames csvText =
    CsvDecode.decodeCustom
        { fieldSeparator = separator }
        CsvDecode.FieldNamesFromFirstRow
        (buildRowDecoder varNames)
        csvText
        |> Result.mapError CsvDecode.errorToString


view : Model -> Html Msg
view model =
    View.view model
