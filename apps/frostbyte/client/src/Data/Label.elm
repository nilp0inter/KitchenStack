module Data.Label exposing
    ( ComputedLabelData
    , LabelData
    , LabelSettings
    , default
    , displayHeight
    , displayWidth
    , textMaxWidth
    )


type alias LabelData =
    { portionId : String
    , name : String
    , ingredients : String
    , expiryDate : String
    , bestBeforeDate : Maybe String
    , appHost : String
    }


type alias ComputedLabelData =
    { titleFontSize : Int
    , titleLines : List String
    , ingredientLines : List String
    }


type alias LabelSettings =
    { name : String
    , labelType : String
    , width : Int
    , height : Int
    , qrSize : Int
    , padding : Int
    , titleFontSize : Int
    , dateFontSize : Int
    , smallFontSize : Int
    , fontFamily : String
    , showTitle : Bool
    , showIngredients : Bool
    , showExpiryDate : Bool
    , showBestBefore : Bool
    , showQr : Bool
    , showBranding : Bool
    , verticalSpacing : Int
    , showSeparator : Bool
    , separatorThickness : Int
    , separatorColor : String
    , cornerRadius : Int
    , titleMinFontSize : Int
    , ingredientsMaxChars : Int
    , rotate : Bool
    }


default : LabelSettings
default =
    { name = "62mm (default)"
    , labelType = "62"
    , width = 696
    , height = 300
    , qrSize = 200
    , padding = 20
    , titleFontSize = 48
    , dateFontSize = 32
    , smallFontSize = 18
    , fontFamily = "Atkinson Hyperlegible, sans-serif"
    , showTitle = True
    , showIngredients = False
    , showExpiryDate = True
    , showBestBefore = False
    , showQr = True
    , showBranding = True
    , verticalSpacing = 10
    , showSeparator = True
    , separatorThickness = 1
    , separatorColor = "#cccccc"
    , cornerRadius = 0
    , titleMinFontSize = 24
    , ingredientsMaxChars = 45
    , rotate = False
    }


displayWidth : LabelSettings -> Int
displayWidth settings =
    if settings.rotate then
        settings.height

    else
        settings.width


displayHeight : LabelSettings -> Int
displayHeight settings =
    if settings.rotate then
        settings.width

    else
        settings.height


textMaxWidth : LabelSettings -> Int
textMaxWidth settings =
    let
        dispWidth =
            displayWidth settings

        qrPaddingCompensation =
            settings.qrSize // 10

        qrX =
            dispWidth - settings.qrSize - settings.padding + qrPaddingCompensation
    in
    if settings.showQr then
        qrX + qrPaddingCompensation - settings.padding - settings.padding

    else
        dispWidth - settings.padding - settings.padding
