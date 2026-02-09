module Data.LabelPreset exposing (empty, presetToSettings)

import Data.Label
import Types exposing (LabelPreset, LabelPresetForm)


empty : LabelPresetForm
empty =
    { name = ""
    , labelType = "29"
    , width = "306"
    , height = "200"
    , qrSize = "215"
    , padding = "10"
    , titleFontSize = "30"
    , dateFontSize = "18"
    , smallFontSize = "12"
    , fontFamily = "Atkinson Hyperlegible, sans-serif"
    , showTitle = True
    , showIngredients = True
    , showExpiryDate = True
    , showBestBefore = False
    , showQr = True
    , showBranding = True
    , verticalSpacing = "8"
    , showSeparator = True
    , separatorThickness = "1"
    , separatorColor = "#cccccc"
    , cornerRadius = "0"
    , titleMinFontSize = "26"
    , ingredientsMaxChars = "80"
    , rotate = False
    , editing = Nothing
    }


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
