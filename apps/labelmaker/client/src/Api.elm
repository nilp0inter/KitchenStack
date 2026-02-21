module Api exposing
    ( createLabel
    , createLabelSet
    , createTemplate
    , deleteLabel
    , deleteLabelSet
    , deleteTemplate
    , fetchLabelDetail
    , fetchLabelList
    , fetchLabelSetDetail
    , fetchLabelSetList
    , fetchTemplateList
    , fetchTemplateDetail
    , printLabelPng
    , setLabelName
    , setLabelValues
    , setLabelsetName
    , setLabelsetRows
    , setTemplateContent
    , setTemplateHeight
    , setTemplateLabelType
    , setTemplateName
    , setTemplateOffset
    , setTemplatePadding
    , setTemplateSampleValue
    )

import Api.Decoders as Decoders
import Api.Encoders as Encoders
import Dict
import Http
import Json.Decode as Decode
import Json.Encode as Encode


fetchTemplateList : (Result Http.Error (List Decoders.TemplateSummary) -> msg) -> Cmd msg
fetchTemplateList toMsg =
    Http.get
        { url = "/api/db/template_list"
        , expect = Http.expectJson toMsg (Decode.list Decoders.templateSummaryDecoder)
        }


fetchTemplateDetail : String -> (Result Http.Error (Maybe Decoders.TemplateDetail) -> msg) -> Cmd msg
fetchTemplateDetail templateId toMsg =
    Http.get
        { url = "/api/db/template_detail?id=eq." ++ templateId
        , expect =
            Http.expectJson toMsg
                (Decode.list Decoders.templateDetailDecoder
                    |> Decode.map List.head
                )
        }


createTemplate : String -> (Result Http.Error String -> msg) -> Cmd msg
createTemplate name toMsg =
    Http.post
        { url = "/api/db/rpc/create_template"
        , body = Http.jsonBody (Encode.object [ ( "p_name", Encode.string name ) ])
        , expect = Http.expectJson toMsg Decoders.createTemplateResponseDecoder
        }


deleteTemplate : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteTemplate templateId toMsg =
    Http.post
        { url = "/api/db/rpc/delete_template"
        , body = Http.jsonBody (Encode.object [ ( "p_template_id", Encode.string templateId ) ])
        , expect = Http.expectWhatever toMsg
        }


