"""
get_reader(f::TaskResultsFormat)

Gets the reader function that will import the Table data
from the filesystem.
"""
function get_reader(f::TaskResultsFormat)::Function end

"""
get_writer(f::TaskResultsFormat)

Gets the writer function that will export the Table data
to the filesystem.
"""
function get_writer(f::TaskResultsFormat)::Function end

"""
get_extension(f::TaskResultsFormat)::String

Gets the file extension to be used when exporting the data.
"""
function get_extension(f::TaskResultsFormat)::String end

# CLASS AnyFormat --------------------------------------------------------------------------------

function get_reader(f::AnyFormat)::Function
    no_op(p, df) = nothing
    return no_op
end

function get_writer(f::AnyFormat)::Function
    no_op(p, df) = nothing
    return no_op
end

function get_extension(f::AnyFormat)::String
    return ""
end

# CLASS CSVFormat --------------------------------------------------------------------------------

function get_reader(f::CSVFormat)::Function
    return CSV.read
end

function get_writer(f::CSVFormat)::Function
    return CSV.write
end

function get_extension(f::CSVFormat)::String
    return ".csv"
end

# CLASS ParquetFormat --------------------------------------------------------------------------------

function get_reader(f::ParquetFormat)::Function
    return read_parquet
end

function get_writer(f::ParquetFormat)::Function
    return Parquet.write_parquet
end

function get_extension(f::ParquetFormat)::String
    return ".parquet"
end

# HELPERS -------------------------------------------------------------------------------------
