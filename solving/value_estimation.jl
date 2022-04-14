module value_estimation

# export estimatevalue

# using StaticArrays

# using infosets
# using games
# using solving

# @inline function estimatevalue(
#     ::Type{T},
#     h::H,
#     gs::G,
#     pl::I) where {A, P, T<:AbstractFloat, I<:Integer, H<:History, G<:AbstractGameState{A, DepthLimited, P}}


#     stp = setup(gs)

#     # todo: randomly select a bias in the depth limited
#     bias = selectrandom(stp.biases)

#     vals = @SVector zeros(T, P)

#     # run a simulation for a certain amount of iterations to get an approximation
#     # of the value a depth limited game.

#     for _ in 1:stp.iterations
#         vals += simulate(h, gs, pl, bias)
#     end

#     return vals/stp.iterations

# end

# function simulate(h::H, gs::G, pl::I, opp_bias::V) where {V<:StaticVector, H<:History, G<:AbstractGameState}
#     #todo: 
#     (lga, n_actions) = legalactions!(K2, gs)

#     info = infoset(h , infosetkey(gs))

#     #problem: for bias, some times some actions are not available (like raise)
#     # so we can't apply bias there...
#     # the bias array has the same size as the total number of actions, 
#     # and we select the bias at the index of the legal action... 

#     if pl != gs.player
#         #apply bias to opponent blueprint strategy
        
#         stg = copy(cumulativestrategy!(info, gs.player))

#         for i in 1:n_actions
#             stg[i] *= opp_bias[lgs[i]]
#         end

#     else
#         stg = cumulativestrategy!(info.cum_strategy)
#     end

#     #add a small chance of sampling off-policy actions? don't see any interest here...
#     sample = sampleaction(lga, n_actions, stg/sum(stg))

#     ngs = perform(action(sample), gs, gs.player)

#     #game ends when we reach 
#     if ended(ngs) == true
#         return computeutility!(T, gs)
#     end

#     return simulate(History(h, K2(sample)), gs, pl, opp_bias)

# end


end