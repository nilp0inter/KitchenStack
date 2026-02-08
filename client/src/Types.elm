module Types exposing
    ( BatchDetailData
    , BatchForm
    , BatchSummary
    , ContainerType
    , ContainerTypeForm
    , CreateBatchResponse
    , Flags
    , HistoryPoint
    , Ingredient
    , IngredientForm
    , LabelPreset
    , LabelPresetForm
    , Notification
    , NotificationType(..)
    , PortionDetail
    , PortionInBatch
    , PortionPrintData
    , PrintingProgress
    , Recipe
    , RecipeForm
    , SelectedIngredient
    , emptyBatchForm
    , emptyContainerTypeForm
    , emptyIngredientForm
    , emptyLabelPresetForm
    , emptyRecipeForm
    )


type alias Flags =
    { currentDate : String
    , appHost : String
    }


type alias BatchSummary =
    { batchId : String
    , name : String
    , containerId : String
    , bestBeforeDate : Maybe String
    , labelPreset : Maybe String
    , batchCreatedAt : String
    , expiryDate : String
    , frozenCount : Int
    , consumedCount : Int
    , totalCount : Int
    , ingredients : String
    , details : Maybe String
    }


type alias PortionDetail =
    { portionId : String
    , batchId : String
    , createdAt : String
    , expiryDate : String
    , status : String
    , consumedAt : Maybe String
    , name : String
    , containerId : String
    , bestBeforeDate : Maybe String
    , ingredients : String
    , details : Maybe String
    }


type alias Ingredient =
    { name : String
    , expireDays : Maybe Int
    , bestBeforeDays : Maybe Int
    }


type alias IngredientForm =
    { name : String
    , expireDays : String
    , bestBeforeDays : String
    , editing : Maybe String
    }


type alias SelectedIngredient =
    { name : String
    , isNew : Bool
    }


type alias ContainerType =
    { name : String
    , servingsPerUnit : Float
    }


type alias ContainerTypeForm =
    { name : String
    , servingsPerUnit : String
    , editing : Maybe String
    }


type alias BatchForm =
    { name : String
    , selectedIngredients : List SelectedIngredient
    , ingredientInput : String
    , containerId : String
    , quantity : String
    , createdAt : String
    , expiryDate : String
    , details : String
    }


type alias CreateBatchResponse =
    { batchId : String
    , portionIds : List String
    }


type alias HistoryPoint =
    { date : String
    , added : Int
    , consumed : Int
    , frozenTotal : Int
    }


type alias Notification =
    { id : Int
    , message : String
    , notificationType : NotificationType
    }


type alias PrintingProgress =
    { total : Int
    , completed : Int
    , failed : Int
    }


type alias BatchDetailData =
    { batch : BatchSummary
    , portions : List PortionInBatch
    }


type alias PortionInBatch =
    { portionId : String
    , status : String
    , createdAt : String
    , expiryDate : String
    , consumedAt : Maybe String
    }


type NotificationType
    = Success
    | Error
    | Info


type alias PortionPrintData =
    { portionId : String
    , name : String
    , ingredients : String
    , containerId : String
    , expiryDate : String
    , bestBeforeDate : Maybe String
    }


emptyBatchForm : String -> BatchForm
emptyBatchForm currentDate =
    { name = ""
    , selectedIngredients = []
    , ingredientInput = ""
    , containerId = ""
    , quantity = "1"
    , createdAt = currentDate
    , expiryDate = ""
    , details = ""
    }


emptyContainerTypeForm : ContainerTypeForm
emptyContainerTypeForm =
    { name = ""
    , servingsPerUnit = ""
    , editing = Nothing
    }


emptyIngredientForm : IngredientForm
emptyIngredientForm =
    { name = ""
    , expireDays = ""
    , bestBeforeDays = ""
    , editing = Nothing
    }


type alias Recipe =
    { name : String
    , defaultPortions : Int
    , defaultContainerId : Maybe String
    , defaultLabelPreset : Maybe String
    , ingredients : String
    , details : Maybe String
    }


type alias RecipeForm =
    { name : String
    , selectedIngredients : List SelectedIngredient
    , ingredientInput : String
    , defaultPortions : String
    , defaultContainerId : String
    , defaultLabelPreset : String
    , editing : Maybe String
    , details : String
    }


emptyRecipeForm : RecipeForm
emptyRecipeForm =
    { name = ""
    , selectedIngredients = []
    , ingredientInput = ""
    , defaultPortions = "1"
    , defaultContainerId = ""
    , defaultLabelPreset = ""
    , editing = Nothing
    , details = ""
    }


type alias LabelPreset =
    { name : String
    , labelType : String
    , width : Int
    , height : Int
    , qrSize : Int
    , padding : Int
    , titleFontSize : Int
    , dateFontSize : Int
    , smallFontSize : Int
    , fontFamily : String
    , showTitle : Bool
    , showIngredients : Bool
    , showExpiryDate : Bool
    , showBestBefore : Bool
    , showQr : Bool
    , showBranding : Bool
    , verticalSpacing : Int
    , showSeparator : Bool
    , separatorThickness : Int
    , separatorColor : String
    , cornerRadius : Int
    , titleMinFontSize : Int
    , ingredientsMaxChars : Int
    , rotate : Bool
    }


type alias LabelPresetForm =
    { name : String
    , labelType : String
    , width : String
    , height : String
    , qrSize : String
    , padding : String
    , titleFontSize : String
    , dateFontSize : String
    , smallFontSize : String
    , fontFamily : String
    , showTitle : Bool
    , showIngredients : Bool
    , showExpiryDate : Bool
    , showBestBefore : Bool
    , showQr : Bool
    , showBranding : Bool
    , verticalSpacing : String
    , showSeparator : Bool
    , separatorThickness : String
    , separatorColor : String
    , cornerRadius : String
    , titleMinFontSize : String
    , ingredientsMaxChars : String
    , rotate : Bool
    , editing : Maybe String
    }


emptyLabelPresetForm : LabelPresetForm
emptyLabelPresetForm =
    { name = ""
    , labelType = "29"
    , width = "306"
    , height = "200"
    , qrSize = "215"
    , padding = "10"
    , titleFontSize = "30"
    , dateFontSize = "18"
    , smallFontSize = "12"
    , fontFamily = "Atkinson Hyperlegible, sans-serif"
    , showTitle = True
    , showIngredients = True
    , showExpiryDate = True
    , showBestBefore = False
    , showQr = True
    , showBranding = True
    , verticalSpacing = "8"
    , showSeparator = True
    , separatorThickness = "1"
    , separatorColor = "#cccccc"
    , cornerRadius = "0"
    , titleMinFontSize = "26"
    , ingredientsMaxChars = "80"
    , rotate = False
    , editing = Nothing
    }
