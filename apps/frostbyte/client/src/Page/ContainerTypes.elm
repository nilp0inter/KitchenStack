module Page.ContainerTypes exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

import Api
import Data.ContainerType
import Html exposing (Html)
import Http
import Page.ContainerTypes.Types as CT exposing (..)
import Page.ContainerTypes.View as View
import Types exposing (..)


type alias Model = CT.Model
type alias Msg = CT.Msg
type alias OutMsg = CT.OutMsg


init : List ContainerType -> ( Model, Cmd Msg )
init containerTypes =
    ( { containerTypes = containerTypes
      , form = Data.ContainerType.empty
      , loading = False
      , deleteConfirm = Nothing
      , viewMode = ListMode
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotContainerTypes result ->
            case result of
                Ok containerTypes ->
                    ( { model | containerTypes = containerTypes, loading = False }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al cargar envases", notificationType = Error }
                    )

        FormNameChanged name ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | name = name } }, Cmd.none, NoOp )

        FormServingsChanged servings ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | servingsPerUnit = servings } }, Cmd.none, NoOp )

        SaveContainerType ->
            ( { model | loading = True }
            , Api.saveContainerType model.form ContainerTypeSaved
            , NoOp
            )

        StartCreate ->
            ( { model | form = Data.ContainerType.empty, viewMode = FormMode }
            , Cmd.none
            , NoOp
            )

        EditContainerType containerType ->
            ( { model
                | form =
                    { name = containerType.name
                    , servingsPerUnit = String.fromFloat containerType.servingsPerUnit
                    , editing = Just containerType.name
                    }
                , viewMode = FormMode
              }
            , Cmd.none
            , NoOp
            )

        CancelEdit ->
            ( { model | form = Data.ContainerType.empty, viewMode = ListMode }, Cmd.none, NoOp )

        DeleteContainerType name ->
            ( { model | deleteConfirm = Just name }, Cmd.none, NoOp )

        ConfirmDelete name ->
            ( { model | deleteConfirm = Nothing, loading = True }
            , Api.deleteContainerType name ContainerTypeDeleted
            , NoOp
            )

        CancelDelete ->
            ( { model | deleteConfirm = Nothing }, Cmd.none, NoOp )

        ContainerTypeSaved result ->
            case result of
                Ok _ ->
                    ( { model | loading = False, form = Data.ContainerType.empty, viewMode = ListMode }
                    , Api.fetchContainerTypes GotContainerTypes
                    , RefreshContainerTypesWithNotification { id = 0, message = "Envase guardado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al guardar envase", notificationType = Error }
                    )

        ContainerTypeDeleted result ->
            case result of
                Ok _ ->
                    ( { model | loading = False }
                    , Api.fetchContainerTypes GotContainerTypes
                    , RefreshContainerTypesWithNotification { id = 0, message = "Envase eliminado", notificationType = Success }
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Error al eliminar envase (puede estar en uso)", notificationType = Error }
                    )

        ReceivedContainerTypes containerTypes ->
            ( { model | containerTypes = containerTypes }, Cmd.none, NoOp )


view : Model -> Html Msg
view =
    View.view
