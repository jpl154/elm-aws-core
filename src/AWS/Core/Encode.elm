module AWS.Core.Encode exposing (addListToQueryArgs, addDictToQueryArgs, addOneToQueryArgs, addRecordToQueryArgs, bool, optionalMember, unchangedQueryArgs, uri)

{-| Helper functions for building AWS calls.


# Helpers

@docs addListToQueryArgs, addDictToQueryArgs, addOneToQueryArgs, addRecordToQueryArgs, bool, optionalMember, unchangedQueryArgs, uri

-}

import Char
import Dict exposing (Dict)
import Regex
import Url
import Word.Hex as Hex


{-| We don't use Http.encodeUri because it misses some characters. It uses the
native `encodeURIComponent` under the hood:

    encodeURIComponent escapes all characters except the following:
    alphabetic, decimal digits, - _ . ! ~ * ' ( )

    - from https://developer.mozilla.org/en/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent

For AWS only "Unreserved Characters" are allowed.
See <http://tools.ietf.org/html/rfc3986>
Section 2.3

So basically we need to also cover: ! \* ' ( )

-}
uri : String -> String
uri x =
    x
        |> Url.percentEncode
        |> Regex.replace
            (Regex.fromString "[!*'()]" |> Maybe.withDefault Regex.never)
            (\match ->
                match.match
                    |> String.toList
                    |> List.head
                    |> Maybe.map
                        (\char ->
                            char
                                |> Char.toCode
                                |> Hex.fromByte
                                |> String.toUpper
                                |> (++) "%"
                        )
                    |> Maybe.withDefault ""
            )



-- QUERY ENCODE SIMPLE TYPES


{-| Turn a bool into a stirng.
-}
bool : Bool -> String
bool val =
    if val then
        "true"

    else
        "false"



-- QUERY ENCODE IN A PIPELINE


{-| Identity function
-}
unchangedQueryArgs : List ( String, String ) -> List ( String, String )
unchangedQueryArgs args =
    args


{-| Adds a key value pair to a list.
-}
addOneToQueryArgs : (a -> String) -> String -> a -> List ( String, String ) -> List ( String, String )
addOneToQueryArgs transform key value =
    (::) ( key, transform value )


{-| Adds a list of key/value pairs to another list, optioanlly flattening them.
-}
addListToQueryArgs :
    Bool
    -> (a -> List ( String, String ) -> List ( String, String ))
    -> String
    -> List a
    -> List ( String, String )
    -> List ( String, String )
addListToQueryArgs flattened transform base values =
    values
        |> List.indexedMap
            (\index rawValue ->
                transform rawValue []
                    |> List.map
                        (\( key, value ) ->
                            ( listItemKey flattened index base key
                            , value
                            )
                        )
            )
        |> List.concat
        |> List.append


{-| Adds a dict of key/value pairs to another list.
-}
addDictToQueryArgs : (a -> String) -> String -> Dict String a -> List ( String, String ) -> List ( String, String )
addDictToQueryArgs toStringFn key dict queryArgs =
    Dict.foldl
        (\k v accum -> addOneToQueryArgs toStringFn k v accum)
        queryArgs
        dict


listItemKey : Bool -> Int -> String -> String -> String
listItemKey flattened index base key =
    base
        ++ (if flattened then
                "."

            else
                ".member."
           )
        ++ String.fromInt (index + 1)
        ++ (if String.isEmpty key then
                ""

            else
                "." ++ key
           )


{-| Adds a record of key/value pairs to a list.
-}
addRecordToQueryArgs :
    (record -> List ( String, String ))
    -> String
    -> record
    -> List ( String, String )
    -> List ( String, String )
addRecordToQueryArgs transform base record =
    let
        prefix =
            if String.isEmpty base then
                ""

            else
                base ++ "."
    in
    record
        |> transform
        |> List.map
            (\( key, value ) ->
                ( prefix ++ key
                , value
                )
            )
        |> List.append


{-| Adds an optional key/value pair to a list.
-}
optionalMember :
    (a -> b)
    -> ( String, Maybe a )
    -> List ( String, b )
    -> List ( String, b )
optionalMember encode ( key, maybeValue ) members =
    case maybeValue of
        Nothing ->
            members

        Just value ->
            ( key, encode value ) :: members
