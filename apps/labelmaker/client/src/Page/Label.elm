module Page.Label exposing (Model, Msg, OutMsg, init, update, view)

import Api
import Data.LabelObject as LO
import Dict
import Html exposing (Html)
import Page.Label.Types as Types
import Page.Label.View as View
import Ports
import Types exposing (Committable(..), NotificationType(..), getValue)


type alias Model =
    Types.Model


type alias Msg =
    Types.Msg


type alias OutMsg =
    Types.OutMsg


init : String -> ( Model, Cmd Msg, OutMsg )
init labelId =
    ( Types.initialModel labelId
    , Api.fetchLabelDetail labelId Types.GotLabelDetail
    , Types.NoOutMsg
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        Types.GotLabelDetail (Ok (Just detail)) ->
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
                        , labelName = Clean detail.name
                        , values = Dict.map (\_ v -> Clean v) detail.values
                        , variableNames = LO.allVariableNames detail.content
                        , computedTexts = Dict.empty
                    }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

        Types.GotLabelDetail (Ok Nothing) ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.GotLabelDetail (Err _) ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.UpdateName name ->
            ( { model | labelName = Dirty name }, Cmd.none, Types.NoOutMsg )

        Types.CommitName ->
            case model.labelName of
                Dirty name ->
                    ( { model | labelName = Clean name }
                    , Api.setLabelName model.labelId name Types.EventEmitted
                    , Types.NoOutMsg
                    )

                Clean _ ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.UpdateValue varName val ->
            let
                newModel =
                    { model
                        | values = Dict.insert varName (Dirty val) model.values
                        , computedTexts = Dict.empty
                    }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

        Types.CommitValues ->
            let
                hasDirty =
                    Dict.values model.values
                        |> List.any
                            (\v ->
                                case v of
                                    Dirty _ ->
                                        True

                                    Clean _ ->
                                        False
                            )
            in
            if hasDirty then
                let
                    cleanValues =
                        Dict.map (\_ v -> Clean (getValue v)) model.values

                    plainValues =
                        Dict.map (\_ v -> getValue v) model.values
                in
                ( { model | values = cleanValues }
                , Api.setLabelValues model.labelId plainValues Types.EventEmitted
                , Types.NoOutMsg
                )

            else
                ( model, Cmd.none, Types.NoOutMsg )

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

        Types.GotPngResult result ->
            case result.dataUrl of
                Just dataUrl ->
                    let
                        base64 =
                            -- Strip "data:image/png;base64," prefix
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
                    ( { model | printing = False }
                    , Cmd.none
                    , Types.ShowNotification
                        (Maybe.withDefault "Error al generar imagen" result.error)
                        Error
                    )

        Types.GotPrintResult (Ok _) ->
            ( { model | printing = False }
            , Cmd.none
            , Types.ShowNotification "Etiqueta enviada a imprimir" Success
            )

        Types.GotPrintResult (Err _) ->
            ( { model | printing = False }
            , Cmd.none
            , Types.ShowNotification "Error al imprimir" Error
            )

        Types.AutoSave ->
            let
                ( m1, c1, _ ) =
                    update Types.CommitName model

                ( m2, c2, _ ) =
                    update Types.CommitValues m1
            in
            ( m2, Cmd.batch [ c1, c2 ], Types.NoOutMsg )

        Types.EventEmitted _ ->
            ( model, Cmd.none, Types.NoOutMsg )


view : Model -> Html Msg
view model =
    View.view model
