module Label exposing
    ( ComputedLabelData
    , LabelData
    , LabelSettings
    , defaultSettings
    , displayHeight
    , displayWidth
    , labelSvgId
    , textMaxWidth
    , viewLabelWithComputed
    )

{-| SVG label rendering for FrostByte freezer labels.

This module generates SVG labels that can be converted to PNG for printing.
Layout matches the original Python printer service output.

-}

import Html exposing (Html)
import QRCode
import Svg exposing (Svg)
import Svg.Attributes as SvgA


{-| Data needed to render a label.
-}
type alias LabelData =
    { portionId : String
    , name : String
    , ingredients : String
    , expiryDate : String
    , bestBeforeDate : Maybe String
    , appHost : String
    }


{-| Computed values from JS text measurement for rendering.
-}
type alias ComputedLabelData =
    { titleFontSize : Int
    , titleLines : List String
    , ingredientLines : List String
    }


{-| Settings that control label dimensions and styling.
-}
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


{-| Default settings for 62mm Brother QL tape.
-}
defaultSettings : LabelSettings
defaultSettings =
    { name = "62mm (default)"
    , labelType = "62"
    , width = 696
    , height = 300
    , qrSize = 200
    , padding = 20
    , titleFontSize = 48
    , dateFontSize = 32
    , smallFontSize = 18
    , fontFamily = "sans-serif"
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


{-| Generate a unique SVG element ID for a portion.
-}
labelSvgId : String -> String
labelSvgId portionId =
    "label-svg-" ++ portionId


{-| Get display width. When rotate=True, swaps width/height for landscape display.
-}
displayWidth : LabelSettings -> Int
displayWidth settings =
    if settings.rotate then
        settings.height

    else
        settings.width


{-| Get display height. When rotate=True, swaps width/height for landscape display.
-}
displayHeight : LabelSettings -> Int
displayHeight settings =
    if settings.rotate then
        settings.width

    else
        settings.height


{-| Calculate the maximum width available for text content.
Used by other modules to request text measurement with correct width.
Uses display dimensions (landscape orientation).
-}
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


{-| Render a label as SVG with computed text measurements.
Uses JS-measured title font size and pre-wrapped ingredient lines.
Renders in landscape orientation (display dimensions).
-}
viewLabelWithComputed : LabelSettings -> LabelData -> ComputedLabelData -> Html msg
viewLabelWithComputed settings data computed =
    let
        -- Display dimensions (swapped for landscape)
        dispWidth =
            displayWidth settings

        dispHeight =
            displayHeight settings

        qrUrl =
            "https://" ++ data.appHost ++ "/item/" ++ data.portionId

        qrPaddingCompensation =
            settings.qrSize // 10

        qrX =
            dispWidth - settings.qrSize - settings.padding + qrPaddingCompensation

        qrY =
            (dispHeight - settings.qrSize) // 2

        textMaxX_ =
            if settings.showQr then
                qrX + qrPaddingCompensation - settings.padding

            else
                dispWidth - settings.padding

        formattedExpiryDate =
            formatDate data.expiryDate

        formattedBestBeforeDate =
            Maybe.map formatDate data.bestBeforeDate

        -- Calculate Y positions dynamically based on visible elements
        startY =
            settings.padding

        -- Title position (use computed font size for Y calculation)
        titleY =
            startY + computed.titleFontSize

        -- Title line height for multi-line titles
        titleLineHeight =
            computed.titleFontSize + 4

        titleLinesCount =
            List.length computed.titleLines

        -- Y position after all title lines
        titleEndY =
            titleY + (titleLinesCount - 1) * titleLineHeight

        separatorY =
            titleEndY + settings.verticalSpacing

        afterTitleY =
            if settings.showTitle then
                if settings.showSeparator then
                    separatorY + settings.verticalSpacing

                else
                    titleEndY + settings.verticalSpacing

            else
                startY

        -- Ingredients section with multi-line support
        ingredientsLabelY =
            afterTitleY + settings.smallFontSize

        ingredientsTextY =
            ingredientsLabelY + settings.smallFontSize + 5

        ingredientLineHeight =
            settings.smallFontSize + 4

        ingredientLinesCount =
            List.length computed.ingredientLines

        afterIngredientsY =
            if settings.showIngredients then
                ingredientsTextY + (ingredientLinesCount - 1) * ingredientLineHeight + settings.verticalSpacing

            else
                afterTitleY

        -- Expiry date section
        expiryLabelY =
            afterIngredientsY + settings.smallFontSize

        expiryDateY =
            expiryLabelY + settings.dateFontSize + 5

        afterExpiryY =
            if settings.showExpiryDate then
                expiryDateY + settings.verticalSpacing

            else
                afterIngredientsY

        -- Best before date section
        bestBeforeLabelY =
            afterExpiryY + settings.smallFontSize

        bestBeforeDateY =
            bestBeforeLabelY + settings.dateFontSize + 5

        -- Branding position (bottom left)
        brandingY =
            dispHeight - settings.padding

        clipId =
            "clip-" ++ data.portionId

        clipPathDef =
            if settings.cornerRadius > 0 then
                [ Svg.defs []
                    [ Svg.clipPath [ SvgA.id clipId ]
                        [ Svg.rect
                            [ SvgA.x "0"
                            , SvgA.y "0"
                            , SvgA.width (String.fromInt dispWidth)
                            , SvgA.height (String.fromInt dispHeight)
                            , SvgA.rx (String.fromInt settings.cornerRadius)
                            , SvgA.ry (String.fromInt settings.cornerRadius)
                            ]
                            []
                        ]
                    ]
                ]

            else
                []

        backgroundRect =
            Svg.rect
                [ SvgA.x "0"
                , SvgA.y "0"
                , SvgA.width (String.fromInt dispWidth)
                , SvgA.height (String.fromInt dispHeight)
                , SvgA.fill "white"
                , SvgA.rx (String.fromInt settings.cornerRadius)
                , SvgA.ry (String.fromInt settings.cornerRadius)
                ]
                []

        -- Title with computed font size and multi-line support
        titleElement =
            if settings.showTitle then
                [ Svg.text_
                    [ SvgA.x (String.fromInt settings.padding)
                    , SvgA.y (String.fromInt titleY)
                    , SvgA.fontFamily settings.fontFamily
                    , SvgA.fontSize (String.fromInt computed.titleFontSize ++ "px")
                    , SvgA.fontWeight "bold"
                    , SvgA.fill "black"
                    ]
                    (List.indexedMap
                        (\idx line ->
                            Svg.tspan
                                [ SvgA.x (String.fromInt settings.padding)
                                , SvgA.dy
                                    (if idx == 0 then
                                        "0"

                                     else
                                        String.fromInt titleLineHeight
                                    )
                                ]
                                [ Svg.text line ]
                        )
                        computed.titleLines
                    )
                ]

            else
                []

        separatorElement =
            if settings.showTitle && settings.showSeparator then
                [ Svg.line
                    [ SvgA.x1 (String.fromInt settings.padding)
                    , SvgA.y1 (String.fromInt separatorY)
                    , SvgA.x2 (String.fromInt textMaxX_)
                    , SvgA.y2 (String.fromInt separatorY)
                    , SvgA.stroke settings.separatorColor
                    , SvgA.strokeWidth (String.fromInt settings.separatorThickness)
                    ]
                    []
                ]

            else
                []

        -- Ingredients with multi-line tspans
        ingredientsElement =
            if settings.showIngredients then
                [ Svg.text_
                    [ SvgA.x (String.fromInt settings.padding)
                    , SvgA.y (String.fromInt ingredientsLabelY)
                    , SvgA.fontFamily settings.fontFamily
                    , SvgA.fontSize (String.fromInt settings.smallFontSize ++ "px")
                    , SvgA.fill "black"
                    ]
                    [ Svg.text "Ingredientes:" ]
                , Svg.text_
                    [ SvgA.x (String.fromInt settings.padding)
                    , SvgA.y (String.fromInt ingredientsTextY)
                    , SvgA.fontFamily settings.fontFamily
                    , SvgA.fontSize (String.fromInt settings.smallFontSize ++ "px")
                    , SvgA.fill "#666666"
                    ]
                    (List.indexedMap
                        (\idx line ->
                            Svg.tspan
                                [ SvgA.x (String.fromInt settings.padding)
                                , SvgA.dy
                                    (if idx == 0 then
                                        "0"

                                     else
                                        String.fromInt ingredientLineHeight
                                    )
                                ]
                                [ Svg.text line ]
                        )
                        computed.ingredientLines
                    )
                ]

            else
                []

        expiryElements =
            if settings.showExpiryDate then
                [ Svg.text_
                    [ SvgA.x (String.fromInt settings.padding)
                    , SvgA.y (String.fromInt expiryLabelY)
                    , SvgA.fontFamily settings.fontFamily
                    , SvgA.fontSize (String.fromInt settings.smallFontSize ++ "px")
                    , SvgA.fill "black"
                    ]
                    [ Svg.text "Caduca:" ]
                , Svg.text_
                    [ SvgA.x (String.fromInt settings.padding)
                    , SvgA.y (String.fromInt expiryDateY)
                    , SvgA.fontFamily settings.fontFamily
                    , SvgA.fontSize (String.fromInt settings.dateFontSize ++ "px")
                    , SvgA.fontWeight "bold"
                    , SvgA.fill "black"
                    ]
                    [ Svg.text formattedExpiryDate ]
                ]

            else
                []

        bestBeforeElements =
            if settings.showBestBefore then
                case formattedBestBeforeDate of
                    Just bbDate ->
                        [ Svg.text_
                            [ SvgA.x (String.fromInt settings.padding)
                            , SvgA.y (String.fromInt bestBeforeLabelY)
                            , SvgA.fontFamily settings.fontFamily
                            , SvgA.fontSize (String.fromInt settings.smallFontSize ++ "px")
                            , SvgA.fill "black"
                            ]
                            [ Svg.text "C.P.A.:" ]
                        , Svg.text_
                            [ SvgA.x (String.fromInt settings.padding)
                            , SvgA.y (String.fromInt bestBeforeDateY)
                            , SvgA.fontFamily settings.fontFamily
                            , SvgA.fontSize (String.fromInt settings.dateFontSize ++ "px")
                            , SvgA.fontWeight "bold"
                            , SvgA.fill "black"
                            ]
                            [ Svg.text bbDate ]
                        ]

                    Nothing ->
                        []

            else
                []

        brandingElement =
            if settings.showBranding then
                [ Svg.text_
                    [ SvgA.x (String.fromInt settings.padding)
                    , SvgA.y (String.fromInt brandingY)
                    , SvgA.fontFamily settings.fontFamily
                    , SvgA.fontSize (String.fromInt settings.smallFontSize ++ "px")
                    , SvgA.fill "#999999"
                    ]
                    [ Svg.text "❄️ FrostByte" ]
                ]

            else
                []

        qrElement =
            if settings.showQr then
                [ viewQrCode qrUrl qrX qrY settings.qrSize ]

            else
                []

        clipPathAttr =
            if settings.cornerRadius > 0 then
                [ SvgA.clipPath ("url(#" ++ clipId ++ ")") ]

            else
                []

        contentGroup =
            Svg.g clipPathAttr
                ([ backgroundRect ]
                    ++ titleElement
                    ++ separatorElement
                    ++ ingredientsElement
                    ++ expiryElements
                    ++ bestBeforeElements
                    ++ brandingElement
                    ++ qrElement
                )
    in
    Svg.svg
        [ SvgA.id (labelSvgId data.portionId)
        , SvgA.width (String.fromInt dispWidth)
        , SvgA.height (String.fromInt dispHeight)
        , SvgA.viewBox ("0 0 " ++ String.fromInt dispWidth ++ " " ++ String.fromInt dispHeight)
        ]
        (clipPathDef ++ [ contentGroup ])


{-| Render a QR code at the specified position.
-}
viewQrCode : String -> Int -> Int -> Int -> Svg msg
viewQrCode url x y size =
    case QRCode.fromString url of
        Ok qrCode ->
            Svg.g
                [ SvgA.transform ("translate(" ++ String.fromInt x ++ "," ++ String.fromInt y ++ ")")
                ]
                [ QRCode.toSvg
                    [ SvgA.width (String.fromInt size)
                    , SvgA.height (String.fromInt size)
                    ]
                    qrCode
                ]

        Err _ ->
            -- Fallback: gray placeholder rectangle
            Svg.rect
                [ SvgA.x (String.fromInt x)
                , SvgA.y (String.fromInt y)
                , SvgA.width (String.fromInt size)
                , SvgA.height (String.fromInt size)
                , SvgA.fill "#cccccc"
                ]
                []


{-| Truncate text with ellipsis if it exceeds maxLength.
-}
truncateText : Int -> String -> String
truncateText maxLength text =
    if String.length text > maxLength then
        String.left (maxLength - 3) text ++ "..."

    else
        text


{-| Convert ISO date (2025-12-31) to DD/MM/YYYY format.
-}
formatDate : String -> String
formatDate isoDate =
    case String.split "-" (String.left 10 isoDate) of
        [ year, month, day ] ->
            day ++ "/" ++ month ++ "/" ++ year

        _ ->
            isoDate
