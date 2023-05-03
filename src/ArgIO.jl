"""
Provide external awareness / service-related side-effects to SciML operations
"""
module ArgIO

import Symbolics
import DataFrames: DataFrame, rename!
import CSV
import HTTP: Request
import Oxygen: serveparallel, serve, resetstate, json, setschema, @post, @get

include("./Settings.jl"); import .Settings: settings
include("./AssetManager.jl"); import .AssetManager: fetch_dataset, fetch_model, upload

export prepare_input, prepare_output


"""
Transform requests into arguments to be used by operation    

Optionally, IDs are hydrated with the corresponding entity from TDS.
"""
function prepare_input(req::Request)
    args = json(req, Dict{Symbol,Any})
    if settings["ENABLE_TDS"]
        if in(:model, keys(args))
            args[:model] = fetch_model(args[:model])   
        end
        if in(:dataset, keys(args)) 
            args[:dataset] = fetch_dataset(args[:dataset])   
        end
    end
    args
end

"""
Normalize the header of the resulting dataframe and return a CSV

Optionally, the CSV is saved to TDS instead an the coreresponding ID is returned.    
"""
function prepare_output(dataframe::DataFrame)
    stripped_names = names(dataframe) .=> (r -> replace(r, "(t)"=>"")).(names(dataframe))
    rename!(dataframe, stripped_names)
    rename!(dataframe, "timestamp" => "timestep")
    if !settings["ENABLE_TDS"]
        io = IOBuffer()
        # TODO(five): Write to remote server
        CSV.write(io, dataframe)
        return String(take!(io))
    else
        return upload(dataframe)
    end
end

"""
Coerces NaN values to nothing for each parameter.    
"""
function prepare_output(params::Vector{Pair{Symbolics.Num, Float64}})
    nan_to_nothing(value) = isnan(value) ? nothing : value
    Dict(key => nan_to_nothing(value) for (key, value) in params)
end

end