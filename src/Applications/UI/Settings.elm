module UI.Settings exposing (Dependencies, view)

import Chunky exposing (..)
import Color.Ext as Color
import Conditional exposing (ifThenElse)
import Css
import Css.Media
import Html.Styled as Html exposing (Html, text)
import Html.Styled.Attributes exposing (css, selected, value)
import Html.Styled.Events exposing (onClick)
import Html.Styled.Lazy
import Material.Icons.Action as Icons
import Material.Icons.Communication as Icons
import Settings exposing (Settings)
import String.Ext as String
import Tachyons.Classes as T
import UI.Backdrop as Backdrop
import UI.Css
import UI.Kit
import UI.Navigation exposing (..)
import UI.Page as Page
import UI.Reply exposing (Reply(..))
import UI.Settings.ImportExport
import UI.Settings.Page as Settings exposing (..)
import User.Layer exposing (Method(..))



-- 🗺


type alias Dependencies =
    { authenticationMethod : Maybe User.Layer.Method
    , chosenBackgroundImage : Maybe String
    , hideDuplicateTracks : Bool
    , processAutomatically : Bool
    , rememberProgress : Bool
    }


view : Settings.Page -> Dependencies -> Html Reply
view page deps =
    case page of
        ImportExport ->
            UI.Settings.ImportExport.view deps.authenticationMethod

        Index ->
            UI.Kit.receptacle { scrolling = True } (index deps)



-- INDEX


index : Dependencies -> List (Html Reply)
index deps =
    [ -----------------------------------------
      -- Navigation
      -----------------------------------------
      UI.Navigation.local
        [ ( Icon Icons.import_export
          , Label "Import & Export" Shown
          , NavigateToPage (Page.Settings ImportExport)
          )
        , ( Icon Icons.help_outline
          , Label "Help" Shown
          , OpenLinkInNewPage "about#How"
          )
        , ( Icon Icons.exit_to_app
          , Label "Sign out" Shown
          , PerformMsg SignOut
          )
        ]

    -----------------------------------------
    -- Content
    -----------------------------------------
    , UI.Kit.canister
        [ UI.Kit.h1 "Settings"
        , [ text "Changes are saved automatically."
          , lineBreak
          , text "You're storing the data for this application "
          , case deps.authenticationMethod of
                Just Blockstack ->
                    text "on Blockstack."

                Just (Dropbox _) ->
                    text "on Dropbox."

                Just (Ipfs _) ->
                    text "on IPFS."

                Just Local ->
                    text "in this browser."

                Just (RemoteStorage _) ->
                    text "on a RemoteStorage server."

                Just (Textile _) ->
                    text "on Textile."

                Nothing ->
                    text "on nothing, wtf?"

          -- Change passphrase (if applicable)
          , case deps.authenticationMethod of
                Just Blockstack ->
                    nothing

                Just (Dropbox d) ->
                    changePassphrase (Dropbox d)

                Just (Ipfs i) ->
                    changePassphrase (Ipfs i)

                Just Local ->
                    changePassphrase Local

                Just (RemoteStorage r) ->
                    changePassphrase (RemoteStorage r)

                Just (Textile _) ->
                    nothing

                Nothing ->
                    nothing
          ]
            |> raw
            |> UI.Kit.intro

        -- Clear cache
        --------------
        , chunk
            [ T.flex, T.flex_wrap ]
            [ chunk
                [ T.w_50_ns, T.w_100 ]
                [ label "Downloaded tracks"
                , UI.Kit.buttonWithColor
                    UI.Kit.colorKit.base04
                    UI.Kit.Normal
                    ClearTracksCache
                    (text "Clear cache")
                ]
            , chunk
                [ T.w_50_ns, T.w_100 ]
                [ label "Hide Duplicates"
                , UI.Kit.checkbox
                    { checked = deps.hideDuplicateTracks
                    , toggleMsg = ToggleHideDuplicates
                    }
                ]
            ]

        -- Check it
        -----------
        , chunk
            [ T.flex, T.flex_wrap ]
            [ chunk
                [ T.w_50_ns, T.w_100 ]
                [ label "Process sources automatically"
                , UI.Kit.checkbox
                    { checked = deps.processAutomatically
                    , toggleMsg = ToggleProcessAutomatically
                    }
                ]
            , chunk
                [ T.w_50_ns, T.w_100 ]
                [ label "Remember position on long tracks"
                , UI.Kit.checkbox
                    { checked = deps.rememberProgress
                    , toggleMsg = ToggleRememberProgress
                    }
                ]
            ]

        -- Background image
        -------------------
        , label "Background Image"
        , Html.Styled.Lazy.lazy backgroundImage deps.chosenBackgroundImage
        ]
    ]


