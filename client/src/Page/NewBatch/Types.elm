module Page.NewBatch.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    , presetToSettings
    )

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
    | FormDetailsChanged String
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


type OutMsg
    = NoOp
    | ShowNotification Notification
    | NavigateToHome
    | NavigateToBatch String
    | RefreshBatches
    | RequestSvgToPng Ports.SvgToPngRequest
    | RequestTextMeasure Ports.TextMeasureRequest


{-| Convert a LabelPreset to LabelSettings for Label module functions.
-}
presetToSettings : LabelPreset -> Data.Label.LabelSettings
presetToSettings preset =
    { name = preset.name
    , labelType = preset.labelType
    , width = preset.width
    , height = preset.height
    , qrSize = preset.qrSize
    , padding = preset.padding
    , titleFontSize = preset.titleFontSize
    , dateFontSize = preset.dateFontSize
    , smallFontSize = preset.smallFontSize
    , fontFamily = preset.fontFamily
    , showTitle = preset.showTitle
    , showIngredients = preset.showIngredients
    , showExpiryDate = preset.showExpiryDate
    , showBestBefore = preset.showBestBefore
    , showQr = preset.showQr
    , showBranding = preset.showBranding
    , verticalSpacing = preset.verticalSpacing
    , showSeparator = preset.showSeparator
    , separatorThickness = preset.separatorThickness
    , separatorColor = preset.separatorColor
    , cornerRadius = preset.cornerRadius
    , titleMinFontSize = preset.titleMinFontSize
    , ingredientsMaxChars = preset.ingredientsMaxChars
    , rotate = preset.rotate
    }
