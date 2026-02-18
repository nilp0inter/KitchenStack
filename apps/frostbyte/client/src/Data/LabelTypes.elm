module Data.LabelTypes exposing
    ( LabelTypeSpec
    , isEndlessLabel
    , labelTypes
    , silverRatioHeight
    )


{-| Specification for a brother_ql label type.
-}
type alias LabelTypeSpec =
    { id : String
    , description : String
    , width : Int
    , height : Maybe Int -- Nothing for endless (variable height)
    , isEndless : Bool
    , isRound : Bool
    }


{-| All supported brother_ql label types.
-}
labelTypes : List LabelTypeSpec
labelTypes =
    [ -- Endless labels
      { id = "12", description = "12mm endless", width = 106, height = Nothing, isEndless = True, isRound = False }
    , { id = "29", description = "29mm endless", width = 306, height = Nothing, isEndless = True, isRound = False }
    , { id = "38", description = "38mm endless", width = 413, height = Nothing, isEndless = True, isRound = False }
    , { id = "50", description = "50mm endless", width = 554, height = Nothing, isEndless = True, isRound = False }
    , { id = "54", description = "54mm endless", width = 590, height = Nothing, isEndless = True, isRound = False }
    , { id = "62", description = "62mm endless", width = 696, height = Nothing, isEndless = True, isRound = False }
    , { id = "62red", description = "62mm endless (red)", width = 696, height = Nothing, isEndless = True, isRound = False }
    , { id = "102", description = "102mm endless", width = 1164, height = Nothing, isEndless = True, isRound = False }

    -- Die-cut rectangular labels
    , { id = "17x54", description = "17mm x 54mm", width = 165, height = Just 566, isEndless = False, isRound = False }
    , { id = "17x87", description = "17mm x 87mm", width = 165, height = Just 956, isEndless = False, isRound = False }
    , { id = "23x23", description = "23mm x 23mm", width = 202, height = Just 202, isEndless = False, isRound = False }
    , { id = "29x42", description = "29mm x 42mm", width = 306, height = Just 425, isEndless = False, isRound = False }
    , { id = "29x90", description = "29mm x 90mm", width = 306, height = Just 991, isEndless = False, isRound = False }
    , { id = "39x48", description = "39mm x 48mm", width = 425, height = Just 495, isEndless = False, isRound = False }
    , { id = "39x90", description = "38mm x 90mm", width = 413, height = Just 991, isEndless = False, isRound = False }
    , { id = "52x29", description = "52mm x 29mm", width = 578, height = Just 271, isEndless = False, isRound = False }
    , { id = "62x29", description = "62mm x 29mm", width = 696, height = Just 271, isEndless = False, isRound = False }
    , { id = "62x100", description = "62mm x 100mm", width = 696, height = Just 1109, isEndless = False, isRound = False }
    , { id = "102x51", description = "102mm x 51mm", width = 1164, height = Just 526, isEndless = False, isRound = False }
    , { id = "102x152", description = "102mm x 153mm", width = 1164, height = Just 1660, isEndless = False, isRound = False }

    -- Round die-cut labels
    , { id = "d12", description = "12mm round", width = 94, height = Just 94, isEndless = False, isRound = True }
    , { id = "d24", description = "24mm round", width = 236, height = Just 236, isEndless = False, isRound = True }
    , { id = "d58", description = "58mm round", width = 618, height = Just 618, isEndless = False, isRound = True }
    ]


{-| Check if a label type is endless (variable height).
-}
isEndlessLabel : String -> Bool
isEndlessLabel labelTypeId =
    List.any (\spec -> spec.id == labelTypeId && spec.isEndless) labelTypes


{-| Calculate silver ratio height for endless labels.
-}
silverRatioHeight : Int -> Int
silverRatioHeight width =
    round (toFloat width * 2.414)
