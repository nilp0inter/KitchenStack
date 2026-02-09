module Page.ItemDetail.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Http
import Types exposing (..)


type alias Model =
    { portionId : String
    , portionDetail : Maybe PortionDetail
    , loading : Bool
    , error : Maybe String
    }


type Msg
    = GotPortionDetail (Result Http.Error PortionDetail)
    | ConsumePortion String
    | PortionConsumed (Result Http.Error ())


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshBatches
