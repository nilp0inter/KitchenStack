module Api.Decoders exposing
    ( LabelDetail
    , LabelSetDetail
    , LabelSetSummary
    , LabelSummary
    , TemplateDetail
    , TemplateSummary
    , colorDecoder
    , createLabelResponseDecoder
    , createLabelSetResponseDecoder
    , createTemplateResponseDecoder
    , labelDetailDecoder
    , labelObjectDecoder
    , labelSetDetailDecoder
    , labelSetSummaryDecoder
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
    , offsetX : Int
    , offsetY : Int
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
        |> andMap (optionalField "offset_x" Decode.int 0)
        |> andMap (optionalField "offset_y" Decode.int 0)
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
            Decode.succeed
                (\id name x y w h content ->
                    Container { id = id, name = name, x = x, y = y, width = w, height = h, content = content }
                )
                |> andMap (Decode.field "id" Decode.string)
                |> andMap
                    (Decode.field "name" Decode.string
                        |> Decode.maybe
                        |> Decode.map (Maybe.withDefault "")
                    )
                |> andMap (Decode.field "x" Decode.float)
                |> andMap (Decode.field "y" Decode.float)
                |> andMap (Decode.field "width" Decode.float)
                |> andMap (Decode.field "height" Decode.float)
                |> andMap (Decode.field "content" (Decode.lazy (\_ -> Decode.list labelObjectDecoder)))

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

        "vsplit" ->
            Decode.succeed
                (\id name split top bottom ->
                    VSplit { id = id, name = name, split = split, top = top, bottom = bottom }
                )
                |> andMap (Decode.field "id" Decode.string)
                |> andMap
                    (Decode.field "name" Decode.string
                        |> Decode.maybe
                        |> Decode.map (Maybe.withDefault "")
                    )
                |> andMap (Decode.field "split" Decode.float)
                |> andMap (Decode.field "top" (Decode.lazy (\_ -> Decode.nullable labelObjectDecoder)))
                |> andMap (Decode.field "bottom" (Decode.lazy (\_ -> Decode.nullable labelObjectDecoder)))

        "hsplit" ->
            Decode.succeed
                (\id name split left right ->
                    HSplit { id = id, name = name, split = split, left = left, right = right }
                )
                |> andMap (Decode.field "id" Decode.string)
                |> andMap
                    (Decode.field "name" Decode.string
                        |> Decode.maybe
                        |> Decode.map (Maybe.withDefault "")
                    )
                |> andMap (Decode.field "split" Decode.float)
                |> andMap (Decode.field "left" (Decode.lazy (\_ -> Decode.nullable labelObjectDecoder)))
                |> andMap (Decode.field "right" (Decode.lazy (\_ -> Decode.nullable labelObjectDecoder)))

        _ ->
            Decode.fail ("Unknown label object type: " ++ typeStr)


textPropertiesDecoder : Decoder LO.TextProperties
textPropertiesDecoder =
    Decode.succeed LO.TextProperties
        |> andMap (Decode.field "fontSize" Decode.float)
        |> andMap (Decode.field "fontFamily" Decode.string)
        |> andMap (Decode.field "color" colorDecoder)
        |> andMap (optionalField "hAlign" hAlignDecoder LO.AlignCenter)
        |> andMap (optionalField "vAlign" vAlignDecoder LO.AlignMiddle)
        |> andMap (optionalField "fontWeight" Decode.string "bold")
        |> andMap (optionalField "lineHeight" Decode.float 1.2)


optionalField : String -> Decoder a -> a -> Decoder a
optionalField fieldName decoder default =
    Decode.oneOf
        [ Decode.field fieldName decoder
        , Decode.succeed default
        ]


hAlignDecoder : Decoder LO.HAlign
hAlignDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "left" ->
                        Decode.succeed LO.AlignLeft

                    "center" ->
                        Decode.succeed LO.AlignCenter

                    "right" ->
                        Decode.succeed LO.AlignRight

                    _ ->
                        Decode.fail ("Unknown hAlign: " ++ s)
            )


vAlignDecoder : Decoder LO.VAlign
vAlignDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "top" ->
                        Decode.succeed LO.AlignTop

                    "middle" ->
                        Decode.succeed LO.AlignMiddle

                    "bottom" ->
                        Decode.succeed LO.AlignBottom

                    _ ->
                        Decode.fail ("Unknown vAlign: " ++ s)
            )


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
    , name : String
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
        |> andMap (Decode.field "name" Decode.string)
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
    , offsetX : Int
    , offsetY : Int
    , content : List LabelObject
    , name : String
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
        |> andMap (optionalField "offset_x" Decode.int 0)
        |> andMap (optionalField "offset_y" Decode.int 0)
        |> andMap (Decode.field "content" (Decode.list labelObjectDecoder))
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "values" (Decode.dict Decode.string))
        |> andMap (Decode.field "created_at" Decode.string)


createLabelResponseDecoder : Decoder String
createLabelResponseDecoder =
    Decode.index 0 (Decode.field "label_id" Decode.string)


type alias LabelSetSummary =
    { id : String
    , templateId : String
    , templateName : String
    , labelTypeId : String
    , name : String
    , rowCount : Int
    , createdAt : String
    }


labelSetSummaryDecoder : Decoder LabelSetSummary
labelSetSummaryDecoder =
    Decode.succeed LabelSetSummary
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "template_id" Decode.string)
        |> andMap (Decode.field "template_name" Decode.string)
        |> andMap (Decode.field "label_type_id" Decode.string)
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "row_count" Decode.int)
        |> andMap (Decode.field "created_at" Decode.string)


type alias LabelSetDetail =
    { id : String
    , templateId : String
    , templateName : String
    , labelTypeId : String
    , labelWidth : Int
    , labelHeight : Int
    , cornerRadius : Int
    , rotate : Bool
    , padding : Int
    , offsetX : Int
    , offsetY : Int
    , content : List LabelObject
    , name : String
    , rows : List (Dict String String)
    , createdAt : String
    }


labelSetDetailDecoder : Decoder LabelSetDetail
labelSetDetailDecoder =
    Decode.succeed LabelSetDetail
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "template_id" Decode.string)
        |> andMap (Decode.field "template_name" Decode.string)
        |> andMap (Decode.field "label_type_id" Decode.string)
        |> andMap (Decode.field "label_width" Decode.int)
        |> andMap (Decode.field "label_height" Decode.int)
        |> andMap (Decode.field "corner_radius" Decode.int)
        |> andMap (Decode.field "rotate" Decode.bool)
        |> andMap (Decode.field "padding" Decode.int)
        |> andMap (optionalField "offset_x" Decode.int 0)
        |> andMap (optionalField "offset_y" Decode.int 0)
        |> andMap (Decode.field "content" (Decode.list labelObjectDecoder))
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "rows" (Decode.list (Decode.dict Decode.string)))
        |> andMap (Decode.field "created_at" Decode.string)


createLabelSetResponseDecoder : Decoder String
createLabelSetResponseDecoder =
    Decode.index 0 (Decode.field "labelset_id" Decode.string)
