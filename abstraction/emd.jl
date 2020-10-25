struct CustomEMD
    sorted_distances::Matrix{Float32, Float32} # next_round_clusters x length(centers)
    ordered_clusters::Matrix{Float32, Float32} # next_round_clusters x length(centers)
end

function (t::CustomEMD)(points::Vector{Float32}, centers::Vector{Float32})
    n = length(points)
    q = length(centers)

    ordered_clusters = t.ordered_clusters
    sorted_distances = t.sorted_distances

    targets = [1/n for i in 1:n]
    mean_remaining = copy(centers)
    done = [false for i in 1:n]
    tot_cost = 0

    for i in 1:q
        for j in 1:n
            if done[j] == true
                continue
            end
            point_cluster = points[j]
            mean_cluster = ordered_clusters[point_cluster][i]
            amt_remaining = amt_remaining[mean_cluster]
            if amt_remaining == 0
                continue
            end
            d = sorted_distances[point_cluster]
            if amt_remaining < targets[j]
                tot_cost += amt_remaining * d
                targets[j] -= amt_remaining
                mean_remaining[mean_cluster] = 0
            else
                tot_cost += targets[j] * d
                targets[j] = 0
                mean_remaining[mean_cluster] -= targets[j]
                done[j] = true
            end
        end
    end
    return tot_cost
end
