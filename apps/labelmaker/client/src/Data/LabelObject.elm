module Data.LabelObject exposing
    ( Color
    , HAlign(..)
    , LabelObject(..)
    , ObjectId
    , ShapeProperties
    , ShapeType(..)
    , SlotPosition(..)
    , TextProperties
    , VAlign(..)
    , addObjectTo
    , addObjectToSlot
    , allContainerIds
    , allSlotTargets
    , allTextObjectIds
    , allVariableNames
    , defaultColor
    , defaultTextProperties
    , findObject
    , insertAtTarget
    , isDescendantOf
    , newContainer
    , newHSplit
    , newImage
    , newShape
    , newText
    , newVSplit
    , newVariable
    , objectId
    , removeAndReturn
    , removeObjectFromTree
    , updateObjectInTree
    )


import Set


type alias ObjectId =
    String


type alias Color =
    { r : Int, g : Int, b : Int, a : Float }


type HAlign
    = AlignLeft
    | AlignCenter
    | AlignRight


type VAlign
    = AlignTop
    | AlignMiddle
    | AlignBottom


type SlotPosition
    = TopSlot
    | BottomSlot
    | LeftSlot
    | RightSlot


type alias TextProperties =
    { fontSize : Float
    , fontFamily : String
    , color : Color
    , hAlign : HAlign
    , vAlign : VAlign
    , fontWeight : String
    , lineHeight : Float
    }


type ShapeType
    = Rectangle
    | Circle
    | Line


type alias ShapeProperties =
    { shapeType : ShapeType
    , color : Color
    }


type LabelObject
    = Container { id : ObjectId, name : String, x : Float, y : Float, width : Float, height : Float, content : List LabelObject }
    | VSplit { id : ObjectId, name : String, split : Float, top : Maybe LabelObject, bottom : Maybe LabelObject }
    | HSplit { id : ObjectId, name : String, split : Float, left : Maybe LabelObject, right : Maybe LabelObject }
    | TextObj { id : ObjectId, content : String, properties : TextProperties }
    | VariableObj { id : ObjectId, name : String, properties : TextProperties }
    | ImageObj { id : ObjectId, url : String }
    | ShapeObj { id : ObjectId, properties : ShapeProperties }



-- Accessors


objectId : LabelObject -> ObjectId
objectId obj =
    case obj of
        Container r ->
            r.id

        VSplit r ->
            r.id

        HSplit r ->
            r.id

        TextObj r ->
            r.id

        VariableObj r ->
            r.id

        ImageObj r ->
            r.id

        ShapeObj r ->
            r.id



-- Defaults


defaultColor : Color
defaultColor =
    { r = 0, g = 0, b = 0, a = 1.0 }


defaultTextProperties : TextProperties
defaultTextProperties =
    { fontSize = 48
    , fontFamily = "Atkinson Hyperlegible"
    , color = defaultColor
    , hAlign = AlignCenter
    , vAlign = AlignMiddle
    , fontWeight = "normal"
    , lineHeight = 1.0
    }



-- Helpers


maybeToList : Maybe LabelObject -> List LabelObject
maybeToList m =
    case m of
        Just obj ->
            [ obj ]

        Nothing ->
            []


slotChildren : Maybe LabelObject -> Maybe LabelObject -> List LabelObject
slotChildren a b =
    maybeToList a ++ maybeToList b



-- Constructors


newText : Int -> LabelObject
newText nextId =
    TextObj
        { id = "obj-" ++ String.fromInt nextId
        , content = "Texto"
        , properties = defaultTextProperties
        }


newVariable : Int -> LabelObject
newVariable nextId =
    VariableObj
        { id = "obj-" ++ String.fromInt nextId
        , name = "nombre"
        , properties = defaultTextProperties
        }


newContainer : Int -> Float -> Float -> Float -> Float -> LabelObject
newContainer nextId x y w h =
    Container
        { id = "obj-" ++ String.fromInt nextId
        , name = ""
        , x = x
        , y = y
        , width = w
        , height = h
        , content = []
        }


