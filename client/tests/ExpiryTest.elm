module ExpiryTest exposing (suite)

{-| Tests for Data.Expiry module functions.
-}

import Data.Expiry exposing (addDaysToDate, computeBestBeforeDate, computeExpiryDate)
import Expect
import Test exposing (Test, describe, test)
import Types exposing (Ingredient, SelectedIngredient)



-- Test Helpers


{-| Create an Ingredient with optional expireDays and bestBeforeDays.
-}
ingredient : String -> Maybe Int -> Maybe Int -> Ingredient
ingredient name expireDays bestBeforeDays =
    { name = name, expireDays = expireDays, bestBeforeDays = bestBeforeDays }


{-| Create a SelectedIngredient.
-}
selected : String -> SelectedIngredient
selected name =
    { name = name, isNew = False }



-- Test Suite


suite : Test
suite =
    describe "Data.Expiry"
        [ addDaysToDateTests
        , computeExpiryDateTests
        , computeBestBeforeDateTests
        ]



-- addDaysToDate Tests


addDaysToDateTests : Test
addDaysToDateTests =
    describe "addDaysToDate"
        [ describe "basic arithmetic"
            [ test "adds days within same month" <|
                \_ ->
                    addDaysToDate "2024-01-15" 5
                        |> Expect.equal "2024-01-20"
            , test "zero days returns same date" <|
                \_ ->
                    addDaysToDate "2024-06-15" 0
                        |> Expect.equal "2024-06-15"
            ]
        , describe "month boundaries"
            [ test "Jan 30 + 3 days = Feb 2" <|
                \_ ->
                    addDaysToDate "2024-01-30" 3
                        |> Expect.equal "2024-02-02"
            , test "Feb 27 + 3 days in non-leap year = Mar 2" <|
                \_ ->
                    addDaysToDate "2023-02-27" 3
                        |> Expect.equal "2023-03-02"
            , test "Apr 29 + 3 days = May 2 (30-day month)" <|
                \_ ->
                    addDaysToDate "2024-04-29" 3
                        |> Expect.equal "2024-05-02"
            ]
        , describe "year boundaries"
            [ test "Dec 30 + 3 days = Jan 2 next year" <|
                \_ ->
                    addDaysToDate "2024-12-30" 3
                        |> Expect.equal "2025-01-02"
            , test "Dec 31 + 1 day (NYE) = Jan 1 next year" <|
                \_ ->
                    addDaysToDate "2024-12-31" 1
                        |> Expect.equal "2025-01-01"
            ]
        , describe "leap years"
            [ test "Feb 28 + 1 day in leap year 2024 = Feb 29" <|
                \_ ->
                    addDaysToDate "2024-02-28" 1
                        |> Expect.equal "2024-02-29"
            , test "Feb 28 + 1 day in non-leap year 2023 = Mar 1" <|
                \_ ->
                    addDaysToDate "2023-02-28" 1
                        |> Expect.equal "2023-03-01"
            , test "Feb 29 + 1 day in leap year = Mar 1" <|
                \_ ->
                    addDaysToDate "2024-02-29" 1
                        |> Expect.equal "2024-03-01"
            , test "century non-leap year 1900: Feb 28 + 1 = Mar 1" <|
                \_ ->
                    addDaysToDate "1900-02-28" 1
                        |> Expect.equal "1900-03-01"
            , test "century leap year 2000: Feb 28 + 1 = Feb 29" <|
                \_ ->
                    addDaysToDate "2000-02-28" 1
                        |> Expect.equal "2000-02-29"
            ]
        , describe "large additions"
            [ test "90 days from Jan 1" <|
                \_ ->
                    addDaysToDate "2024-01-01" 90
                        |> Expect.equal "2024-03-31"
            , test "180 days from Jan 1 (leap year)" <|
                \_ ->
                    addDaysToDate "2024-01-01" 180
                        |> Expect.equal "2024-06-29"
            , test "365 days from Jan 1, 2024" <|
                \_ ->
                    addDaysToDate "2024-01-01" 365
                        |> Expect.equal "2024-12-31"
            , test "366 days from Jan 1, 2024 (leap year)" <|
                \_ ->
                    addDaysToDate "2024-01-01" 366
                        |> Expect.equal "2025-01-01"
            ]
        , describe "invalid input"
            [ test "malformed date returns original" <|
                \_ ->
                    addDaysToDate "not-a-date" 5
                        |> Expect.equal "not-a-date"
            ]
        ]



-- computeExpiryDate Tests


computeExpiryDateTests : Test
computeExpiryDateTests =
    describe "computeExpiryDate"
        [ describe "manual expiry override"
            [ test "uses manual expiry when provided" <|
                \_ ->
                    computeExpiryDate "2024-01-01" "2024-06-01" [] []
                        |> Expect.equal "2024-06-01"
            , test "manual expiry takes precedence over ingredients" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        "2024-06-01"
                        [ selected "Pollo" ]
                        [ ingredient "Pollo" (Just 30) Nothing ]
                        |> Expect.equal "2024-06-01"
            ]
        , describe "single ingredient"
            [ test "calculates from single ingredient expire_days" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Pollo" ]
                        [ ingredient "Pollo" (Just 30) Nothing ]
                        |> Expect.equal "2024-01-31"
            ]
        , describe "multiple ingredients"
            [ test "uses minimum expire_days among ingredients" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Pollo", selected "Arroz" ]
                        [ ingredient "Pollo" (Just 30) Nothing
                        , ingredient "Arroz" (Just 90) Nothing
                        ]
                        |> Expect.equal "2024-01-31"
            , test "minimum from three ingredients" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Pollo", selected "Arroz", selected "Verduras" ]
                        [ ingredient "Pollo" (Just 60) Nothing
                        , ingredient "Arroz" (Just 90) Nothing
                        , ingredient "Verduras" (Just 30) Nothing
                        ]
                        |> Expect.equal "2024-01-31"
            ]
        , describe "case insensitivity"
            [ test "matches ingredient names case-insensitively" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "pollo" ]
                        [ ingredient "Pollo" (Just 30) Nothing ]
                        |> Expect.equal "2024-01-31"
            , test "matches UPPERCASE to lowercase" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "ARROZ" ]
                        [ ingredient "arroz" (Just 45) Nothing ]
                        |> Expect.equal "2024-02-15"
            ]
        , describe "fallback to createdAt"
            [ test "no matching ingredient returns createdAt" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Unknown" ]
                        [ ingredient "Pollo" (Just 30) Nothing ]
                        |> Expect.equal "2024-01-01"
            , test "ingredient without expireDays returns createdAt" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Pollo" ]
                        [ ingredient "Pollo" Nothing Nothing ]
                        |> Expect.equal "2024-01-01"
            , test "empty ingredient list returns createdAt" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Pollo" ]
                        []
                        |> Expect.equal "2024-01-01"
            , test "empty selected ingredients returns createdAt" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        []
                        [ ingredient "Pollo" (Just 30) Nothing ]
                        |> Expect.equal "2024-01-01"
            ]
        , describe "mixed ingredients"
            [ test "ignores ingredients without expireDays" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Pollo", selected "Sal" ]
                        [ ingredient "Pollo" (Just 30) Nothing
                        , ingredient "Sal" Nothing Nothing
                        ]
                        |> Expect.equal "2024-01-31"
            , test "uses the one with expireDays when others don't have it" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Sal", selected "Arroz", selected "Agua" ]
                        [ ingredient "Sal" Nothing Nothing
                        , ingredient "Arroz" (Just 60) Nothing
                        , ingredient "Agua" Nothing Nothing
                        ]
                        |> Expect.equal "2024-03-01"
            ]
        , describe "edge cases"
            [ test "expireDays of 0 gives same date" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Test" ]
                        [ ingredient "Test" (Just 0) Nothing ]
                        |> Expect.equal "2024-01-01"
            , test "empty string manual expiry triggers calculation" <|
                \_ ->
                    computeExpiryDate "2024-01-01"
                        ""
                        [ selected "Pollo" ]
                        [ ingredient "Pollo" (Just 15) Nothing ]
                        |> Expect.equal "2024-01-16"
            ]
        ]



-- computeBestBeforeDate Tests


computeBestBeforeDateTests : Test
computeBestBeforeDateTests =
    describe "computeBestBeforeDate"
        [ describe "basic functionality"
            [ test "returns Just when bestBeforeDays exists" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "Pollo" ]
                        [ ingredient "Pollo" Nothing (Just 14) ]
                        |> Expect.equal (Just "2024-01-15")
            , test "returns Nothing when no bestBeforeDays" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "Pollo" ]
                        [ ingredient "Pollo" (Just 30) Nothing ]
                        |> Expect.equal Nothing
            ]
        , describe "multiple ingredients"
            [ test "uses minimum bestBeforeDays" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "Pollo", selected "Arroz" ]
                        [ ingredient "Pollo" Nothing (Just 14)
                        , ingredient "Arroz" Nothing (Just 30)
                        ]
                        |> Expect.equal (Just "2024-01-15")
            , test "minimum from three ingredients" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "A", selected "B", selected "C" ]
                        [ ingredient "A" Nothing (Just 20)
                        , ingredient "B" Nothing (Just 7)
                        , ingredient "C" Nothing (Just 15)
                        ]
                        |> Expect.equal (Just "2024-01-08")
            ]
        , describe "case insensitivity"
            [ test "matches ingredient names case-insensitively" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "pollo" ]
                        [ ingredient "Pollo" Nothing (Just 14) ]
                        |> Expect.equal (Just "2024-01-15")
            ]
        , describe "independence from expireDays"
            [ test "bestBefore is independent of expireDays" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "Pollo" ]
                        [ ingredient "Pollo" (Just 30) (Just 14) ]
                        |> Expect.equal (Just "2024-01-15")
            , test "returns bestBefore even if expireDays is Nothing" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "Test" ]
                        [ ingredient "Test" Nothing (Just 7) ]
                        |> Expect.equal (Just "2024-01-08")
            ]
        , describe "fallback to Nothing"
            [ test "empty selected ingredients returns Nothing" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        []
                        [ ingredient "Pollo" Nothing (Just 14) ]
                        |> Expect.equal Nothing
            , test "no matching ingredients returns Nothing" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "Unknown" ]
                        [ ingredient "Pollo" Nothing (Just 14) ]
                        |> Expect.equal Nothing
            , test "all ingredients without bestBeforeDays returns Nothing" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "Pollo", selected "Arroz" ]
                        [ ingredient "Pollo" (Just 30) Nothing
                        , ingredient "Arroz" (Just 60) Nothing
                        ]
                        |> Expect.equal Nothing
            ]
        , describe "edge cases"
            [ test "bestBeforeDays of 0 gives same date" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "Test" ]
                        [ ingredient "Test" Nothing (Just 0) ]
                        |> Expect.equal (Just "2024-01-01")
            , test "ignores ingredients without bestBeforeDays in minimum calculation" <|
                \_ ->
                    computeBestBeforeDate "2024-01-01"
                        [ selected "Pollo", selected "Sal" ]
                        [ ingredient "Pollo" Nothing (Just 14)
                        , ingredient "Sal" Nothing Nothing
                        ]
                        |> Expect.equal (Just "2024-01-15")
            ]
        ]
