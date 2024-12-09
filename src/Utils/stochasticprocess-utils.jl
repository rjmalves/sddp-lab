
function __node2season(node::Int, period::Int, initial_season::Int)
    m = (initial_season + node - 1)
    if m > period
        season = m - period * Int(div(m, period + 1e-5))
    else
        season = m
    end

    return season
end

function __lagged_season(current_season::Int, lag::Int, period::Int)
    m = current_season - lag
    if m >= 1
        lagged_season = m
    elseif (m < 1) & (m > -period)
        lagged_season = period + m
    elseif m <= -period
        lagged_season = period + Int(rem(m, period))
    end

    return lagged_season
end