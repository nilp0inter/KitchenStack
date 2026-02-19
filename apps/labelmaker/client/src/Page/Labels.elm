module Page.Labels exposing (Model, Msg, OutMsg, init, update, view)

import Api
import Html exposing (Html)
import Page.Labels.Types as Types
import Page.Labels.View as View
import Types exposing (RemoteData(..))


type alias Model =
    Types.Model


type alias Msg =
    Types.Msg


type alias OutMsg =
    Types.OutMsg


init : ( Model, Cmd Msg )
init =
    ( Types.initialModel
    , Cmd.batch
        [ Api.fetchLabelList Types.GotLabels
        , Api.fetchTemplateList Types.GotTemplates
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        Types.GotLabels (Ok labels) ->
            ( { model | labels = Loaded labels }, Cmd.none, Types.NoOutMsg )

        Types.GotLabels (Err _) ->
            ( { model | labels = Failed "Error al cargar etiquetas" }, Cmd.none, Types.NoOutMsg )

        Types.GotTemplates (Ok templates) ->
            ( { model | templates = Loaded templates }, Cmd.none, Types.NoOutMsg )

        Types.GotTemplates (Err _) ->
            ( { model | templates = Failed "Error al cargar plantillas" }, Cmd.none, Types.NoOutMsg )

        Types.SelectTemplate templateId ->
            ( { model
                | selectedTemplateId =
                    if String.isEmpty templateId then
                        Nothing

                    else
                        Just templateId
              }
            , Cmd.none
            , Types.NoOutMsg
            )

        Types.UpdateNewName name ->
            ( { model | newName = name }, Cmd.none, Types.NoOutMsg )

        Types.CreateLabel ->
            case model.selectedTemplateId of
                Just templateId ->
                    let
                        name =
                            String.trim model.newName
                    in
                    if String.isEmpty name then
                        ( model, Cmd.none, Types.NoOutMsg )

                    else
                        ( model, Api.createLabel templateId name Types.GotCreateResult, Types.NoOutMsg )

                Nothing ->
                    ( model, Cmd.none, Types.NoOutMsg )

        Types.GotCreateResult (Ok labelId) ->
            ( model, Cmd.none, Types.NavigateTo ("/label/" ++ labelId) )

        Types.GotCreateResult (Err _) ->
            ( model, Cmd.none, Types.NoOutMsg )

        Types.DeleteLabel labelId ->
            ( model, Api.deleteLabel labelId (Types.GotDeleteResult labelId), Types.NoOutMsg )

        Types.GotDeleteResult labelId (Ok _) ->
            let
                removeFromList labels =
                    List.filter (\l -> l.id /= labelId) labels

                newLabels =
                    case model.labels of
                        Loaded labels ->
                            Loaded (removeFromList labels)

                        other ->
                            other
            in
            ( { model | labels = newLabels }, Cmd.none, Types.NoOutMsg )

        Types.GotDeleteResult _ (Err _) ->
            ( model, Cmd.none, Types.NoOutMsg )


view : Model -> Html Msg
view model =
    View.view model
