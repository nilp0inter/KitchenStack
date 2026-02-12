module Page.Dashboard.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Http
import Types exposing (..)


type alias Model =
    { batches : List BatchSummary
    , containerTypes : List ContainerType
    , loading : Bool
    , error : Maybe String
    }


type Msg
    = GotBatches (Result Http.Error (List BatchSummary))
    | SelectBatch String
    | ReceivedBatches (List BatchSummary)
    | ReceivedContainerTypes (List ContainerType)


type OutMsg
    = NoOp
    | NavigateToBatch String
    | ShowError String
