module Api exposing
    ( consumePortion
    , createBatch
    , deleteContainerType
    , fetchBatchPortions
    , fetchBatches
    , fetchCategories
    , fetchContainerTypes
    , fetchHistory
    , fetchPortionDetail
    , printLabel
    , returnPortionToFreezer
    , saveContainerType
    )

import Api.Decoders exposing (..)
import Api.Encoders exposing (..)
import Http
import Json.Decode as Decode
import Types exposing (..)
import UUID exposing (UUID)
import Url


fetchCategories : (Result Http.Error (List Category) -> msg) -> Cmd msg
fetchCategories toMsg =
    Http.get
        { url = "/api/db/category"
        , expect = Http.expectJson toMsg (Decode.list categoryDecoder)
        }


fetchContainerTypes : (Result Http.Error (List ContainerType) -> msg) -> Cmd msg
fetchContainerTypes toMsg =
    Http.get
        { url = "/api/db/container_type"
        , expect = Http.expectJson toMsg (Decode.list containerTypeDecoder)
        }


fetchBatches : (Result Http.Error (List BatchSummary) -> msg) -> Cmd msg
fetchBatches toMsg =
    Http.get
        { url = "/api/db/batch_summary?frozen_count=gt.0&order=expiry_date.asc"
        , expect = Http.expectJson toMsg (Decode.list batchSummaryDecoder)
        }


fetchPortionDetail : String -> (Result Http.Error PortionDetail -> msg) -> Cmd msg
fetchPortionDetail portionId toMsg =
    Http.get
        { url = "/api/db/portion_detail?portion_id=eq." ++ portionId
        , expect = Http.expectJson toMsg (Decode.index 0 portionDetailDecoder)
        }


fetchHistory : (Result Http.Error (List HistoryPoint) -> msg) -> Cmd msg
fetchHistory toMsg =
    Http.get
        { url = "/api/db/freezer_history"
        , expect = Http.expectJson toMsg (Decode.list historyPointDecoder)
        }


fetchBatchPortions : String -> (Result Http.Error (List PortionInBatch) -> msg) -> Cmd msg
fetchBatchPortions batchId toMsg =
    Http.get
        { url = "/api/db/portion?batch_id=eq." ++ batchId ++ "&order=created_at.asc"
        , expect = Http.expectJson toMsg (Decode.list portionInBatchDecoder)
        }


createBatch : BatchForm -> UUID -> List UUID -> (Result Http.Error CreateBatchResponse -> msg) -> Cmd msg
createBatch form batchUuid portionUuids toMsg =
    Http.post
        { url = "/api/db/rpc/create_batch"
        , body = Http.jsonBody (encodeBatchRequest form batchUuid portionUuids)
        , expect = Http.expectJson toMsg createBatchResponseDecoder
        }


printLabel : PortionPrintData -> (String -> Result Http.Error () -> msg) -> Cmd msg
printLabel data toMsg =
    Http.post
        { url = "/api/printer/print"
        , body = Http.jsonBody (encodePrintRequest data)
        , expect = Http.expectWhatever (toMsg data.portionId)
        }


consumePortion : String -> (Result Http.Error () -> msg) -> Cmd msg
consumePortion portionId toMsg =
    Http.request
        { method = "PATCH"
        , headers = []
        , url = "/api/db/portion?id=eq." ++ portionId
        , body = Http.jsonBody encodeConsumeRequest
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


returnPortionToFreezer : String -> (Result Http.Error () -> msg) -> Cmd msg
returnPortionToFreezer portionId toMsg =
    Http.request
        { method = "PATCH"
        , headers = []
        , url = "/api/db/portion?id=eq." ++ portionId
        , body = Http.jsonBody encodeReturnToFreezerRequest
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


saveContainerType : ContainerTypeForm -> (Result Http.Error () -> msg) -> Cmd msg
saveContainerType form toMsg =
    let
        ( method, url ) =
            case form.editing of
                Just originalName ->
                    ( "PATCH", "/api/db/container_type?name=eq." ++ Url.percentEncode originalName )

                Nothing ->
                    ( "POST", "/api/db/container_type" )
    in
    Http.request
        { method = method
        , headers = []
        , url = url
        , body = Http.jsonBody (encodeContainerType form)
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


deleteContainerType : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteContainerType name toMsg =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/db/container_type?name=eq." ++ Url.percentEncode name
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }
