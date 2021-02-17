

"""
http://www.trackvis.org/docs/?subsect=fileformat

`id_string::NTuple{6,UInt8}`: ID string for track file. The first 5 characters must be \"TRACK\".
`dim::NTuple{3,Int16}`: Dimension of the image volume
`voxel_size::NTuple{3,Float32}`: Voxel size of the image volume
`origin::Ntuple{3,Float32}`: Origin of the image volume. This field is not yet
                             being used by TrackVis. That means the origin is
                             always (0, 0, 0).
`n_scalars::Int16`: Number of scalars saved at each track point (besides x, y and z coordinates).
`scalar_name::NTuple{10,NTuple{20,UInt8}}`: Name of each scalar. Can not be longer than 20 characters each. Can only store up to 10 names.
`n_properties::UInt16`: Number of properties saved at each track.
`property_name::NTuple{10,NTuple{20,UInt8}}`: Name of each property. Can not be longer than 20 characters each. Can only store up to 10 names.
`vox_to_ras::Matrix{Float32}`: 4x4 matrix for voxel to RAS (crs to xyz) transformation. If vox_to_ras[3][3] is 0, it means the matrix is not recorded. This field is added from version 2.
`reserved[444]::NTuple{444,UInt8}`: Reserved space for future version.
`voxel_order::NTuple{4,UInt8}`: Storing order of the original image data. Explained here.
`pad2::NTuple{2,UInt8}`: Paddings
`image_orientation_patient::NTuple{6,Float32}`: Image orientation of the original image. As defined in the DICOM header.
`pad1::NTuple{2,UInt8}`: Paddings
`invert_x::UInt8`,`invert_y::UInt8`,`invert_x::UInt8`,`swap_xy::UInt8`,`swap_yz::UInt8`,`swap_zx::UInt8`: Inversion/rotation flags used to generate this track file. For internal use only.
`n_count::Int32`: Number of tracks stored in this track file. 0 means the number was NOT stored.
`version::Int32`: Version number. Current version is 2.
`hdr_size::Int32`: Size of the header. Used to determine byte swap. Should be 1000.


141531076

f = "../tmp/ABCDStudy/test/data/DTI1_PA1_AP1/streamlines/full_interface_prob_pft.trk"
io = open(f)
s = load(io, TrkStream);
mytracks = load(s, VecPath);

trk = load(s, PathMeta);


"""
struct TrkHeader
    dim::NTuple{3,Int16}
    voxel_size::NTuple{3,Float32}
    origin::NTuple{3,Float32}
    nscalars::Int16
    scalar_name::NTuple{10,NTuple{20,UInt8}}
    nproperties::UInt16
    property_name::NTuple{10,NTuple{20,UInt8}}
    vox_to_ras::NTuple{4,NTuple{4,Float32}}
    reserved::NTuple{444,UInt8}
    voxel_order::NTuple{4,UInt8}
    pad2::NTuple{4,UInt8}
    image_orientation_patient::NTuple{6,Float32}
    pad1::NTuple{2,UInt8}
    invert_x::UInt8
    invert_y::UInt8
    invert_z::UInt8
    swap_xy::UInt8
    swap_yz::UInt8
    swap_zx::UInt8
    ncount::Int32
    version::Int32
    hdr_size::Int32
end

@generated function read_header(io)
    out = Expr(:new, TrkHeader)
    for p in fieldtypes(TrkHeader)
        if p <: Tuple
            t = Expr(:tuple)
            for p_i in p.parameters
                if p_i <: Tuple
                    t_i = Expr(:tuple)
                    for p_j in p_i.parameters
                        push!(t_i.args, :(read(io, $p_j)))
                    end
                    push!(t.args, t_i)
                else
                    push!(t.args, :(read(io, $p_i)))
                end
            end
            push!(out.args, t)
        else
            push!(out.args, :(read(io, $p)))
        end
    end
    return out
end

@generated function read_header_swap(io)
    out = Expr(:new, TrkHeader)
    for p in fieldtypes(TrkHeader)
        if p <: Tuple
            t = Expr(:tuple)
            for p_i in p.parameters
                if p_i <: Tuple
                    t_i = Expr(:tuple)
                    for p_j in p_i.parameters
                        push!(t_i.args, :(bswap(read(io, $p_j))))
                    end
                    push!(t.args, t_i)
                else
                    push!(t.args, :(bswap(read(io, $p_i))))
                end
            end
            push!(out.args, t)
        else
            push!(out.args, :(bswap(read(io, $p))))
        end
    end
    return out
end

read_trk(file::AbstractString; mode="r") = read_trk(open(file, mode))
function read_trk(io)
    b1, b2, b3, b4, b5, b6 = read(io, 6)
    if (b1, b2, b3, b4, b5) === (0x54, 0x52, 0x41, 0x43, 0x4b)
        return read_header(io)
    elseif (b6, b5, b4, b3, b2) === (0x4b, 0x43, 0x41, 0x52, 0x54)
        return read_header_swap(io)
    else
        error("This is not a Track file.")
    end
end

function load(io::IO, ::Type{TrkStream})
    needswap = checkfile(io)
    hdr = read(io, TrkHeader, needswap)
    TrkStream(hdr, io, needswap)
end

function load(s::TrkStream, ::Type{VecPoint})
    nscalars = convert(Int64, s.hdr.nscalars)
    if s.needswap
        VecPoint((bswap.(read!(s.io, Vector{Float32}(undef, 3)))...,),
                 (bswap.(read!(s.io, Vector{Float32}(undef, nscalars)))...,))
    else
        VecPoint((read!(s.io, Vector{Float32}(undef, 3))...,),
                 (read!(s.io, Vector{Float32}(undef, nscalars))...,))
    end
