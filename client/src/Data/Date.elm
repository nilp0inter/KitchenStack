module Data.Date exposing
    ( Date
    , addDays
    , formatDisplay
    , formatShort
    , fromIsoString
    , range
    , toIsoString
    )

{-| Date utilities wrapping elm/time for date-only operations.

All dates are represented as midnight UTC to avoid timezone ambiguity.

-}

import Time exposing (Month(..), Posix, utc)


{-| Opaque date type wrapping Posix (always at midnight UTC).
-}
type Date
    = Date Posix


{-| Milliseconds in a day.
-}
msPerDay : Int
msPerDay =
    86400000


{-| Parse an ISO string "YYYY-MM-DD" to Date.
-}
fromIsoString : String -> Maybe Date
fromIsoString str =
    case String.split "-" (String.left 10 str) of
        [ yearStr, monthStr, dayStr ] ->
            Maybe.map3
                (\year month day ->
                    let
                        -- Days from year 1 to start of given year
                        yearDays =
                            daysBeforeYear year

                        -- Days from Jan 1 to start of given month
                        monthDays =
                            daysBeforeMonth year month

                        -- Total days from Unix epoch (1970-01-01)
                        epochDays =
                            yearDays + monthDays + day - 1 - daysBeforeYear 1970
                    in
                    Date (Time.millisToPosix (epochDays * msPerDay))
                )
                (String.toInt yearStr)
                (String.toInt monthStr)
                (String.toInt dayStr)

        _ ->
            Nothing


{-| Convert Date to ISO string "YYYY-MM-DD".
-}
toIsoString : Date -> String
toIsoString (Date posix) =
    let
        year =
            Time.toYear utc posix

        month =
            monthToInt (Time.toMonth utc posix)

        day =
            Time.toDay utc posix
    in
    String.fromInt year
        ++ "-"
        ++ String.padLeft 2 '0' (String.fromInt month)
        ++ "-"
        ++ String.padLeft 2 '0' (String.fromInt day)


{-| Format as "DD/MM/YYYY" for Spanish display.
-}
formatDisplay : Date -> String
formatDisplay (Date posix) =
    let
        year =
            Time.toYear utc posix

        month =
            monthToInt (Time.toMonth utc posix)

        day =
            Time.toDay utc posix
    in
    String.padLeft 2 '0' (String.fromInt day)
        ++ "/"
        ++ String.padLeft 2 '0' (String.fromInt month)
        ++ "/"
        ++ String.fromInt year


{-| Format as "DD/MM" for chart labels.
-}
formatShort : Date -> String
formatShort (Date posix) =
    let
        month =
            monthToInt (Time.toMonth utc posix)

        day =
            Time.toDay utc posix
    in
    String.padLeft 2 '0' (String.fromInt day)
        ++ "/"
        ++ String.padLeft 2 '0' (String.fromInt month)


{-| Add N days (negative to subtract).
-}
addDays : Int -> Date -> Date
addDays n (Date posix) =
    let
        currentMillis =
            Time.posixToMillis posix
    in
    Date (Time.millisToPosix (currentMillis + n * msPerDay))


{-| Generate an inclusive date range from start to end.
-}
range : Date -> Date -> List Date
range start end =
    rangeHelper start end []


rangeHelper : Date -> Date -> List Date -> List Date
rangeHelper ((Date currentPosix) as current) ((Date endPosix) as end) acc =
    if Time.posixToMillis currentPosix > Time.posixToMillis endPosix then
        List.reverse acc

    else
        rangeHelper (addDays 1 current) end (current :: acc)



-- Helpers


{-| Convert Time.Month to Int (Jan = 1, Dec = 12).
-}
monthToInt : Month -> Int
monthToInt month =
    case month of
        Jan ->
            1

        Feb ->
            2

        Mar ->
            3

        Apr ->
            4

        May ->
            5

        Jun ->
            6

        Jul ->
            7

        Aug ->
            8

        Sep ->
            9

        Oct ->
            10

        Nov ->
            11

        Dec ->
            12


{-| Check if a year is a leap year.
-}
isLeapYear : Int -> Bool
isLeapYear year =
    (modBy 4 year == 0) && (modBy 100 year /= 0 || modBy 400 year == 0)


{-| Days in a month for a given year.
-}
daysInMonth : Int -> Int -> Int
daysInMonth year month =
    case month of
        1 ->
            31

        2 ->
            if isLeapYear year then
                29

            else
                28

        3 ->
            31

        4 ->
            30

        5 ->
            31

        6 ->
            30

        7 ->
            31

        8 ->
            31

        9 ->
            30

        10 ->
            31

        11 ->
            30

        12 ->
            31

        _ ->
            30


{-| Count of days before the start of a year (from year 1).
-}
daysBeforeYear : Int -> Int
daysBeforeYear year =
    let
        y =
            year - 1

        leapYears =
            (y // 4) - (y // 100) + (y // 400)
    in
    365 * y + leapYears


{-| Count of days before a month in a given year.
-}
daysBeforeMonth : Int -> Int -> Int
daysBeforeMonth year month =
    List.range 1 (month - 1)
        |> List.map (daysInMonth year)
        |> List.sum
