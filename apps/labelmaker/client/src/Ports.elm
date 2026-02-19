port module Ports exposing
    ( PngResult
    , SvgToPngRequest
    , TextMeasureRequest
    , TextMeasureResult
    , receivePngResult
    , receiveTextMeasureResult
    , requestSvgToPng
    , requestTextMeasure
    )


type alias TextMeasureRequest =
    { requestId : String
    , text : String
    , fontFamily : String
    , maxFontSize : Int
    , minFontSize : Int
    , maxWidth : Int
    , maxHeight : Int
    }


type alias TextMeasureResult =
    { requestId : String
    , fittedFontSize : Int
    , lines : List String
    }


type alias SvgToPngRequest =
    { svgId : String
    , requestId : String
    , width : Int
    , height : Int
    , rotate : Bool
    }


type alias PngResult =
    { requestId : String
    , dataUrl : Maybe String
    , error : Maybe String
    }


port requestTextMeasure : TextMeasureRequest -> Cmd msg


port receiveTextMeasureResult : (TextMeasureResult -> msg) -> Sub msg


port requestSvgToPng : SvgToPngRequest -> Cmd msg


port receivePngResult : (PngResult -> msg) -> Sub msg
