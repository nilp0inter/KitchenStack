module Page.Menu.Types exposing
    ( MenuItem
    , Model
    , Msg(..)
    , OutMsg(..)
    )

import Types exposing (..)


type alias MenuItem =
    { name : String
    , image : Maybe String
    , ingredients : String
    , frozenCount : Int
    , nearestExpiry : String
    }


type alias Model =
    { menuItems : List MenuItem
    }


type Msg
    = ReceivedBatches (List BatchSummary)


type OutMsg
    = NoOp