end

"""
#C: Path count
S: Size of a path
N: Dimensions
Tp: Type (e.g., Int, Float32) representing position of each VecPoint
Ns: Number of scalars in a VecPoint
Ts: Type (e.g., Int, Float32) of scalars in a VecPoint

#  Path{3,Float32,nscalars,Float32}
"""

function load(s::TrkStream, ::Type{VecPath})
    nprops = s.hdr.nproperties
    ncount = s.hdr.ncount
    nscalars = convert(Int64, s.hdr.nscalars)
    #vecpointtype = VecPath{3,Float32,nscalars,Float32}


    vecdata = Vector{Path}(undef, ncount);
    props = Dict{String,Any}();

    propnames = []
    for i in 1:nprops
        append!(propnames, s.hdr.property_name[i])
        if propnames[i] == 0
            props[String("property$i")] = []
        else
            props[String([propnames[i]...])] = []
        end
    end

    # load each path
    # i = each pathway
    # p = each point
    # j = each property
    for pathway_i in 1:ncount
        npoints = read!(s.io, Vector{Int32}(undef, 1))[1]

        if s.needswap
            npoints = bswap(npoints)
        end

        if s.needswap

            data[pathway_i] = [bswap.([load(s, VecPoint) for p in OneTo(npoints)])...]
        else
            vecdata[pathway_i] = [(load(s, VecPoint) for p in OneTo(npoints))...]
        end

        for j in 1:nprops
            props[propnames[j]][pathway_i] = read!(s.io, Vector{Float32}(undef, 1))[1]
        end
    end

    if s.needswap
        props = bswap.(props)
    end
    return (vecdata, props)  # this should be ImageMeta
end

#### FINAL

@inline function read_trk_point_swap(io, nscalars::Integer)
    return PointNode(
        map(bswap, read_type_swap(io, NTuple{3,Float32})),
        if nscalars == 0
            Float32[]
        else
            for i in OneTo(nscalars)
            [bswap(read(io, Float32)) for i in ]
        end
    )
end

@inline function read_trk_point_noswap(io, nscalars::Integer)
    return PointNode(
        read_type_noswap(io, NTuple{3,Float32}),
        if nscalars == 0
            Float32[]
        else
            [read(io, Float32) for i in OneTo(nscalars)]
        end
    )
end

function read_tract_noswap(io, nscalars::Integer, nprops::Integer)
    npoints = bswap(read(io, Int32))

    out = NodeFiber(Vector{TrkPoint}(undef, npoints), Vector{Float32}(undef, nprops))
    for i in OneTo(npoints)
        @inbounds out[i] = read_trk_point_noswap(io, nscalars)
    end

    for i in OneTo(nprops)
        @inbounds out.metadata[i] = read(io, Float32)
    end
    return out
end

function read_tract_noswap(io, nscalars::Integer, nprops::Integer)
    npoints = read(io, Int32)
    out = Tract(Vector{TractPoint}(undef, npoints), Vector{Float32}(undef, nprops))
    for i in OneTo(npoints)
        out.points[i] = read_trk_point_noswap(io, nscalars)
    end

    for i in OneTo(nprops)
        out.points[i] = read(io, Float32)
    end
    return out
end

function readtrk_swap(io)
end

function readtrk_noswap(io)
    hdr = NamedTuple{TRK_FIELDS,TRK_TUPLE}(read_type_noswap(io, TRK_TUPLE))
    propnames = map(OneTo(hdr.nproperties)) do i
        n_i = hdr.property_name[i]
        if n_i == 0
            Symbol("property_$i")
        else
            Symbol(n_i)
        end
    end

    return BraintTracts(
        hdr,
        [read_tract_noswap(io, hdr.nscalars, hdr.nproperties)],
        propnames
    )
end

function readtrk(io::IO)
    magic = read_type_noswap(io, NTuple{5,UInt8})
    if magic === MAGIC_BYTES
        hdr = NamedTuple{TRK_FIELDS,TRK_TUPLE}(read_tract_noswap(io, TRK_TUPLE))
        propnames = map(OneTo(hdr.nproperties)) do i
            n_i = hdr.property_name[i]
            if n_i == 0
                Symbol("property_$i")
            else
                Symbol(n_i)
            end
        end

        fibers = Vector{TrkFiber}(undef, npoints)

        for fiber_i in OneTo(hdr.ncount)
            @inbounds fibers[fibers_i] = NodeFiber(Vector{TrkPoint}(undef, npoints), Vector{Float32}(undef, nprops))
            npoints = read(io, Int32)
            for point_i in OneTo(npoints)
                @inbounds fibers[fibers_i][point_i] = PointNode(read_type_noswap(io, NTuple{3,Float32}), read!(io, Vector{Float32}(undef, hdr.nscalars)))
            end
            props = properties(@inbounds(fibers[fibers_i]))
            for property_i in OneTo(hdr.nproperties)
                @inbounds props[property_i] = read(io, Float32)
            end
        end
        return BraintTracts(hdr, fibers, propnames)
    elseif map(bswap, magic) === MAGIC_BYTES
        return readtrk_swap(io)
    else
        error("Not a track file.")
    end
end

@inline function read_trk_point_swap(io, nscalars::Integer)
    return PointNode(
        map(bswap, read_type_swap(io, NTuple{3,Float32})),
        if nscalars == 0
            Float32[]
        else
            for i in OneTo(nscalars)
            [bswap(read(io, Float32)) for i in ]
        end
    )
readtrk(trkfile) = readtrk(open(trkfile))

