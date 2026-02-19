module Api exposing
    ( createLabel
    , createLabelSet
    , createTemplate
    , deleteLabel
    , deleteLabelSet
    , deleteTemplate
    , emitEvent
    , fetchLabelDetail
    , fetchLabelList
    , fetchLabelSetDetail
    , fetchLabelSetList
    , fetchTemplateList
    , fetchTemplateDetail
    , printLabelPng
    )

import Api.Decoders as Decoders
import Api.Encoders as Encoders
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


emitEvent : String -> Encode.Value -> (Result Http.Error () -> msg) -> Cmd msg
emitEvent eventType payload toMsg =
    Http.post
        { url = "/api/db/event"
        , body = Http.jsonBody (Encoders.encodeEvent eventType payload)
        , expect = Http.expectWhatever toMsg
        }


deleteTemplate : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteTemplate templateId toMsg =
    emitEvent "template_deleted"
        (Encode.object [ ( "template_id", Encode.string templateId ) ])
        toMsg


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
    emitEvent "label_deleted"
        (Encode.object [ ( "label_id", Encode.string labelId ) ])
        toMsg


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
    emitEvent "labelset_deleted"
        (Encode.object [ ( "labelset_id", Encode.string labelsetId ) ])
        toMsg


printLabelPng : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
printLabelPng pngBase64 labelTypeId toMsg =
    Http.post
        { url = "/api/printer/print"
        , body = Http.jsonBody (Encoders.encodePrintRequest pngBase64 labelTypeId)
        , expect = Http.expectWhatever toMsg
        }
