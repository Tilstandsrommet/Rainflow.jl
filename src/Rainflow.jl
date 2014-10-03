module Rainflow
import Base.show

export sort_peaks, find_boundary_vals, count_cycles, sum_cycles

""" This function sort out points where the slope is changing sign."""
function sort_peaks(signal::AbstractArray{Float64,1}, dt=[0.:length(signal)-1.])
    slope = diff(signal)
    # Determines if the point is local extremum
    is_extremum = [true ;(slope[1:end-1].*slope[2:end]).<=0.;true]
    return signal[is_extremum] , dt[is_extremum]
end

immutable Cycle  # This is the information stored for each cycle found
    count::Float64
    range::Float64
    mean::Float64  # value
    v_s::Float64   # value start
    t_s::Float64   # time start
    v_e::Float64   # value end
    t_e::Float64   # time end
end

show(io::IO,x::Cycle) = print(io, "Cycle: count=", x.count, ", range=",x.range, ", mean=",x.mean)

function cycle(count::Float64, v_s::Float64, t_s::Float64, v_e::Float64, t_e::Float64)
    Cycle(count, abs(v_s-v_e), (v_s+v_e)/2, v_s, t_s, v_e, t_e)
end

""" Count the cycles from the data. """
function count_cycles(ext_in::Array{Float64,1},t::Array{Float64,1})
    ext = copy(ext_in) # Makes a copy because there is going to be sorted in the vectors
    time = copy(t)
    i = 1
    j = 2
    cycles = Cycle[]
    sizehint(cycles, length(ext)) # This reduces the memory consumption a bit
    @inbounds begin
    while length(ext)>(i+1)
        Y = abs(ext[i+1]-ext[i])
        X = abs(ext[j+1]-ext[j])
        if X>=Y
            if i == 1 # This case counts a half and cycle deletes the poit that is counted
                #println("Half cycle $(ext[i]), $(ext[i+1])")
                push!(cycles,cycle(0.5 ,ext[i], time[i], ext[i+1],time[i+1]))
                shift!(ext) # Removes the first entrance in ext and time
                shift!(time)
            else # This case counts one cycle and deletes the poit that is counted
                #println("One cycle $(ext[i]), $(ext[i+1])")
                push!(cycles,cycle(1. ,ext[i], time[i], ext[i+1],time[i+1]))
                splice!(ext,i+1)  # Removes the i and i+1 entrance in ext and time
                splice!(ext,i)
                splice!(time,i+1)
                splice!(time,i)
            end
            i = 1
            j = 2
        else
            i += 1
            j += 1
        end
    end
    for i=1:length(ext)-1 # This counts the rest of the points that have not been counted as a half cycle
        #println("Half cycle $(ext[i]), $(ext[i+1])")
        push!(cycles,cycle(0.5 ,ext[i], time[i], ext[i+1],time[i+1]))
    end
    end
    return cycles
end

type Cycles_bounds #
    min_mean::Float64
    max_mean::Float64
    max_range::Float64
end

show(io::IO,x::Cycles_bounds) = print(io, "Cycles_bounds : min mean value=", x.min_mean, ", max mean value=", x.max_mean, ", max range=",x.max_range)

""" Find the minimum and maximum mean value and maximum range from a vector of cycles. """
function find_boundary_vals(cycles::Array{Cycle,1})
    bounds = Cycles_bounds(Inf, -Inf, -Inf)
    for cycle in cycles
        cycle.mean > bounds.max_mean && setfield!(bounds, :max_mean, cycle.mean)
        cycle.mean < bounds.min_mean && setfield!(bounds, :min_mean, cycle.mean)
        cycle.range > bounds.max_range && setfield!(bounds, :max_range, cycle.range)
    end
    return bounds
end

""" Returns the range index the value is belonging in """
function find_range{T<:Real}(spacing::Array{T,1},value)
    for i=1:length(spacing)-1
        if spacing[i] <= value <= spacing[i+1]
            return i
        end
    end
    error("The value where not in range, see if the vectors in calc_sum(cycles::Array{Cycle,1}, range_spacing::Array{T,1}, mean_spacing::Array{T,1}) are continious increasing in value, or adjust the nr_digits parameter")
end

""" Sums the cycle count given intervals of range_spacing and mean_spacing. """
function sum_cycles{T<:Real}(cycles::Array{Cycle,1}, range_spacing::Array{T,1}, mean_spacing::Array{T,1})
    bounds = find_boundary_vals(cycles)
    bins = zeros(length(range_spacing)-1, length(mean_spacing)-1)
    range_spacing *= bounds.max_range/100
    #show(range_spacing)
    mean_spacing *= (bounds.max_mean-bounds.min_mean)/100
    mean_spacing += bounds.min_mean
    nr_digits = 14  # The rounding is performed due to numerical noise in the floats when comparing
    mean_spacing = round(mean_spacing, nr_digits)
    range_spacing = round(range_spacing, nr_digits)
    #show(mean_spacing)
    for cycle in cycles
        i = find_range(range_spacing,round(cycle.range, nr_digits))
        j = find_range(mean_spacing,round(cycle.mean, nr_digits))
        bins[i,j] += cycle.count
    end
    return bins
end

function sum_cycles(cycles::Array{Cycle,1}, nr_ranges::Int=10, nr_means::Int=1)
    range_spacing = linspace(0,100,nr_ranges+1)
    mean_spacing = linspace(0,100,nr_means+1)
    sum_cycles(cycles, range_spacing, mean_spacing)
end

try
    include("plot.jl")
catch
    println("""For added plotting features do: Pkg.add("PyPlot")""")
end

end # module
