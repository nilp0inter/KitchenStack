module Page.Labels.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    , initialModel
    )

import Api.Decoders exposing (LabelSummary, TemplateSummary)
import Http
import Types exposing (RemoteData(..))


type alias Model =
    { labels : RemoteData (List LabelSummary)
    , templates : RemoteData (List TemplateSummary)
    , selectedTemplateId : Maybe String
    , newName : String
    }


type Msg
    = GotLabels (Result Http.Error (List LabelSummary))
    | GotTemplates (Result Http.Error (List TemplateSummary))
    | SelectTemplate String
    | UpdateNewName String
    | CreateLabel
    | GotCreateResult (Result Http.Error String)
    | DeleteLabel String
    | GotDeleteResult String (Result Http.Error ())


type OutMsg
    = NoOutMsg
    | NavigateTo String


initialModel : Model
initialModel =
    { labels = Loading
    , templates = Loading
    , selectedTemplateId = Nothing
    , newName = ""
    }
