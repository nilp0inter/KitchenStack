module Api.Decoders exposing
    ( batchIngredientDecoder
    , batchSummaryDecoder
    , containerTypeDecoder
    , createBatchResponseDecoder
    , historyPointDecoder
    , ingredientDecoder
    , labelPresetDecoder
    , portionDetailDecoder
    , portionInBatchDecoder
    , recipeDecoder
    , updateBatchResponseDecoder
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
        |> andMap (Decode.field "label_preset" (Decode.nullable Decode.string))
        |> andMap (Decode.field "batch_created_at" Decode.string)
        |> andMap (Decode.field "expiry_date" (Decode.nullable Decode.string))
        |> andMap (Decode.field "frozen_count" Decode.int)
        |> andMap (Decode.field "consumed_count" Decode.int)
        |> andMap (Decode.field "discarded_count" Decode.int)
        |> andMap (Decode.field "total_count" Decode.int)
        |> andMap (Decode.field "ingredients" Decode.string)
        |> andMap (Decode.field "details" (Decode.nullable Decode.string))
        |> andMap (Decode.field "image" (Decode.nullable Decode.string))


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
        |> andMap (Decode.field "details" (Decode.nullable Decode.string))
        |> andMap (Decode.field "image" (Decode.nullable Decode.string))


createBatchResponseDecoder : Decoder CreateBatchResponse
createBatchResponseDecoder =
    Decode.index 0
        (Decode.succeed CreateBatchResponse
            |> andMap (Decode.field "batch_id" Decode.string)
            |> andMap (Decode.field "portion_ids" (Decode.list Decode.string))
            |> andMap (Decode.field "expiry_date" Decode.string)
            |> andMap (Decode.field "best_before_date" (Decode.nullable Decode.string))
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
    Decode.succeed PortionInBatch
        |> andMap (Decode.field "id" Decode.string)
        |> andMap (Decode.field "status" Decode.string)
        |> andMap (Decode.field "created_at" Decode.string)
        |> andMap (Decode.field "expiry_date" Decode.string)
        |> andMap (Decode.field "consumed_at" (Decode.nullable Decode.string))
        |> andMap (Decode.field "discarded_at" (Decode.nullable Decode.string))


recipeDecoder : Decoder Recipe
recipeDecoder =
    Decode.succeed Recipe
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "default_portions" Decode.int)
        |> andMap (Decode.field "default_container_id" (Decode.nullable Decode.string))
        |> andMap (Decode.field "default_label_preset" (Decode.nullable Decode.string))
        |> andMap (Decode.field "ingredients" Decode.string)
        |> andMap (Decode.field "details" (Decode.nullable Decode.string))
        |> andMap (Decode.field "image" (Decode.nullable Decode.string))


updateBatchResponseDecoder : Decoder UpdateBatchResponse
updateBatchResponseDecoder =
    Decode.index 0
        (Decode.succeed UpdateBatchResponse
            |> andMap (Decode.field "new_portion_ids" (Decode.list Decode.string))
            |> andMap (Decode.field "new_expiry_date" (Decode.nullable Decode.string))
            |> andMap (Decode.field "best_before_date" (Decode.nullable Decode.string))
        )


batchIngredientDecoder : Decoder BatchIngredient
batchIngredientDecoder =
    Decode.map2 BatchIngredient
        (Decode.field "batch_id" Decode.string)
        (Decode.field "ingredient_name" Decode.string)


labelPresetDecoder : Decoder LabelPreset
labelPresetDecoder =
    Decode.succeed LabelPreset
        |> andMap (Decode.field "name" Decode.string)
        |> andMap (Decode.field "label_type" Decode.string)
        |> andMap (Decode.field "width" Decode.int)
        |> andMap (Decode.field "height" Decode.int)
        |> andMap (Decode.field "qr_size" Decode.int)
        |> andMap (Decode.field "padding" Decode.int)
        |> andMap (Decode.field "title_font_size" Decode.int)
        |> andMap (Decode.field "date_font_size" Decode.int)
        |> andMap (Decode.field "small_font_size" Decode.int)
        |> andMap (Decode.field "font_family" Decode.string)
        |> andMap (Decode.field "show_title" Decode.bool)
        |> andMap (Decode.field "show_ingredients" Decode.bool)
        |> andMap (Decode.field "show_expiry_date" Decode.bool)
        |> andMap (Decode.field "show_best_before" Decode.bool)
        |> andMap (Decode.field "show_qr" Decode.bool)
        |> andMap (Decode.field "show_branding" Decode.bool)
        |> andMap (Decode.field "vertical_spacing" Decode.int)
        |> andMap (Decode.field "show_separator" Decode.bool)
        |> andMap (Decode.field "separator_thickness" Decode.int)
        |> andMap (Decode.field "separator_color" Decode.string)
        |> andMap (Decode.field "corner_radius" Decode.int)
        |> andMap (Decode.field "title_min_font_size" Decode.int)
        |> andMap (Decode.field "ingredients_max_chars" Decode.int)
        |> andMap (Decode.field "rotate" Decode.bool)