newShape : Int -> ShapeType -> LabelObject
newShape nextId shapeType =
    ShapeObj
        { id = "obj-" ++ String.fromInt nextId
        , properties = { shapeType = shapeType, color = defaultColor }
        }


newVSplit : Int -> LabelObject
newVSplit nextId =
    VSplit
        { id = "obj-" ++ String.fromInt nextId
        , name = ""
        , split = 50
        , top = Nothing
        , bottom = Nothing
        }


newHSplit : Int -> LabelObject
newHSplit nextId =
    HSplit
        { id = "obj-" ++ String.fromInt nextId
        , name = ""
        , split = 50
        , left = Nothing
        , right = Nothing
        }


newImage : Int -> LabelObject
newImage nextId =
    ImageObj
        { id = "obj-" ++ String.fromInt nextId
        , url = ""
        }



-- Tree operations


findObject : ObjectId -> List LabelObject -> Maybe LabelObject
findObject targetId objects =
    case objects of
        [] ->
            Nothing

        obj :: rest ->
            if objectId obj == targetId then
                Just obj

            else
                case obj of
                    Container r ->
                        case findObject targetId r.content of
                            Just found ->
                                Just found

                            Nothing ->
                                findObject targetId rest

                    VSplit r ->
                        case findObject targetId (slotChildren r.top r.bottom) of
                            Just found ->
                                Just found

                            Nothing ->
                                findObject targetId rest

                    HSplit r ->
                        case findObject targetId (slotChildren r.left r.right) of
                            Just found ->
                                Just found

                            Nothing ->
                                findObject targetId rest

                    _ ->
                        findObject targetId rest


updateObjectInTree : ObjectId -> (LabelObject -> LabelObject) -> List LabelObject -> List LabelObject
updateObjectInTree targetId fn objects =
    List.map
        (\obj ->
            if objectId obj == targetId then
                fn obj

            else
                case obj of
                    Container r ->
                        Container { r | content = updateObjectInTree targetId fn r.content }

                    VSplit r ->
                        VSplit
                            { r
                                | top = Maybe.map (updateSingleObject targetId fn) r.top
                                , bottom = Maybe.map (updateSingleObject targetId fn) r.bottom
                            }

                    HSplit r ->
                        HSplit
                            { r
                                | left = Maybe.map (updateSingleObject targetId fn) r.left
                                , right = Maybe.map (updateSingleObject targetId fn) r.right
                            }

                    _ ->
                        obj
        )
        objects


updateSingleObject : ObjectId -> (LabelObject -> LabelObject) -> LabelObject -> LabelObject
updateSingleObject targetId fn obj =
    if objectId obj == targetId then
        fn obj

    else
        case obj of
            Container r ->
                Container { r | content = updateObjectInTree targetId fn r.content }

            VSplit r ->
                VSplit
                    { r
                        | top = Maybe.map (updateSingleObject targetId fn) r.top
                        , bottom = Maybe.map (updateSingleObject targetId fn) r.bottom
                    }

            HSplit r ->
                HSplit
                    { r
                        | left = Maybe.map (updateSingleObject targetId fn) r.left
                        , right = Maybe.map (updateSingleObject targetId fn) r.right
                    }

            _ ->
                obj


removeObjectFromTree : ObjectId -> List LabelObject -> List LabelObject
removeObjectFromTree targetId objects =
    List.filterMap
        (\obj ->
            if objectId obj == targetId then
                Nothing

            else
                case obj of
                    Container r ->
                        Just (Container { r | content = removeObjectFromTree targetId r.content })

                    VSplit r ->
                        Just
                            (VSplit
                                { r
                                    | top = removeFromSlot targetId r.top
                                    , bottom = removeFromSlot targetId r.bottom
                                }
                            )

                    HSplit r ->
                        Just
                            (HSplit
                                { r
                                    | left = removeFromSlot targetId r.left
                                    , right = removeFromSlot targetId r.right
                                }
                            )

                    _ ->
                        Just obj
        )
        objects


