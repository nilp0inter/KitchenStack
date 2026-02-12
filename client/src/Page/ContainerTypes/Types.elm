module Page.ContainerTypes.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Http
import Types exposing (..)


type alias Model =
    { containerTypes : List ContainerType
    , form : ContainerTypeForm
    , loading : Bool
    , deleteConfirm : Maybe String
    , viewMode : ViewMode
    }


type Msg
    = GotContainerTypes (Result Http.Error (List ContainerType))
    | FormNameChanged String
    | FormServingsChanged String
    | SaveContainerType
    | StartCreate
    | EditContainerType ContainerType
    | CancelEdit
    | DeleteContainerType String
    | ConfirmDelete String
    | CancelDelete
    | ContainerTypeSaved (Result Http.Error ())
    | ContainerTypeDeleted (Result Http.Error ())
    | ReceivedContainerTypes (List ContainerType)


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshContainerTypes
    | RefreshContainerTypesWithNotification Notification
