module Page.LabelDesigner.Types exposing
    ( Model
    , Msg(..)
    , OutMsg(..)
    , formToSettings
    , requestMeasurement
    )

import Data.Label as Label
import Http
import Ports
import Types exposing (..)


type alias Model =
    { presets : List LabelPreset
    , form : LabelPresetForm
    , appHost : String
    , loading : Bool
    , deleteConfirm : Maybe String
    , sampleName : String
    , sampleIngredients : String
    , computedLabelData : Maybe Label.ComputedLabelData
    , isPrinting : Bool
    , previewZoom : Float
    , previewPanX : Float
    , previewPanY : Float
    , previewContainerHeight : Int
    }


type Msg
    = GotPresets (Result Http.Error (List LabelPreset))
    | FormNameChanged String
    | FormLabelTypeChanged String
    | FormWidthChanged String
    | FormHeightChanged String
    | FormQrSizeChanged String
    | FormPaddingChanged String
    | FormTitleFontSizeChanged String
    | FormDateFontSizeChanged String
    | FormSmallFontSizeChanged String
    | FormFontFamilyChanged String
    | FormShowTitleChanged Bool
    | FormShowIngredientsChanged Bool
    | FormShowExpiryDateChanged Bool
    | FormShowBestBeforeChanged Bool
    | FormShowQrChanged Bool
    | FormShowBrandingChanged Bool
    | FormVerticalSpacingChanged String
    | FormShowSeparatorChanged Bool
    | FormSeparatorThicknessChanged String
    | FormSeparatorColorChanged String
    | FormCornerRadiusChanged String
    | FormTitleMinFontSizeChanged String
    | FormIngredientsMaxCharsChanged String
    | FormRotateChanged Bool
    | SampleNameChanged String
    | SampleIngredientsChanged String
    | SavePreset
    | EditPreset LabelPreset
    | CancelEdit
    | DeletePreset String
    | ConfirmDelete String
    | CancelDelete
    | PresetSaved (Result Http.Error ())
    | PresetDeleted (Result Http.Error ())
    | GotTextMeasureResult Ports.TextMeasureResult
    | PrintLabel
    | GotPngResult Ports.PngResult
    | PrintResult (Result Http.Error ())
    | ZoomChanged Float
    | ZoomIn
    | ZoomOut
    | PinchZoomUpdated { zoom : Float, panX : Float, panY : Float }
    | PreviewContainerHeightChanged String
    | ResetZoomPan
    | ReceivedLabelPresets (List LabelPreset)


type OutMsg
    = NoOp
    | ShowNotification Notification
    | RefreshPresets
    | RefreshPresetsWithNotification Notification
    | RequestTextMeasure Ports.TextMeasureRequest
    | RequestSvgToPng Ports.SvgToPngRequest
    | RequestInitPinchZoom { elementId : String, initialZoom : Float }
    | RequestSetPinchZoom { elementId : String, zoom : Float, panX : Float, panY : Float }


{-| Build a text measure request from current model state.
-}
requestMeasurement : Model -> OutMsg
requestMeasurement model =
    let
        settings =
            formToSettings model.form
    in
    RequestTextMeasure
        { requestId = "preview"
        , titleText = model.sampleName
        , ingredientsText = model.sampleIngredients
        , fontFamily = settings.fontFamily
        , titleFontSize = settings.titleFontSize
        , titleMinFontSize = settings.titleMinFontSize
        , smallFontSize = settings.smallFontSize
        , maxWidth = Label.textMaxWidth settings
        , ingredientsMaxChars = settings.ingredientsMaxChars
        }


{-| Convert form values to LabelSettings for preview.
-}
formToSettings : LabelPresetForm -> Label.LabelSettings
formToSettings form =
    { name = form.name
    , labelType = form.labelType
    , width = Maybe.withDefault 696 (String.toInt form.width)
    , height = Maybe.withDefault 300 (String.toInt form.height)
    , qrSize = Maybe.withDefault 200 (String.toInt form.qrSize)
    , padding = Maybe.withDefault 20 (String.toInt form.padding)
    , titleFontSize = Maybe.withDefault 48 (String.toInt form.titleFontSize)
    , dateFontSize = Maybe.withDefault 32 (String.toInt form.dateFontSize)
    , smallFontSize = Maybe.withDefault 18 (String.toInt form.smallFontSize)
    , fontFamily = form.fontFamily
    , showTitle = form.showTitle
    , showIngredients = form.showIngredients
    , showExpiryDate = form.showExpiryDate
    , showBestBefore = form.showBestBefore
    , showQr = form.showQr
    , showBranding = form.showBranding
    , verticalSpacing = Maybe.withDefault 10 (String.toInt form.verticalSpacing)
    , showSeparator = form.showSeparator
    , separatorThickness = Maybe.withDefault 1 (String.toInt form.separatorThickness)
    , separatorColor = form.separatorColor
    , cornerRadius = Maybe.withDefault 0 (String.toInt form.cornerRadius)
    , titleMinFontSize = Maybe.withDefault 24 (String.toInt form.titleMinFontSize)
    , ingredientsMaxChars = Maybe.withDefault 45 (String.toInt form.ingredientsMaxChars)
    , rotate = form.rotate
    }