removeFromSlot : ObjectId -> Maybe LabelObject -> Maybe LabelObject
removeFromSlot targetId slot =
    case slot of
        Nothing ->
            Nothing

        Just obj ->
            if objectId obj == targetId then
                Nothing

            else
                Just (removeFromSingleObject targetId obj)


removeFromSingleObject : ObjectId -> LabelObject -> LabelObject
removeFromSingleObject targetId obj =
    case obj of
        Container r ->
            Container { r | content = removeObjectFromTree targetId r.content }

        VSplit r ->
            VSplit
                { r
                    | top = removeFromSlot targetId r.top
                    , bottom = removeFromSlot targetId r.bottom
                }

        HSplit r ->
            HSplit
                { r
                    | left = removeFromSlot targetId r.left
                    , right = removeFromSlot targetId r.right
                }

        _ ->
            obj


addObjectTo : Maybe ObjectId -> LabelObject -> List LabelObject -> List LabelObject
addObjectTo maybeParentId newObj objects =
    case maybeParentId of
        Nothing ->
            objects ++ [ newObj ]

        Just parentId ->
            List.map
                (\obj ->
                    case obj of
                        Container r ->
                            if r.id == parentId then
                                Container { r | content = r.content ++ [ newObj ] }

                            else
                                Container { r | content = addObjectTo (Just parentId) newObj r.content }

                        VSplit r ->
                            VSplit
                                { r
                                    | top = Maybe.map (addToSingleObject parentId newObj) r.top
                                    , bottom = Maybe.map (addToSingleObject parentId newObj) r.bottom
                                }

                        HSplit r ->
                            HSplit
                                { r
                                    | left = Maybe.map (addToSingleObject parentId newObj) r.left
                                    , right = Maybe.map (addToSingleObject parentId newObj) r.right
                                }

                        _ ->
                            obj
                )
                objects


addToSingleObject : ObjectId -> LabelObject -> LabelObject -> LabelObject
addToSingleObject parentId newObj obj =
    case obj of
        Container r ->
            if r.id == parentId then
                Container { r | content = r.content ++ [ newObj ] }

            else
                Container { r | content = addObjectTo (Just parentId) newObj r.content }

        VSplit r ->
            VSplit
                { r
                    | top = Maybe.map (addToSingleObject parentId newObj) r.top
                    , bottom = Maybe.map (addToSingleObject parentId newObj) r.bottom
                }

        HSplit r ->
            HSplit
                { r
                    | left = Maybe.map (addToSingleObject parentId newObj) r.left
                    , right = Maybe.map (addToSingleObject parentId newObj) r.right
                }

        _ ->
            obj


allVariableNames : List LabelObject -> List String
allVariableNames objects =
    let
        collect objs =
            List.concatMap
                (\obj ->
                    case obj of
                        VariableObj r ->
                            [ r.name ]

                        Container r ->
                            collect r.content

                        VSplit r ->
                            collect (slotChildren r.top r.bottom)

                        HSplit r ->
                            collect (slotChildren r.left r.right)

                        _ ->
                            []
                )
                objs
    in
    collect objects
        |> List.foldl
            (\name ( seen, acc ) ->
                if Set.member name seen then
                    ( seen, acc )

                else
                    ( Set.insert name seen, acc ++ [ name ] )
            )
            ( Set.empty, [] )
        |> Tuple.second


allTextObjectIds : List LabelObject -> List ObjectId
allTextObjectIds objects =
    List.concatMap
        (\obj ->
            case obj of
                TextObj r ->
                    [ r.id ]

                VariableObj r ->
                    [ r.id ]

                Container r ->
                    allTextObjectIds r.content

                VSplit r ->
                    allTextObjectIds (slotChildren r.top r.bottom)

                HSplit r ->
                    allTextObjectIds (slotChildren r.left r.right)

                _ ->
                    []
        )
        objects


