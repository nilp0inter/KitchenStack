module Page.History.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Chart.Item as CI
import Http
import Types exposing (..)


type alias Model =
    { historyData : List HistoryPoint
    , loading : Bool
    , error : Maybe String
    , hovering : List (CI.One HistoryPoint CI.Any)
    }


type Msg
    = GotHistory (Result Http.Error (List HistoryPoint))
    | OnHover (List (CI.One HistoryPoint CI.Any))


type OutMsg
    = NoOp
    | ShowError String
