push!(LOAD_PATH, join([pwd(), "games"], "/"))
push!(LOAD_PATH, join([pwd(), "glog"], "/"))
push!(LOAD_PATH, join([pwd(), "evaluation"], "/"))
push!(LOAD_PATH, join([pwd(), "cards"], "/"))


using game_client
using games

function main()
    println("Starting Heads up game!")
    parsed_args = parse_commandline()

    #start two player game.

    start(
        Val(2),
        parsed_args["server_url"],
        parsed_args["small_blind"],
        parsed_args["big_blind"],
        UInt32(parsed_args["chips"]))

end

main()