removeAndReturn : ObjectId -> List LabelObject -> ( Maybe LabelObject, List LabelObject )
removeAndReturn targetId objects =
    let
        go objs =
            case objs of
                [] ->
                    ( Nothing, [] )

                obj :: rest ->
                    if objectId obj == targetId then
                        ( Just obj, rest )

                    else
                        case obj of
                            Container r ->
                                let
                                    ( found, newContent ) =
                                        go r.content
                                in
                                case found of
                                    Just _ ->
                                        ( found, Container { r | content = newContent } :: rest )

                                    Nothing ->
                                        let
                                            ( foundInRest, restResult ) =
                                                go rest
                                        in
                                        ( foundInRest, obj :: restResult )

                            VSplit r ->
                                let
                                    ( foundTop, newTop ) =
                                        removeAndReturnFromSlot targetId r.top

                                    ( foundBottom, newBottom ) =
                                        removeAndReturnFromSlot targetId r.bottom
                                in
                                case ( foundTop, foundBottom ) of
                                    ( Just _, _ ) ->
                                        ( foundTop, VSplit { r | top = newTop, bottom = newBottom } :: rest )

                                    ( _, Just _ ) ->
                                        ( foundBottom, VSplit { r | top = newTop, bottom = newBottom } :: rest )

                                    _ ->
                                        let
                                            ( foundInRest, restResult ) =
                                                go rest
                                        in
                                        ( foundInRest, obj :: restResult )

                            HSplit r ->
                                let
                                    ( foundLeft, newLeft ) =
                                        removeAndReturnFromSlot targetId r.left

                                    ( foundRight, newRight ) =
                                        removeAndReturnFromSlot targetId r.right
                                in
                                case ( foundLeft, foundRight ) of
                                    ( Just _, _ ) ->
                                        ( foundLeft, HSplit { r | left = newLeft, right = newRight } :: rest )

                                    ( _, Just _ ) ->
                                        ( foundRight, HSplit { r | left = newLeft, right = newRight } :: rest )

                                    _ ->
                                        let
                                            ( foundInRest, restResult ) =
                                                go rest
                                        in
                                        ( foundInRest, obj :: restResult )

                            _ ->
                                let
                                    ( found, restResult ) =
                                        go rest
                                in
                                ( found, obj :: restResult )
    in
    go objects


removeAndReturnFromSlot : ObjectId -> Maybe LabelObject -> ( Maybe LabelObject, Maybe LabelObject )
removeAndReturnFromSlot targetId slot =
    case slot of
        Nothing ->
            ( Nothing, Nothing )

        Just obj ->
            if objectId obj == targetId then
                ( Just obj, Nothing )

            else
                let
                    ( found, updated ) =
                        removeAndReturnSingle targetId obj
                in
                ( found, Just updated )


removeAndReturnSingle : ObjectId -> LabelObject -> ( Maybe LabelObject, LabelObject )
removeAndReturnSingle targetId obj =
    case obj of
        Container r ->
            let
                ( found, newContent ) =
                    removeAndReturn targetId r.content
            in
            ( found, Container { r | content = newContent } )

        VSplit r ->
            let
                ( foundTop, newTop ) =
                    removeAndReturnFromSlot targetId r.top

                ( foundBottom, newBottom ) =
                    removeAndReturnFromSlot targetId r.bottom
            in
            case foundTop of
                Just _ ->
                    ( foundTop, VSplit { r | top = newTop, bottom = newBottom } )

                Nothing ->
                    ( foundBottom, VSplit { r | top = newTop, bottom = newBottom } )

        HSplit r ->
            let
                ( foundLeft, newLeft ) =
                    removeAndReturnFromSlot targetId r.left

                ( foundRight, newRight ) =
                    removeAndReturnFromSlot targetId r.right
            in
            case foundLeft of
                Just _ ->
                    ( foundLeft, HSplit { r | left = newLeft, right = newRight } )

                Nothing ->
                    ( foundRight, HSplit { r | left = newLeft, right = newRight } )

        _ ->
            ( Nothing, obj )


