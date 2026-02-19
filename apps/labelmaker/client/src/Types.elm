module Types exposing
    ( Committable(..)
    , Flags
    , Notification
    , NotificationType(..)
    , RemoteData(..)
    , getValue
    )


type alias Flags =
    { currentDate : String
    }


{-| Represents the state of data that is loaded asynchronously.
-}
type RemoteData a
    = NotAsked
    | Loading
    | Loaded a
    | Failed String


type NotificationType
    = Success
    | Info
    | Error


type alias Notification =
    { id : Int
    , message : String
    , notificationType : NotificationType
    }


type Committable a
    = Dirty a
    | Clean a


getValue : Committable a -> a
getValue c =
    case c of
        Dirty a ->
            a

        Clean a ->
            a
