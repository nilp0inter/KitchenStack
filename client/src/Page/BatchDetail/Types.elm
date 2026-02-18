module Page.BatchDetail.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    )

import Data.Label
import Dict exposing (Dict)
import Http
import Ports
import Types exposing (..)


type alias Model =
    { batchId : String
    , batch : Maybe BatchSummary
    , portions : List PortionInBatch
    , labelPresets : List LabelPreset
    , selectedPreset : Maybe LabelPreset
    , appHost : String
    , loading : Bool
    , error : Maybe String
    , previewModal : Maybe PortionPrintData
    , pendingPreview : Maybe PortionPrintData
    , printingProgress : Maybe PrintingProgress
    , pendingPrintData : List PortionPrintData
    , pendingPngRequests : List String
    , pendingMeasurements : List String
    , computedLabelData : Dict String Data.Label.ComputedLabelData
    }


type Msg
    = GotBatches (Result Http.Error (List BatchSummary))
    | GotBatchPortions (Result Http.Error (List PortionInBatch))
    | ReprintPortion PortionInBatch
    | ReprintAllFrozen
    | PrintResult (Result Http.Error ())
    | OpenPreviewModal PortionPrintData
    | ClosePreviewModal
    | ReturnToFreezer String
    | ReturnToFreezerResult (Result Http.Error ())
    | DiscardPortion String
    | DiscardPortionResult (Result Http.Error ())
    | SelectPreset String
    | GotPngResult Ports.PngResult
    | GotTextMeasureResult Ports.TextMeasureResult
    | ReceivedBatches (List BatchSummary)
    | ReceivedLabelPresets (List LabelPreset)


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RequestSvgToPng Ports.SvgToPngRequest
    | RequestTextMeasure Ports.TextMeasureRequest