insertAtTarget : ObjectId -> Bool -> LabelObject -> List LabelObject -> List LabelObject
insertAtTarget targetId isBefore newObj objects =
    List.concatMap
        (\obj ->
            if objectId obj == targetId then
                if isBefore then
                    [ newObj, obj ]

                else
                    [ obj, newObj ]

            else
                case obj of
                    Container r ->
                        [ Container { r | content = insertAtTarget targetId isBefore newObj r.content } ]

                    VSplit r ->
                        [ VSplit
                            { r
                                | top = Maybe.map (insertInSingleObject targetId isBefore newObj) r.top
                                , bottom = Maybe.map (insertInSingleObject targetId isBefore newObj) r.bottom
                            }
                        ]

                    HSplit r ->
                        [ HSplit
                            { r
                                | left = Maybe.map (insertInSingleObject targetId isBefore newObj) r.left
                                , right = Maybe.map (insertInSingleObject targetId isBefore newObj) r.right
                            }
                        ]

                    _ ->
                        [ obj ]
        )
        objects


insertInSingleObject : ObjectId -> Bool -> LabelObject -> LabelObject -> LabelObject
insertInSingleObject targetId isBefore newObj obj =
    case obj of
        Container r ->
            Container { r | content = insertAtTarget targetId isBefore newObj r.content }

        VSplit r ->
            VSplit
                { r
                    | top = Maybe.map (insertInSingleObject targetId isBefore newObj) r.top
                    , bottom = Maybe.map (insertInSingleObject targetId isBefore newObj) r.bottom
                }

        HSplit r ->
            HSplit
                { r
                    | left = Maybe.map (insertInSingleObject targetId isBefore newObj) r.left
                    , right = Maybe.map (insertInSingleObject targetId isBefore newObj) r.right
                }

        _ ->
            obj


isDescendantOf : ObjectId -> ObjectId -> List LabelObject -> Bool
isDescendantOf childId parentId objects =
    case findObject parentId objects of
        Just (Container r) ->
            containsId childId r.content

        Just (VSplit r) ->
            containsId childId (slotChildren r.top r.bottom)

        Just (HSplit r) ->
            containsId childId (slotChildren r.left r.right)

        _ ->
            False


containsId : ObjectId -> List LabelObject -> Bool
containsId targetId objects =
    List.any
        (\obj ->
            if objectId obj == targetId then
                True

            else
                case obj of
                    Container r ->
                        containsId targetId r.content

                    VSplit r ->
                        containsId targetId (slotChildren r.top r.bottom)

                    HSplit r ->
                        containsId targetId (slotChildren r.left r.right)

                    _ ->
                        False
        )
        objects


allContainerIds : List LabelObject -> List ( ObjectId, String )
allContainerIds objects =
    List.concatMap
        (\obj ->
            case obj of
                Container r ->
                    ( r.id
                    , if String.isEmpty r.name then
                        "Contenedor"

                      else
                        r.name
                    )
                        :: allContainerIds r.content

                VSplit r ->
                    allContainerIds (slotChildren r.top r.bottom)

                HSplit r ->
                    allContainerIds (slotChildren r.left r.right)

                _ ->
                    []
        )
        objects


addObjectToSlot : ObjectId -> SlotPosition -> LabelObject -> List LabelObject -> List LabelObject
addObjectToSlot parentId slot newObj objects =
    List.map
        (\obj ->
            case obj of
                VSplit r ->
                    if r.id == parentId then
                        case slot of
                            TopSlot ->
                                VSplit { r | top = Just newObj }

                            BottomSlot ->
                                VSplit { r | bottom = Just newObj }

                            _ ->
                                obj

                    else
                        VSplit
                            { r
                                | top = Maybe.map (addToSlotSingle parentId slot newObj) r.top
                                , bottom = Maybe.map (addToSlotSingle parentId slot newObj) r.bottom
                            }

                HSplit r ->
                    if r.id == parentId then
                        case slot of
                            LeftSlot ->
                                HSplit { r | left = Just newObj }

                            RightSlot ->
                                HSplit { r | right = Just newObj }

                            _ ->
                                obj

                    else
                        HSplit
                            { r
                                | left = Maybe.map (addToSlotSingle parentId slot newObj) r.left
                                , right = Maybe.map (addToSlotSingle parentId slot newObj) r.right
                            }

                Container r ->
                    Container { r | content = addObjectToSlot parentId slot newObj r.content }

                _ ->
                    obj
        )
        objects


