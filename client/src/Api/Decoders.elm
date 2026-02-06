module Api.Decoders exposing
    ( batchSummaryDecoder
    , containerTypeDecoder
    , createBatchResponseDecoder
    , historyPointDecoder
    , ingredientDecoder
    , portionDetailDecoder
    , portionInBatchDecoder
    , recipeDecoder
    )

import Json.Decode as Decode exposing (Decoder)
import Types exposing (..)


ingredientDecoder : Decoder Ingredient
ingredientDecoder =
    Decode.map3 Ingredient
        (Decode.field "name" Decode.string)
        (Decode.field "expire_days" (Decode.nullable Decode.int))
        (Decode.field "best_before_days" (Decode.nullable Decode.int))


containerTypeDecoder : Decoder ContainerType
containerTypeDecoder =
    Decode.map2 ContainerType
        (Decode.field "name" Decode.string)
        (Decode.field "servings_per_unit" Decode.float)


batchSummaryDecoder : Decoder BatchSummary
batchSummaryDecoder =
    Decode.succeed BatchSummary
        |> andMap (Decode.field "batch_id" Decode.string)
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "container_id" Decode.string)
        |> andMap (Decode.field "best_before_date" (Decode.nullable Decode.string))
        |> andMap (Decode.field "batch_created_at" Decode.string)
        |> andMap (Decode.field "expiry_date" Decode.string)
        |> andMap (Decode.field "frozen_count" Decode.int)
        |> andMap (Decode.field "consumed_count" Decode.int)
        |> andMap (Decode.field "total_count" Decode.int)
        |> andMap (Decode.field "ingredients" Decode.string)


andMap : Decoder a -> Decoder (a -> b) -> Decoder b
andMap =
    Decode.map2 (|>)


portionDetailDecoder : Decoder PortionDetail
portionDetailDecoder =
    Decode.succeed PortionDetail
        |> andMap (Decode.field "portion_id" Decode.string)
        |> andMap (Decode.field "batch_id" Decode.string)
        |> andMap (Decode.field "created_at" Decode.string)
        |> andMap (Decode.field "expiry_date" Decode.string)
        |> andMap (Decode.field "status" Decode.string)
        |> andMap (Decode.field "consumed_at" (Decode.nullable Decode.string))
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "container_id" Decode.string)
        |> andMap (Decode.field "best_before_date" (Decode.nullable Decode.string))
        |> andMap (Decode.field "ingredients" Decode.string)


createBatchResponseDecoder : Decoder CreateBatchResponse
createBatchResponseDecoder =
    Decode.index 0
        (Decode.map2 CreateBatchResponse
            (Decode.field "batch_id" Decode.string)
            (Decode.field "portion_ids" (Decode.list Decode.string))
        )


historyPointDecoder : Decoder HistoryPoint
historyPointDecoder =
    Decode.map4 HistoryPoint
        (Decode.field "date" Decode.string)
        (Decode.field "added" Decode.int)
        (Decode.field "consumed" Decode.int)
        (Decode.field "frozen_total" Decode.int)


portionInBatchDecoder : Decoder PortionInBatch
portionInBatchDecoder =
    Decode.map5 PortionInBatch
        (Decode.field "id" Decode.string)
        (Decode.field "status" Decode.string)
        (Decode.field "created_at" Decode.string)
        (Decode.field "expiry_date" Decode.string)
        (Decode.field "consumed_at" (Decode.nullable Decode.string))


recipeDecoder : Decoder Recipe
recipeDecoder =
    Decode.map4 Recipe
        (Decode.field "name" Decode.string)
        (Decode.field "default_portions" Decode.int)
        (Decode.field "default_container_id" (Decode.nullable Decode.string))
        (Decode.field "ingredients" Decode.string)
