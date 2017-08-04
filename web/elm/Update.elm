module Update exposing (..)

import Models exposing (Project, Pipeline, Model, Msg(..))
import Phoenix.Socket
import Phoenix.Channel
import Json.Decode as Decode
import Json.Decode exposing (field, Decoder)
import Json.Decode.Extra exposing ((|:))
import Task
import Date


decodePipeline : Decoder Pipeline
decodePipeline =
    Decode.succeed Pipeline
        |: (field "created_at" Json.Decode.Extra.date)


decodeProject : Decoder Project
decodeProject =
    Decode.succeed Project
        |: (field "name" Decode.string)
        |: (field "image" Decode.string)
        |: (field "status" Decode.string)
        |: (field "duration" Decode.float)
        |: (field "last_commit_author" Decode.string)
        |: (field "last_commit_message" Decode.string)
        |: (field "updated_at" Json.Decode.Extra.date)
        |: (field "pipelines" (Decode.list decodePipeline))


decodeProjects : Decoder (List Project)
decodeProjects =
    field "list" (Decode.list decodeProject)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PhoenixMsg msg ->
            let
                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.update msg model.phxSocket
            in
                { model | phxSocket = phxSocket }
                    ! [ Cmd.map PhoenixMsg phxCmd
                      ]

        ReceiveProjects raw ->
            let
                newModel =
                    case Decode.decodeValue decodeProjects raw of
                        Ok projects ->
                            { model
                                | projects = projects
                                , error = Nothing
                            }

                        Err error ->
                            { model
                                | error = Just error
                            }
            in
                newModel ! [ Task.perform SetUpdated Date.now ]

        SetUpdated newDate ->
            { model | updatedAt = Just newDate } ! []

        Tick newTime ->
            { model | now = newTime } ! []

        JoinChannel ->
            let
                channel =
                    Phoenix.Channel.init "gitlab:lobby"

                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.join channel model.phxSocket
            in
                { model | phxSocket = phxSocket }
                    ! [ Cmd.map PhoenixMsg phxCmd
                      ]