addToSlotSingle : ObjectId -> SlotPosition -> LabelObject -> LabelObject -> LabelObject
addToSlotSingle parentId slot newObj obj =
    case obj of
        VSplit r ->
            if r.id == parentId then
                case slot of
                    TopSlot ->
                        VSplit { r | top = Just newObj }

                    BottomSlot ->
                        VSplit { r | bottom = Just newObj }

                    _ ->
                        obj

            else
                VSplit
                    { r
                        | top = Maybe.map (addToSlotSingle parentId slot newObj) r.top
                        , bottom = Maybe.map (addToSlotSingle parentId slot newObj) r.bottom
                    }

        HSplit r ->
            if r.id == parentId then
                case slot of
                    LeftSlot ->
                        HSplit { r | left = Just newObj }

                    RightSlot ->
                        HSplit { r | right = Just newObj }

                    _ ->
                        obj

            else
                HSplit
                    { r
                        | left = Maybe.map (addToSlotSingle parentId slot newObj) r.left
                        , right = Maybe.map (addToSlotSingle parentId slot newObj) r.right
                    }

        Container r ->
            Container { r | content = addObjectToSlot parentId slot newObj r.content }

        _ ->
            obj


allSlotTargets : List LabelObject -> List ( ObjectId, SlotPosition, String )
allSlotTargets objects =
    List.concatMap
        (\obj ->
            case obj of
                VSplit r ->
                    let
                        name =
                            if String.isEmpty r.name then
                                "V-Split"

                            else
                                r.name

                        topTarget =
                            case r.top of
                                Nothing ->
                                    [ ( r.id, TopSlot, name ++ " > Arriba" ) ]

                                Just child ->
                                    allSlotTargetsSingle child

                        bottomTarget =
                            case r.bottom of
                                Nothing ->
                                    [ ( r.id, BottomSlot, name ++ " > Abajo" ) ]

                                Just child ->
                                    allSlotTargetsSingle child
                    in
                    topTarget ++ bottomTarget

                HSplit r ->
                    let
                        name =
                            if String.isEmpty r.name then
                                "H-Split"

                            else
                                r.name

                        leftTarget =
                            case r.left of
                                Nothing ->
                                    [ ( r.id, LeftSlot, name ++ " > Izq." ) ]

                                Just child ->
                                    allSlotTargetsSingle child

                        rightTarget =
                            case r.right of
                                Nothing ->
                                    [ ( r.id, RightSlot, name ++ " > Der." ) ]

                                Just child ->
                                    allSlotTargetsSingle child
                    in
                    leftTarget ++ rightTarget

                Container r ->
                    allSlotTargets r.content

                _ ->
                    []
        )
        objects


allSlotTargetsSingle : LabelObject -> List ( ObjectId, SlotPosition, String )
allSlotTargetsSingle obj =
    case obj of
        VSplit r ->
            let
                name =
                    if String.isEmpty r.name then
                        "V-Split"

                    else
                        r.name

                topTarget =
                    case r.top of
                        Nothing ->
                            [ ( r.id, TopSlot, name ++ " > Arriba" ) ]

                        Just child ->
                            allSlotTargetsSingle child

                bottomTarget =
                    case r.bottom of
                        Nothing ->
                            [ ( r.id, BottomSlot, name ++ " > Abajo" ) ]

                        Just child ->
                            allSlotTargetsSingle child
            in
            topTarget ++ bottomTarget

        HSplit r ->
            let
                name =
                    if String.isEmpty r.name then
                        "H-Split"

                    else
                        r.name

                leftTarget =
                    case r.left of
                        Nothing ->
                            [ ( r.id, LeftSlot, name ++ " > Izq." ) ]

                        Just child ->
                            allSlotTargetsSingle child

                rightTarget =
                    case r.right of
                        Nothing ->
                            [ ( r.id, RightSlot, name ++ " > Der." ) ]

                        Just child ->
                            allSlotTargetsSingle child
            in
            leftTarget ++ rightTarget

        Container r ->
            allSlotTargets r.content

        _ ->
            []
