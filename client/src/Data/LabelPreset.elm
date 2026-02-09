module Data.LabelPreset exposing (empty)

import Types exposing (LabelPresetForm)


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
