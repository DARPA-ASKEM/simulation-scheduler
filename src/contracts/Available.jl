"""
Operations interface for the simulation service
"""
module Available

import CSV
import AlgebraicPetri: LabelledPetriNet, AbstractPetriNet
import DataFrames: DataFrame

include("./ProblemInputs.jl"); import .ProblemInputs: conversions_for_valid_inputs
include("./SystemInputs.jl"); import .SystemInputs: Context
include("../operations/Operations.jl"); import .Operations
include("../Settings.jl"); import .Settings: settings

export available_operations

available_operations = Dict{String, Function}()

"""
Retrieve internal atomic operations
"""
function get_operation(operation::Symbol)
    if in(operation, names(Operations; all=false, imported=true))
        return getfield(Operations, operation)
    else
        return nothing
    end
end

function simulate(;
    model,
    timespan=(0.0, 100.0)::Tuple{Float64,Float64},
    context
)
    Dict("result" => get_operation(:simulate)(;model=model, timespan=timespan, context))
end

available_operations["simulate"] = simulate

function calibrate_then_simulate(; 
    model::AbstractPetriNet, # TODO(five): Remove from exports and rename
    params::Dict{String,Float64},
    initials::Dict{String,Float64},
    dataset::DataFrame,
    timespan::Union{Nothing, Tuple{Float64, Float64}} = nothing,
    context,
)
    results = Dict{String, Any}()
    calibrated_params = get_operation(:calibrate)(;model=model, params=params, initials=initials, dataset=dataset, context=context)
    results["parameters"] = calibrated_params
    if in(NaN, values(calibrated_params)) throw("NaN adjustment") 
        return results
    end
    adjusted_params = Dict(string(key.val) => value for (key,value) in calibrated_params)
    tmin, tmax = (dataset.timestep[1], dataset.timestep[end])
    results["simulation"] = get_operation(:simulate)(;model=model, params=adjusted_params, initials=initials, timespan=(tmin, tmax), context=context)
    if isnothing(timespan)
        return results
    end
    results["extra-simulation"] = get_operation(:simulate)(;model=model, params=adjusted_params, initials=initials, timespan=timespan, context=context)
    results
end

available_operations["calibrate"] = calibrate_then_simulate





end # module Available