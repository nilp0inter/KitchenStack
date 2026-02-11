module Data.Expiry exposing
    ( addDaysToDate
    , computeBestBeforeDate
    , computeExpiryDate
    )

{-| Functions for computing expiry and best-before dates from ingredients.
-}

import Date
import Types exposing (Ingredient, SelectedIngredient)


{-| Compute expiry date from created date and ingredients.
If manual expiry is provided, use that. Otherwise compute from min(expire_days).
-}
computeExpiryDate : String -> String -> List SelectedIngredient -> List Ingredient -> String
computeExpiryDate createdAt manualExpiry selectedIngredients allIngredients =
    if manualExpiry /= "" then
        manualExpiry

    else
        let
            minDays =
                selectedIngredients
                    |> List.filterMap
                        (\sel ->
                            allIngredients
                                |> List.filter (\i -> String.toLower i.name == String.toLower sel.name)
                                |> List.head
                                |> Maybe.andThen .expireDays
                        )
                    |> List.minimum
        in
        case minDays of
            Just days ->
                addDaysToDate createdAt days

            Nothing ->
                -- This shouldn't happen - validation should catch it
                createdAt


{-| Compute best before date from created date and ingredients.
Returns Nothing if no ingredient has best_before_days.
-}
computeBestBeforeDate : String -> List SelectedIngredient -> List Ingredient -> Maybe String
computeBestBeforeDate createdAt selectedIngredients allIngredients =
    let
        minDays =
            selectedIngredients
                |> List.filterMap
                    (\sel ->
                        allIngredients
                            |> List.filter (\i -> String.toLower i.name == String.toLower sel.name)
                            |> List.head
                            |> Maybe.andThen .bestBeforeDays
                    )
                |> List.minimum
    in
    case minDays of
        Just days ->
            Just (addDaysToDate createdAt days)

        Nothing ->
            Nothing


{-| Add days to an ISO date string (YYYY-MM-DD).
Uses justinmimbs/date for proper date arithmetic.
-}
addDaysToDate : String -> Int -> String
addDaysToDate isoDate days =
    case Date.fromIsoString isoDate of
        Ok date ->
            date
                |> Date.add Date.Days days
                |> Date.toIsoString

        Err _ ->
            -- Fallback to original if parsing fails
            isoDate