label : String -> Html msg
label l =
    chunk
        [ T.mb3, T.mt4 ]
        [ UI.Kit.label [] l ]



-- AUTHENTICATION


changePassphrase : User.Layer.Method -> Html Reply
changePassphrase method =
    inline
        []
        [ lineBreak
        , text "If you want to, you can "
        , UI.Kit.textButton
            { label = "change your passphrase"
            , onClick = ShowUpdateEncryptionKeyScreen method
            }
        , text "."
        ]



-- BACKGROUND IMAGE


backgroundImage : Maybe String -> Html Reply
backgroundImage chosenBackground =
    chunk
        [ T.flex, T.flex_wrap ]
        (List.map
            (\( filename, backdropLabel ) ->
                let
                    isActive =
                        chosenBackground == Just filename
                in
                brick
                    [ css backgroundThumbnailStyles
                    , onClick (ChooseBackdrop filename)
                    ]
                    [ T.overflow_hidden
                    , T.pointer
                    , T.relative
                    ]
                    [ if isActive then
                        brick
                            [ css backgroundThumbnailColorStyles ]
                            [ T.absolute
                            , T.absolute__fill
                            , T.br1
                            , T.mb1
                            , T.mr1
                            , T.z_1
                            ]
                            []

                      else
                        chunk
                            [ T.absolute
                            , T.absolute__fill
                            , T.bg_black_05
                            , T.br1
                            , T.mb1
                            , T.mr1
                            , T.z_1
                            ]
                            []

                    --
                    , brick
                        [ css (backgroundThumbnailInnerStyles filename)
                        , Backdrop.backgroundPositioning filename
                        ]
                        [ T.absolute
                        , T.absolute__fill
                        , T.br1
                        , T.mb1
                        , T.mr1
                        , T.z_2
                        , ifThenElse isActive T.o_20 T.o_100
                        ]
                        []

                    --
                    , if isActive then
                        chunk
                            [ T.absolute
                            , T.absolute__fill
                            , T.f7
                            , T.flex
                            , T.fw7
                            , T.items_center
                            , T.justify_center
                            , T.lh_title
                            , T.mb1
                            , T.mr1
                            , T.ph2
                            , T.tc
                            , T.white
                            , T.z_3
                            ]
                            [ chunk
                                [ T.dn
                                , T.db_ns
                                ]
                                [ text "Selected" ]
                            ]

                      else
                        nothing
                    ]
            )
            Backdrop.options
        )


backgroundThumbnailStyles : List Css.Style
backgroundThumbnailStyles =
    [ Css.height Css.zero
    , Css.paddingTop (Css.pct 19.3083198175)
    , Css.width (Css.pct 33.33333)

    --
    , Css.Media.withMedia
        [ UI.Css.notSmallMediaQuery ]
        [ Css.paddingTop (Css.pct 8.275)
        , Css.width (Css.pct 14.28571)
        ]
    ]


backgroundThumbnailColorStyles : List Css.Style
backgroundThumbnailColorStyles =
    [ Css.backgroundColor (Color.toElmCssColor UI.Kit.colorKit.accent) ]


backgroundThumbnailInnerStyles : String -> List Css.Style
backgroundThumbnailInnerStyles filename =
    [ Css.backgroundImage (Css.url <| "images/Background/Thumbnails/" ++ filename)
    , Css.backgroundSize Css.cover
    ]
