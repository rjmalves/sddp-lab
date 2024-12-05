
function __node2season(node::Int, period::Int, initial_season::Int)
    m = (initial_season + node - 1)
    if m > period
        season = m - period * Int(div(m, period + 1e-5))
    else
        season = m
    end

    return season
end