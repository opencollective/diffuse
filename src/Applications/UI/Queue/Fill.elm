module UI.Queue.Fill exposing (cleanAutoGenerated, ordered, shuffled)

{-| These functions will return a new list for the `future` property.
-}

import List.Extra as List
import Maybe.Ext as Maybe
import Maybe.Extra as Maybe
import Queue exposing (Item)
import Random exposing (Generator, Seed)
import Time
import Tracks exposing (IdentifiedTrack)
import UI.Queue.Common exposing (makeItem)
import UI.Queue.Core exposing (Model)



-- 🔱


cleanAutoGenerated : Bool -> String -> List Item -> List Item
cleanAutoGenerated shuffle trackId future =
    case shuffle of
        True ->
            List.filterNot
                (\i -> i.manualEntry == False && itemTrackId i == trackId)
                future

        False ->
            future



-- 🔱  ░░  ORDERED


ordered : Time.Posix -> List IdentifiedTrack -> Model -> List Item
ordered _ rawTracks model =
    let
        tracks =
            purifyTracksList model.ignored rawTracks

        manualEntries =
            List.filter (.manualEntry >> (==) True) model.future

        remaining =
            max (queueLength - List.length manualEntries) 0

        focus =
            Maybe.preferFirst (List.last manualEntries) model.activeItem
    in
    case focus of
        Just item ->
            tracks
                |> List.findIndex (indexFinder item.identifiedTrack)
                |> Maybe.map (\idx -> List.drop (idx + 1) tracks)
                |> Maybe.withDefault tracks
                |> List.take remaining
                |> (\a ->
                        let
                            actualRemaining =
                                remaining - List.length a

                            n =
                                tracks
                                    |> List.findIndex (indexFinder item.identifiedTrack)
                                    |> Maybe.withDefault (List.length tracks)
                        in
                        a ++ List.take (min n actualRemaining) tracks
                   )
                |> List.map (makeItem False)
                |> List.append manualEntries

        Nothing ->
            tracks
                |> List.take remaining
                |> List.map (makeItem False)
                |> List.append manualEntries



-- 🔱  ░░  SHUFFLED


shuffled : Time.Posix -> List IdentifiedTrack -> Model -> List Item
shuffled timestamp rawTracks model =
    let
        tracks =
            purifyTracksList model.ignored rawTracks

        amountOfTracks =
            List.length tracks

        generator =
            Random.int 0 (amountOfTracks - 1)

        ( pastIds, futureIds, activeId ) =
            ( List.map itemTrackId model.past
            , List.map itemTrackId model.future
            , Maybe.map itemTrackId model.activeItem
            )

        usedIndexes =
            collectIndexes
                tracks
                [ \( _, t ) -> List.member t.id pastIds
                , \( _, t ) -> List.member t.id futureIds
                , \( _, t ) -> Just t.id == activeId
                ]

        usedIndexes_ =
            let
                isUsedUp =
                    List.length usedIndexes >= amountOfTracks

                hasNoFuture =
                    List.isEmpty model.future
            in
            if isUsedUp && hasNoFuture && amountOfTracks > 1 then
                case amountOfTracks > 1 of
                    True ->
                        collectIndexes tracks [ \( _, t ) -> Just t.id == activeId ]

                    False ->
                        []

            else
                usedIndexes

        ( toAmount, maxAmount ) =
            ( max (queueLength - List.length model.future) 0
            , max (amountOfTracks - List.length usedIndexes_) 0
            )

        howMany =
            min toAmount maxAmount
    in
    if howMany > 0 then
        timestamp
            |> Time.toMillis Time.utc
            |> Random.initialSeed
            |> generateIndexes generator howMany usedIndexes_ []
            |> List.map (\idx -> List.getAt idx tracks)
            |> Maybe.values
            |> List.map (makeItem False)
            |> List.append model.future

    else
        model.future



-- ㊙️


collectIndexes : List IdentifiedTrack -> List (IdentifiedTrack -> Bool) -> List Int
collectIndexes tracks audits =
    List.indexedFoldl (collector audits) [] tracks


collector : List (IdentifiedTrack -> Bool) -> Int -> IdentifiedTrack -> List Int -> List Int
collector audits idx track acc =
    case List.foldl (auditor track) False audits of
        True ->
            idx :: acc

        False ->
            acc


auditor : IdentifiedTrack -> (IdentifiedTrack -> Bool) -> Bool -> Bool
auditor track audit acc =
    if acc == True then
        acc

    else
        audit track


{-| Generated random indexes.

    `squirrel` = accumulator, ie. collected indexes

-}
generateIndexes : Generator Int -> Int -> List Int -> List Int -> Seed -> List Int
generateIndexes generator howMany usedIndexes squirrel seed =
    let
        ( index, newSeed ) =
            Random.step generator seed

        newSquirrel =
            if List.member index usedIndexes then
                squirrel

            else if List.member index squirrel then
                squirrel

            else
                index :: squirrel
    in
    if List.length newSquirrel < howMany then
        generateIndexes generator howMany usedIndexes newSquirrel newSeed

    else
        newSquirrel



-- PURIFY


purifyTracksList : List Item -> List IdentifiedTrack -> List IdentifiedTrack
purifyTracksList ignored tracks =
    let
        ignoredTrackIds =
            List.map itemTrackId ignored
    in
    tracks
        |> List.foldr purifyTracksListReducer ( [], ignoredTrackIds )
        |> Tuple.first


purifyTracksListReducer :
    IdentifiedTrack
    -> ( List IdentifiedTrack, List String )
    -> ( List IdentifiedTrack, List String )
purifyTracksListReducer identifiedTrack ( collection, ignored ) =
    let
        trackId =
            (Tuple.second >> .id) identifiedTrack
    in
    case List.findIndex ((==) trackId) ignored of
        Just idx ->
            ( collection, List.removeAt idx ignored )

        Nothing ->
            ( identifiedTrack :: collection, ignored )



-- COMMON


indexFinder : IdentifiedTrack -> IdentifiedTrack -> Bool
indexFinder =
    Tracks.isNowPlaying


itemTrackId : Item -> String
itemTrackId =
    .identifiedTrack >> Tuple.second >> .id



-- CONSTANTS


queueLength : Int
queueLength =
    30
