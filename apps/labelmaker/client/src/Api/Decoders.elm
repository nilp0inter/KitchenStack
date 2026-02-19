module Api.Decoders exposing
    ( LabelDetail
    , LabelSummary
    , TemplateDetail
    , TemplateSummary
    , colorDecoder
    , createLabelResponseDecoder
    , createTemplateResponseDecoder
    , labelDetailDecoder
    , labelObjectDecoder
    , labelSummaryDecoder
    , shapePropertiesDecoder
    , shapeTypeDecoder
    , templateDetailDecoder
    , templateSummaryDecoder
    , textPropertiesDecoder
    )

import Data.LabelObject as LO exposing (LabelObject(..), ShapeType(..))
import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder)


andMap : Decoder a -> Decoder (a -> b) -> Decoder b
andMap =
    Decode.map2 (|>)


type alias TemplateSummary =
    { id : String
    , name : String
    , labelTypeId : String
    , createdAt : String
    }


templateSummaryDecoder : Decoder TemplateSummary
templateSummaryDecoder =
    Decode.succeed TemplateSummary
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "label_type_id" Decode.string)
        |> andMap (Decode.field "created_at" Decode.string)


type alias TemplateDetail =
    { id : String
    , name : String
    , labelTypeId : String
    , labelWidth : Int
    , labelHeight : Int
    , cornerRadius : Int
    , rotate : Bool
    , padding : Int
    , content : List LabelObject
    , nextId : Int
    , sampleValues : Dict String String
    }


templateDetailDecoder : Decoder TemplateDetail
templateDetailDecoder =
    Decode.succeed TemplateDetail
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "label_type_id" Decode.string)
        |> andMap (Decode.field "label_width" Decode.int)
        |> andMap (Decode.field "label_height" Decode.int)
        |> andMap (Decode.field "corner_radius" Decode.int)
        |> andMap (Decode.field "rotate" Decode.bool)
        |> andMap (Decode.field "padding" Decode.int)
        |> andMap (Decode.field "content" (Decode.list labelObjectDecoder))
        |> andMap (Decode.field "next_id" Decode.int)
        |> andMap (Decode.field "sample_values" (Decode.dict Decode.string))


labelObjectDecoder : Decoder LabelObject
labelObjectDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen labelObjectByType


labelObjectByType : String -> Decoder LabelObject
labelObjectByType typeStr =
    case typeStr of
        "container" ->
            Decode.map6
                (\id x y w h content ->
                    Container { id = id, x = x, y = y, width = w, height = h, content = content }
                )
                (Decode.field "id" Decode.string)
                (Decode.field "x" Decode.float)
                (Decode.field "y" Decode.float)
                (Decode.field "width" Decode.float)
                (Decode.field "height" Decode.float)
                (Decode.field "content" (Decode.lazy (\_ -> Decode.list labelObjectDecoder)))

        "text" ->
            Decode.map3
                (\id content props ->
                    TextObj { id = id, content = content, properties = props }
                )
                (Decode.field "id" Decode.string)
                (Decode.field "content" Decode.string)
                (Decode.field "properties" textPropertiesDecoder)

        "variable" ->
            Decode.map3
                (\id name props ->
                    VariableObj { id = id, name = name, properties = props }
                )
                (Decode.field "id" Decode.string)
                (Decode.field "name" Decode.string)
                (Decode.field "properties" textPropertiesDecoder)

        "image" ->
            Decode.map2
                (\id url ->
                    ImageObj { id = id, url = url }
                )
                (Decode.field "id" Decode.string)
                (Decode.field "url" Decode.string)

        "shape" ->
            Decode.map2
                (\id props ->
                    ShapeObj { id = id, properties = props }
                )
                (Decode.field "id" Decode.string)
                (Decode.field "properties" shapePropertiesDecoder)

        _ ->
            Decode.fail ("Unknown label object type: " ++ typeStr)


textPropertiesDecoder : Decoder LO.TextProperties
textPropertiesDecoder =
    Decode.map3 LO.TextProperties
        (Decode.field "fontSize" Decode.float)
        (Decode.field "fontFamily" Decode.string)
        (Decode.field "color" colorDecoder)


shapePropertiesDecoder : Decoder LO.ShapeProperties
shapePropertiesDecoder =
    Decode.map2 LO.ShapeProperties
        (Decode.field "shapeType" shapeTypeDecoder)
        (Decode.field "color" colorDecoder)


colorDecoder : Decoder LO.Color
colorDecoder =
    Decode.map4 LO.Color
        (Decode.field "r" Decode.int)
        (Decode.field "g" Decode.int)
        (Decode.field "b" Decode.int)
        (Decode.field "a" Decode.float)


shapeTypeDecoder : Decoder ShapeType
shapeTypeDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "rectangle" ->
                        Decode.succeed Rectangle

                    "circle" ->
                        Decode.succeed Circle

                    "line" ->
                        Decode.succeed Line

                    _ ->
                        Decode.fail ("Unknown shape type: " ++ s)
            )


createTemplateResponseDecoder : Decoder String
createTemplateResponseDecoder =
    Decode.index 0 (Decode.field "template_id" Decode.string)


type alias LabelSummary =
    { id : String
    , templateId : String
    , templateName : String
    , labelTypeId : String
    , values : Dict String String
    , createdAt : String
    }


labelSummaryDecoder : Decoder LabelSummary
labelSummaryDecoder =
    Decode.succeed LabelSummary
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "template_id" Decode.string)
        |> andMap (Decode.field "template_name" Decode.string)
        |> andMap (Decode.field "label_type_id" Decode.string)
        |> andMap (Decode.field "values" (Decode.dict Decode.string))
        |> andMap (Decode.field "created_at" Decode.string)


type alias LabelDetail =
    { id : String
    , templateId : String
    , templateName : String
    , labelTypeId : String
    , labelWidth : Int
    , labelHeight : Int
    , cornerRadius : Int
    , rotate : Bool
    , padding : Int
    , content : List LabelObject
    , values : Dict String String
    , createdAt : String
    }


labelDetailDecoder : Decoder LabelDetail
labelDetailDecoder =
    Decode.succeed LabelDetail
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "template_id" Decode.string)
        |> andMap (Decode.field "template_name" Decode.string)
        |> andMap (Decode.field "label_type_id" Decode.string)
        |> andMap (Decode.field "label_width" Decode.int)
        |> andMap (Decode.field "label_height" Decode.int)
        |> andMap (Decode.field "corner_radius" Decode.int)
        |> andMap (Decode.field "rotate" Decode.bool)
        |> andMap (Decode.field "padding" Decode.int)
        |> andMap (Decode.field "content" (Decode.list labelObjectDecoder))
        |> andMap (Decode.field "values" (Decode.dict Decode.string))
        |> andMap (Decode.field "created_at" Decode.string)


createLabelResponseDecoder : Decoder String
createLabelResponseDecoder =
    Decode.index 0 (Decode.field "label_id" Decode.string)
