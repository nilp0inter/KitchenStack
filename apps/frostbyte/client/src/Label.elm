module Label exposing
    ( labelSvgId
    , viewLabelWithComputed
    )

{-| SVG label rendering for FrostByte freezer labels.

This module generates SVG labels that can be converted to PNG for printing.
Layout matches the original Python printer service output.

-}

import Data.Date as Date
import Data.Label exposing (ComputedLabelData, LabelData, LabelSettings, displayHeight, displayWidth, textMaxWidth)
import Html exposing (Html)
import QRCode
import Svg exposing (Svg)
import Svg.Attributes as SvgA


{-| Generate a unique SVG element ID for a portion.
-}
labelSvgId : String -> String
labelSvgId portionId =
    "label-svg-" ++ portionId




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

        -- Snowflake size is 1.5x the small font size for better visibility
        snowflakeFontSize =
            (settings.smallFontSize * 3) // 2

        -- Shift snowflake down to align with text baseline
        snowflakeYOffset =
            (snowflakeFontSize - settings.smallFontSize) // 3

        brandingElement =
            if settings.showBranding then
                [ Svg.text_
                    [ SvgA.x (String.fromInt settings.padding)
                    , SvgA.y (String.fromInt brandingY)
                    , SvgA.fill "#999999"
                    ]
                    [ Svg.tspan
                        [ SvgA.fontFamily "sans-serif"
                        , SvgA.fontSize (String.fromInt snowflakeFontSize ++ "px")
                        , SvgA.dy (String.fromInt snowflakeYOffset)
                        ]
                        [ Svg.text "❄" ]
                    , Svg.tspan
                        [ SvgA.fontFamily settings.fontFamily
                        , SvgA.fontSize (String.fromInt settings.smallFontSize ++ "px")
                        , SvgA.dy (String.fromInt -snowflakeYOffset)
                        ]
                        [ Svg.text "FrostByte" ]
                    ]
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
    case Date.fromIsoString isoDate of
        Just date ->
            Date.formatDisplay date

        Nothing ->
            isoDate
