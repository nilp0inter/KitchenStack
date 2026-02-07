module Api exposing
    ( consumePortion
    , createBatch
    , deleteContainerType
    , deleteIngredient
    , deleteLabelPreset
    , deleteRecipe
    , fetchBatchPortions
    , fetchBatches
    , fetchContainerTypes
    , fetchHistory
    , fetchIngredients
    , fetchLabelPresets
    , fetchPortionDetail
    , fetchRecipes
    , printLabel
    , printLabelPng
    , returnPortionToFreezer
    , saveContainerType
    , saveIngredient
    , saveLabelPreset
    , saveRecipe
    )

import Api.Decoders exposing (..)
import Api.Encoders exposing (..)
import Http
import Json.Decode as Decode
import Types exposing (..)
import UUID exposing (UUID)
import Url


fetchIngredients : (Result Http.Error (List Ingredient) -> msg) -> Cmd msg
fetchIngredients toMsg =
    Http.get
        { url = "/api/db/ingredient?order=name.asc"
        , expect = Http.expectJson toMsg (Decode.list ingredientDecoder)
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


createBatch : BatchForm -> UUID -> List UUID -> Maybe String -> (Result Http.Error CreateBatchResponse -> msg) -> Cmd msg
createBatch form batchUuid portionUuids maybeLabelPreset toMsg =
    Http.post
        { url = "/api/db/rpc/create_batch"
        , body = Http.jsonBody (encodeBatchRequest form batchUuid portionUuids maybeLabelPreset)
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


saveIngredient : IngredientForm -> (Result Http.Error () -> msg) -> Cmd msg
saveIngredient form toMsg =
    let
        ( method, url ) =
            case form.editing of
                Just originalName ->
                    ( "PATCH", "/api/db/ingredient?name=eq." ++ Url.percentEncode originalName )

                Nothing ->
                    ( "POST", "/api/db/ingredient" )
    in
    Http.request
        { method = method
        , headers = []
        , url = url
        , body = Http.jsonBody (encodeIngredient form)
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


deleteIngredient : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteIngredient name toMsg =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/db/ingredient?name=eq." ++ Url.percentEncode name
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


fetchRecipes : (Result Http.Error (List Recipe) -> msg) -> Cmd msg
fetchRecipes toMsg =
    Http.get
        { url = "/api/db/recipe_summary?order=name.asc"
        , expect = Http.expectJson toMsg (Decode.list recipeDecoder)
        }


saveRecipe : RecipeForm -> (Result Http.Error () -> msg) -> Cmd msg
saveRecipe form toMsg =
    Http.post
        { url = "/api/db/rpc/save_recipe"
        , body = Http.jsonBody (encodeRecipeRequest form)
        , expect = Http.expectWhatever toMsg
        }


deleteRecipe : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteRecipe name toMsg =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/db/recipe?name=eq." ++ Url.percentEncode name
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


fetchLabelPresets : (Result Http.Error (List LabelPreset) -> msg) -> Cmd msg
fetchLabelPresets toMsg =
    Http.get
        { url = "/api/db/label_preset?order=name.asc"
        , expect = Http.expectJson toMsg (Decode.list labelPresetDecoder)
        }


saveLabelPreset : LabelPresetForm -> (Result Http.Error () -> msg) -> Cmd msg
saveLabelPreset form toMsg =
    let
        ( method, url ) =
            case form.editing of
                Just originalName ->
                    ( "PATCH", "/api/db/label_preset?name=eq." ++ Url.percentEncode originalName )

                Nothing ->
                    ( "POST", "/api/db/label_preset" )
    in
    Http.request
        { method = method
        , headers = []
        , url = url
        , body = Http.jsonBody (encodeLabelPreset form)
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


deleteLabelPreset : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteLabelPreset name toMsg =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/db/label_preset?name=eq." ++ Url.percentEncode name
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


printLabelPng : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
printLabelPng pngBase64 labelType toMsg =
    Http.post
        { url = "/api/printer/print"
        , body = Http.jsonBody (encodePrintPngRequest pngBase64 labelType)
        , expect = Http.expectWhatever toMsg
        }
