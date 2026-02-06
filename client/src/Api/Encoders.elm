module Api.Encoders exposing
    ( encodeBatchRequest
    , encodeConsumeRequest
    , encodeContainerType
    , encodePrintRequest
    , encodeReturnToFreezerRequest
    )

import Json.Encode as Encode
import Types exposing (..)
import UUID exposing (UUID)


encodeBatchRequest : BatchForm -> UUID -> List UUID -> Encode.Value
encodeBatchRequest form batchUuid portionUuids =
    Encode.object
        ([ ( "p_batch_id", Encode.string (UUID.toString batchUuid) )
         , ( "p_portion_ids", Encode.list (Encode.string << UUID.toString) portionUuids )
         , ( "p_name", Encode.string form.name )
         , ( "p_category_id", Encode.string form.categoryId )
         , ( "p_container_id", Encode.string form.containerId )
         , ( "p_ingredients", Encode.string form.ingredients )
         , ( "p_created_at", Encode.string form.createdAt )
         ]
            ++ (if form.expiryDate /= "" then
                    [ ( "p_expiry_date", Encode.string form.expiryDate ) ]

                else
                    []
               )
        )


encodePrintRequest : PortionPrintData -> Encode.Value
encodePrintRequest data =
    Encode.object
        [ ( "id", Encode.string data.portionId )
        , ( "name", Encode.string data.name )
        , ( "ingredients", Encode.string data.ingredients )
        , ( "container", Encode.string data.containerId )
        , ( "expiry_date", Encode.string data.expiryDate )
        ]


encodeConsumeRequest : Encode.Value
encodeConsumeRequest =
    Encode.object
        [ ( "status", Encode.string "CONSUMED" )
        , ( "consumed_at", Encode.string "now()" )
        ]


encodeReturnToFreezerRequest : Encode.Value
encodeReturnToFreezerRequest =
    Encode.object
        [ ( "status", Encode.string "FROZEN" )
        , ( "consumed_at", Encode.null )
        ]


encodeContainerType : ContainerTypeForm -> Encode.Value
encodeContainerType form =
    Encode.object
        [ ( "name", Encode.string form.name )
        , ( "servings_per_unit", Encode.float (Maybe.withDefault 1.0 (String.toFloat form.servingsPerUnit)) )
        ]
