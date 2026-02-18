module Page.History exposing
    ( Model
    , Msg
    , OutMsg
    , init
    , update
    , view
    )

import Api
import Chart.Item as CI
import Html exposing (Html)
import Http
import Page.History.Types as HT exposing (..)
import Page.History.View as View
import Types exposing (..)


type alias Model = HT.Model
type alias Msg = HT.Msg
type alias OutMsg = HT.OutMsg


init : ( Model, Cmd Msg )
init =
    ( { historyData = []
      , loading = True
      , error = Nothing
      , hovering = []
      }
    , Api.fetchHistory GotHistory
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotHistory result ->
            case result of
                Ok history ->
                    ( { model | historyData = history, loading = False }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( { model | error = Just "Failed to load history", loading = False }
                    , Cmd.none
                    , ShowError "Failed to load history"
                    )

        OnHover hovering ->
            ( { model | hovering = hovering }, Cmd.none, NoOp )


view : Model -> Html Msg
view =
    View.view
