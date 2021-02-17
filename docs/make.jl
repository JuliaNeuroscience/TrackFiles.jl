using TrackFiles
using Documenter

makedocs(;
    modules=[TrackFiles],
    authors="Zachary P. Christensen <zchristensen7@gmail.com> and contributors",
    repo="https://github.com/JuliaNeuroscience/TrackFiles.jl/blob/{commit}{path}#L{line}",
    sitename="TrackFiles.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaNeuroscience.github.io/TrackFiles.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaNeuroscience/TrackFiles.jl",
)