setTemplateName : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
setTemplateName templateId name toMsg =
    Http.post
        { url = "/api/db/rpc/set_template_name"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_template_id", Encode.string templateId )
                    , ( "p_name", Encode.string name )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


setTemplateLabelType : String -> String -> Int -> Int -> Int -> Bool -> (Result Http.Error () -> msg) -> Cmd msg
setTemplateLabelType templateId labelTypeId labelWidth labelHeight cornerRadius rotate toMsg =
    Http.post
        { url = "/api/db/rpc/set_template_label_type"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_template_id", Encode.string templateId )
                    , ( "p_label_type_id", Encode.string labelTypeId )
                    , ( "p_label_width", Encode.int labelWidth )
                    , ( "p_label_height", Encode.int labelHeight )
                    , ( "p_corner_radius", Encode.int cornerRadius )
                    , ( "p_rotate", Encode.bool rotate )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


setTemplateHeight : String -> Int -> (Result Http.Error () -> msg) -> Cmd msg
setTemplateHeight templateId labelHeight toMsg =
    Http.post
        { url = "/api/db/rpc/set_template_height"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_template_id", Encode.string templateId )
                    , ( "p_label_height", Encode.int labelHeight )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


setTemplatePadding : String -> Int -> (Result Http.Error () -> msg) -> Cmd msg
setTemplatePadding templateId padding toMsg =
    Http.post
        { url = "/api/db/rpc/set_template_padding"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_template_id", Encode.string templateId )
                    , ( "p_padding", Encode.int padding )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


setTemplateOffset : String -> Int -> Int -> (Result Http.Error () -> msg) -> Cmd msg
setTemplateOffset templateId offsetX offsetY toMsg =
    Http.post
        { url = "/api/db/rpc/set_template_offset"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_template_id", Encode.string templateId )
                    , ( "p_offset_x", Encode.int offsetX )
                    , ( "p_offset_y", Encode.int offsetY )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


setTemplateContent : String -> Encode.Value -> Int -> (Result Http.Error () -> msg) -> Cmd msg
setTemplateContent templateId content nextId toMsg =
    Http.post
        { url = "/api/db/rpc/set_template_content"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_template_id", Encode.string templateId )
                    , ( "p_content", content )
                    , ( "p_next_id", Encode.int nextId )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


setTemplateSampleValue : String -> String -> String -> (Result Http.Error () -> msg) -> Cmd msg
setTemplateSampleValue templateId variableName value toMsg =
    Http.post
        { url = "/api/db/rpc/set_template_sample_value"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_template_id", Encode.string templateId )
                    , ( "p_variable_name", Encode.string variableName )
                    , ( "p_value", Encode.string value )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


fetchLabelList : (Result Http.Error (List Decoders.LabelSummary) -> msg) -> Cmd msg
fetchLabelList toMsg =
    Http.get
        { url = "/api/db/label_list"
        , expect = Http.expectJson toMsg (Decode.list Decoders.labelSummaryDecoder)
        }


fetchLabelDetail : String -> (Result Http.Error (Maybe Decoders.LabelDetail) -> msg) -> Cmd msg
fetchLabelDetail labelId toMsg =
    Http.get
        { url = "/api/db/label_detail?id=eq." ++ labelId
        , expect =
            Http.expectJson toMsg
                (Decode.list Decoders.labelDetailDecoder
                    |> Decode.map List.head
                )
        }


createLabel : String -> String -> (Result Http.Error String -> msg) -> Cmd msg
createLabel templateId name toMsg =
    Http.post
        { url = "/api/db/rpc/create_label"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_template_id", Encode.string templateId )
                    , ( "p_name", Encode.string name )
                    ]
                )
        , expect = Http.expectJson toMsg Decoders.createLabelResponseDecoder
        }


deleteLabel : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteLabel labelId toMsg =
    Http.post
        { url = "/api/db/rpc/delete_label"
        , body = Http.jsonBody (Encode.object [ ( "p_label_id", Encode.string labelId ) ])
        , expect = Http.expectWhatever toMsg
        }


setLabelName : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
setLabelName labelId name toMsg =
    Http.post
        { url = "/api/db/rpc/set_label_name"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_label_id", Encode.string labelId )
                    , ( "p_name", Encode.string name )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


setLabelValues : String -> Dict.Dict String String -> (Result Http.Error () -> msg) -> Cmd msg
setLabelValues labelId values toMsg =
    Http.post
        { url = "/api/db/rpc/set_label_values"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_label_id", Encode.string labelId )
                    , ( "p_values", Encode.dict identity Encode.string values )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


fetchLabelSetList : (Result Http.Error (List Decoders.LabelSetSummary) -> msg) -> Cmd msg
fetchLabelSetList toMsg =
    Http.get
        { url = "/api/db/labelset_list"
        , expect = Http.expectJson toMsg (Decode.list Decoders.labelSetSummaryDecoder)
        }


fetchLabelSetDetail : String -> (Result Http.Error (Maybe Decoders.LabelSetDetail) -> msg) -> Cmd msg
fetchLabelSetDetail labelsetId toMsg =
    Http.get
        { url = "/api/db/labelset_detail?id=eq." ++ labelsetId
        , expect =
            Http.expectJson toMsg
                (Decode.list Decoders.labelSetDetailDecoder
                    |> Decode.map List.head
                )
        }


createLabelSet : String -> String -> (Result Http.Error String -> msg) -> Cmd msg
createLabelSet templateId name toMsg =
    Http.post
        { url = "/api/db/rpc/create_labelset"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_template_id", Encode.string templateId )
                    , ( "p_name", Encode.string name )
                    ]
                )
        , expect = Http.expectJson toMsg Decoders.createLabelSetResponseDecoder
        }


deleteLabelSet : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteLabelSet labelsetId toMsg =
    Http.post
        { url = "/api/db/rpc/delete_labelset"
        , body = Http.jsonBody (Encode.object [ ( "p_labelset_id", Encode.string labelsetId ) ])
        , expect = Http.expectWhatever toMsg
        }


setLabelsetName : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
setLabelsetName labelsetId name toMsg =
    Http.post
        { url = "/api/db/rpc/set_labelset_name"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_labelset_id", Encode.string labelsetId )
                    , ( "p_name", Encode.string name )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


setLabelsetRows : String -> List (Dict.Dict String String) -> (Result Http.Error () -> msg) -> Cmd msg
setLabelsetRows labelsetId rows toMsg =
    Http.post
        { url = "/api/db/rpc/set_labelset_rows"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "p_labelset_id", Encode.string labelsetId )
                    , ( "p_rows", Encode.list (Encode.dict identity Encode.string) rows )
                    ]
                )
        , expect = Http.expectWhatever toMsg
        }


printLabelPng : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
printLabelPng pngBase64 labelTypeId toMsg =
    Http.post
        { url = "/api/printer/print"
        , body = Http.jsonBody (Encoders.encodePrintRequest pngBase64 labelTypeId)
        , expect = Http.expectWhatever toMsg
        }
