module Page.Label exposing (Model, Msg, OutMsg, init, update, view)

import Api
import Data.LabelObject as LO
import Dict
import Html exposing (Html)
import Json.Encode as Encode
import Page.Label.Types as Types
import Page.Label.View as View
import Ports
import Types exposing (NotificationType(..))


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
                        , content = detail.content
                        , values = detail.values
                        , variableNames = LO.allVariableNames detail.content
                        , computedTexts = Dict.empty
                    }
            in
            ( newModel, Cmd.none, Types.requestAllMeasurements newModel )

        Types.GotLabelDetail (Ok Nothing) ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.GotLabelDetail (Err _) ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.UpdateValue varName val ->
            let
                newModel =
                    { model
                        | values = Dict.insert varName val model.values
                        , computedTexts = Dict.empty
                    }
            in
            ( newModel
            , Api.emitEvent "label_values_set"
                (Encode.object
                    [ ( "label_id", Encode.string model.labelId )
                    , ( "values", Encode.dict identity Encode.string newModel.values )
                    ]
                )
                Types.EventEmitted
            , Types.requestAllMeasurements newModel
            )

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

        Types.EventEmitted _ ->
            ( model, Cmd.none, Types.NoOutMsg )


view : Model -> Html Msg
view model =
    View.view model
