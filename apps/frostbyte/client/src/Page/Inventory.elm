module Page.Inventory exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

import Api
import Html exposing (Html)
import Http
import Page.Inventory.Types as IT exposing (..)
import Page.Inventory.View as View
import Types exposing (..)


type alias Model = IT.Model
type alias Msg = IT.Msg
type alias OutMsg = IT.OutMsg


init : List BatchSummary -> List ContainerType -> ( Model, Cmd Msg )
init batches containerTypes =
    ( { batches = batches
      , containerTypes = containerTypes
      , loading = False
      , error = Nothing
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotBatches result ->
            case result of
                Ok batches ->
                    ( { model | batches = batches, loading = False }, Cmd.none, NoOp )

                Err _ ->
                    ( { model | error = Just "Failed to load batches", loading = False }
                    , Cmd.none
                    , ShowError "Failed to load batches"
                    )

        SelectBatch batchId ->
            ( model, Cmd.none, NavigateToBatch batchId )

        ReceivedBatches batches ->
            ( { model | batches = batches }, Cmd.none, NoOp )

        ReceivedContainerTypes containerTypes ->
            ( { model | containerTypes = containerTypes }, Cmd.none, NoOp )


view : Model -> Html Msg
view =
    View.view
