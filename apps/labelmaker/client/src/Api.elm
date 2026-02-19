module Api exposing
    ( createLabel
    , createTemplate
    , deleteLabel
    , deleteTemplate
    , emitEvent
    , fetchLabelDetail
    , fetchLabelList
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


createLabel : String -> (Result Http.Error String -> msg) -> Cmd msg
createLabel templateId toMsg =
    Http.post
        { url = "/api/db/rpc/create_label"
        , body = Http.jsonBody (Encode.object [ ( "p_template_id", Encode.string templateId ) ])
        , expect = Http.expectJson toMsg Decoders.createLabelResponseDecoder
        }


deleteLabel : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteLabel labelId toMsg =
    emitEvent "label_deleted"
        (Encode.object [ ( "label_id", Encode.string labelId ) ])
        toMsg


printLabelPng : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
printLabelPng pngBase64 labelTypeId toMsg =
    Http.post
        { url = "/api/printer/print"
        , body = Http.jsonBody (Encoders.encodePrintRequest pngBase64 labelTypeId)
        , expect = Http.expectWhatever toMsg
        }
