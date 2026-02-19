module Data.LabelObject exposing
    ( Color
    , LabelObject(..)
    , ObjectId
    , ShapeProperties
    , ShapeType(..)
    , TextProperties
    , addObjectTo
    , allTextObjectIds
    , allVariableNames
    , defaultColor
    , defaultTextProperties
    , findObject
    , newContainer
    , newImage
    , newShape
    , newText
    , newVariable
    , objectId
    , removeObjectFromTree
    , updateObjectInTree
    )


import Set


type alias ObjectId =
    String


type alias Color =
    { r : Int, g : Int, b : Int, a : Float }


type alias TextProperties =
    { fontSize : Float
    , fontFamily : String
    , color : Color
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
    = Container { id : ObjectId, x : Float, y : Float, width : Float, height : Float, content : List LabelObject }
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
    }



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

                    _ ->
                        obj
        )
        objects


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

                    _ ->
                        Just obj
        )
        objects


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

                        _ ->
                            obj
                )
                objects


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

                        _ ->
                            []
                )
                objs
    in
    collect objects
        |> Set.fromList
        |> Set.toList


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

                _ ->
                    []
        )
        objects
