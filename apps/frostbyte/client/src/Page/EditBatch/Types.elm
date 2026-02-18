module Page.EditBatch.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Components.MarkdownEditor as MarkdownEditor
import Data.Label
import Dict exposing (Dict)
import Http
import Ports
import Types exposing (..)
import UUID exposing (UUID)


type alias Model =
    { batchId : String
    , batch : Maybe BatchSummary
    , portions : List PortionInBatch
    , ingredients : List Ingredient
    , containerTypes : List ContainerType
    , labelPresets : List LabelPreset
    , selectedPreset : Maybe LabelPreset
    , appHost : String
    , currentDate : String
    , loading : Bool
    , saving : Bool
    , form : EditBatchForm
    , discardPortionIds : List String
    , newPortionQuantity : String
    , newPortionsExpiryDate : String
    , expiryRequired : Bool
    , showSuggestions : Bool
    , imageChanged : Bool
    , detailsEditor : MarkdownEditor.Model
    , printingProgress : Maybe PrintingProgress
    , pendingPrintData : List PortionPrintData
    , pendingPngRequests : List String
    , pendingMeasurements : List String
    , computedLabelData : Dict String Data.Label.ComputedLabelData
    }


type alias EditBatchForm =
    { name : String
    , selectedIngredients : List SelectedIngredient
    , ingredientInput : String
    , containerId : String
    , bestBeforeDate : String
    , details : String
    , image : Maybe String
    }


type Msg
    = GotBatch (Result Http.Error (List BatchSummary))
    | GotBatchPortions (Result Http.Error (List PortionInBatch))
    | GotBatchIngredients (Result Http.Error (List BatchIngredient))
    | FormNameChanged String
    | FormIngredientInputChanged String
    | AddIngredient String
    | RemoveIngredient String
    | FormContainerChanged String
    | FormBestBeforeDateChanged String
    | NewPortionQuantityChanged String
    | NewPortionsExpiryDateChanged String
    | ToggleDiscardPortion String
    | SelectPreset String
    | SubmitUpdate
    | SubmitUpdateAndPrint
    | GotUuidsForUpdate (List UUID)
    | BatchUpdated (Result Http.Error UpdateBatchResponse)
    | PrintResult String (Result Http.Error ())
    | RecordPrintedResult (Result Http.Error ())
    | HideSuggestions
    | IngredientKeyDown String
    | DetailsEditorMsg MarkdownEditor.Msg
    | SelectImage
    | GotImageResult Ports.FileSelectResult
    | RemoveImage
    | GotPngResult Ports.PngResult
    | GotTextMeasureResult Ports.TextMeasureResult
    | ReceivedIngredients (List Ingredient)
    | ReceivedContainerTypes (List ContainerType)
    | ReceivedLabelPresets (List LabelPreset)


type OutMsg
    = NoOp
    | ShowNotification Notification
    | NavigateToBatch String
    | RefreshBatchesWithNotification Notification
    | RequestSvgToPng Ports.SvgToPngRequest
    | RequestTextMeasure Ports.TextMeasureRequest
    | RequestFileSelect Ports.FileSelectRequest
