module Page.ItemDetail exposing
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
import Page.ItemDetail.Types as IT exposing (..)
import Page.ItemDetail.View as View
import Types exposing (..)


type alias Model = IT.Model
type alias Msg = IT.Msg
type alias OutMsg = IT.OutMsg


init : String -> ( Model, Cmd Msg )
init portionId =
    ( { portionId = portionId
      , portionDetail = Nothing
      , loading = True
      , error = Nothing
      }
    , Api.fetchPortionDetail portionId GotPortionDetail
    )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        GotPortionDetail result ->
            case result of
                Ok detail ->
                    ( { model | portionDetail = Just detail, loading = False }
                    , Cmd.none
                    , NoOp
                    )

                Err _ ->
                    ( { model | error = Just "Failed to load portion details", loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Failed to load portion details", notificationType = Error }
                    )

        ConsumePortion portionId ->
            ( { model | loading = True }
            , Api.consumePortion portionId PortionConsumed
            , NoOp
            )

        PortionConsumed result ->
            case result of
                Ok _ ->
                    ( { model | loading = False }
                    , Api.fetchPortionDetail model.portionId GotPortionDetail
                    , RefreshBatches
                    )

                Err _ ->
                    ( { model | loading = False }
                    , Cmd.none
                    , ShowNotification { id = 0, message = "Failed to consume portion", notificationType = Error }
                    )


view : Model -> Html Msg
view =
    View.view
