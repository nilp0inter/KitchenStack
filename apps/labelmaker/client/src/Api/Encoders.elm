module Api.Encoders exposing
    ( encodeColor
    , encodeLabelObject
    , encodeLabelObjectList
    , encodePrintRequest
    , encodeShapeProperties
    , encodeShapeType
    , encodeTextProperties
    )

import Data.LabelObject as LO exposing (LabelObject(..), ShapeType(..))
import Json.Encode as Encode


encodeLabelObjectList : List LabelObject -> Encode.Value
encodeLabelObjectList objects =
    Encode.list encodeLabelObject objects


encodeLabelObject : LabelObject -> Encode.Value
encodeLabelObject obj =
    case obj of
        Container r ->
            Encode.object
                [ ( "type", Encode.string "container" )
                , ( "id", Encode.string r.id )
                , ( "name", Encode.string r.name )
                , ( "x", Encode.float r.x )
                , ( "y", Encode.float r.y )
                , ( "width", Encode.float r.width )
                , ( "height", Encode.float r.height )
                , ( "content", encodeLabelObjectList r.content )
                ]

        TextObj r ->
            Encode.object
                [ ( "type", Encode.string "text" )
                , ( "id", Encode.string r.id )
                , ( "content", Encode.string r.content )
                , ( "properties", encodeTextProperties r.properties )
                ]

        VariableObj r ->
            Encode.object
                [ ( "type", Encode.string "variable" )
                , ( "id", Encode.string r.id )
                , ( "name", Encode.string r.name )
                , ( "properties", encodeTextProperties r.properties )
                ]

        ImageObj r ->
            Encode.object
                [ ( "type", Encode.string "image" )
                , ( "id", Encode.string r.id )
                , ( "url", Encode.string r.url )
                ]

        VSplit r ->
            Encode.object
                [ ( "type", Encode.string "vsplit" )
                , ( "id", Encode.string r.id )
                , ( "name", Encode.string r.name )
                , ( "split", Encode.float r.split )
                , ( "top", encodeMaybeLabelObject r.top )
                , ( "bottom", encodeMaybeLabelObject r.bottom )
                ]

        HSplit r ->
            Encode.object
                [ ( "type", Encode.string "hsplit" )
                , ( "id", Encode.string r.id )
                , ( "name", Encode.string r.name )
                , ( "split", Encode.float r.split )
                , ( "left", encodeMaybeLabelObject r.left )
                , ( "right", encodeMaybeLabelObject r.right )
                ]

        ShapeObj r ->
            Encode.object
                [ ( "type", Encode.string "shape" )
                , ( "id", Encode.string r.id )
                , ( "properties", encodeShapeProperties r.properties )
                ]


encodeMaybeLabelObject : Maybe LabelObject -> Encode.Value
encodeMaybeLabelObject maybeObj =
    case maybeObj of
        Just obj ->
            encodeLabelObject obj

        Nothing ->
            Encode.null


encodeTextProperties : LO.TextProperties -> Encode.Value
encodeTextProperties props =
    Encode.object
        [ ( "fontSize", Encode.float props.fontSize )
        , ( "fontFamily", Encode.string props.fontFamily )
        , ( "color", encodeColor props.color )
        , ( "hAlign", encodeHAlign props.hAlign )
        , ( "vAlign", encodeVAlign props.vAlign )
        , ( "fontWeight", Encode.string props.fontWeight )
        , ( "lineHeight", Encode.float props.lineHeight )
        ]


encodeHAlign : LO.HAlign -> Encode.Value
encodeHAlign align =
    case align of
        LO.AlignLeft ->
            Encode.string "left"

        LO.AlignCenter ->
            Encode.string "center"

        LO.AlignRight ->
            Encode.string "right"


encodeVAlign : LO.VAlign -> Encode.Value
encodeVAlign align =
    case align of
        LO.AlignTop ->
            Encode.string "top"

        LO.AlignMiddle ->
            Encode.string "middle"

        LO.AlignBottom ->
            Encode.string "bottom"


encodeShapeProperties : LO.ShapeProperties -> Encode.Value
encodeShapeProperties props =
    Encode.object
        [ ( "shapeType", encodeShapeType props.shapeType )
        , ( "color", encodeColor props.color )
        ]


encodeColor : LO.Color -> Encode.Value
encodeColor color =
    Encode.object
        [ ( "r", Encode.int color.r )
        , ( "g", Encode.int color.g )
        , ( "b", Encode.int color.b )
        , ( "a", Encode.float color.a )
        ]


encodeShapeType : ShapeType -> Encode.Value
encodeShapeType st =
    case st of
        Rectangle ->
            Encode.string "rectangle"

        Circle ->
            Encode.string "circle"

        Line ->
            Encode.string "line"


encodePrintRequest : String -> String -> Encode.Value
encodePrintRequest pngBase64 labelType =
    Encode.object
        [ ( "image_data", Encode.string pngBase64 )
        , ( "label_type", Encode.string labelType )
        ]
