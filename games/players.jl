module players

export Player
export PlayerState
export ID

export id
export player

export state
export position
export totalbet
export action
export setaction!

abstract type PlayerState end

struct Player
    id::UInt8
    position::UInt8

    Player(id, position) = new(id, position)
end

@inline function Base.position(player::Player)
    return player.position
end

@inline function Base.:(==)(p1::Player, p2::Player)
    return p1.id == p2.id
end

end
