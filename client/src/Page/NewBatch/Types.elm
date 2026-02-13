module Page.NewBatch.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Components.MarkdownEditor as MarkdownEditor
import Data.Label
import Dict exposing (Dict)
import Http
import Label
import Ports
import Types exposing (..)
import UUID exposing (UUID)


type alias Model =
    { form : BatchForm
    , ingredients : List Ingredient
    , containerTypes : List ContainerType
    , recipes : List Recipe
    , labelPresets : List LabelPreset
    , selectedPreset : Maybe LabelPreset
    , appHost : String
    , loading : Bool
    , printWithSave : Bool
    , printingProgress : Maybe PrintingProgress
    , showSuggestions : Bool
    , showRecipeSuggestions : Bool
    , expiryRequired : Bool
    , pendingPrintData : List PortionPrintData
    , pendingPngRequests : List String
    , pendingMeasurements : List String
    , computedLabelData : Dict String Data.Label.ComputedLabelData
    , detailsEditor : MarkdownEditor.Model
    , pendingExpiryDate : String
    , pendingBestBeforeDate : Maybe String
    }


type Msg
    = FormNameChanged String
    | FormIngredientInputChanged String
    | AddIngredient String
    | RemoveIngredient String
    | FormContainerChanged String
    | FormQuantityChanged String
    | FormCreatedAtChanged String
    | FormExpiryDateChanged String
    | SubmitBatchOnly
    | SubmitBatchWithPrint
    | GotUuidsForBatch (List UUID)
    | BatchCreated (Result Http.Error CreateBatchResponse)
    | PrintResult (Result Http.Error ())
    | HideSuggestions
    | HideRecipeSuggestions
    | IngredientKeyDown String
    | SelectRecipe Recipe
    | SelectPreset String
    | GotPngResult Ports.PngResult
    | GotTextMeasureResult Ports.TextMeasureResult
    | DetailsEditorMsg MarkdownEditor.Msg
    | ReceivedIngredients (List Ingredient)
    | ReceivedContainerTypes (List ContainerType)
    | ReceivedRecipes (List Recipe)
    | ReceivedLabelPresets (List LabelPreset)
    | SelectImage
    | GotImageResult Ports.FileSelectResult
    | RemoveImage


type OutMsg
    = NoOp
    | ShowNotification Notification
    | NavigateToHome
    | NavigateToBatch String
    | RefreshBatches
    | BatchCreatedLocally BatchSummary String
    | RequestSvgToPng Ports.SvgToPngRequest
    | RequestTextMeasure Ports.TextMeasureRequest
    | RequestFileSelect Ports.FileSelectRequest
