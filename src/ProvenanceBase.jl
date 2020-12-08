"""
Base package for provenance providers and consumers.

Main extensions points are:

  - `provenance`: to be extended by "providers" of provenance data, i.e.
    packages with types that wish to provide provenance data about themselves.

  - `signature`: to be extended by "consumers" of provenance data, i.e.
    packages which capture, track, or analyse provenance data.

For details about extending these please see their respective documentation
strings.
"""
module ProvenanceBase

import Dates

# producers extend
export provenance

# consumers extend
export Provenance, AbstractSignature
export signature, verify, is_signed, has_provenance, flat

"""
    provenance(object) -> NamedTuple

Describes the *provenance* of an `object` as a `NamedTuple`. Provenance here
refers to the following:

> Provenance is information about entities, activities, and people involved in
> producing a piece of data or thing, which can be used to form assessments
> about its quality, reliability or trustworthiness.
>
> -- https://www.w3.org/TR/prov-overview/

Returns `nothing` when no provenance has been captured from `object`.

Package authors with types that they wish to take part in provenance capture
should extend `provenance` on their types. The definition *must* return a
`NamedTuple` containing relevant provenance data associated with the `object`.

# Examples

```julia
struct MyType
    # ...
end

function ProvenanceBase.provenance(t::MyType)
    # Compute provenance data associated with `t`.
    return (
        # Assign provenance data to named fields and return it.
    )
end
```

# Data

`ProvenanceBase` does **not** prescribe a required set of provenance data that
should be returned by these methods. It is up individual package authors to
decide on the relevant data themselves.

Data that typically does not need to be captured is system-level data that is
globally available, unless it is of direct relevance to the associated
`object`. Data that would typically be included in the return value of
`provenance` would be internal (or public) data of the `object` that needs a
uniform access pattern.
"""
provenance(@nospecialize(object)) = nothing

"""
    AbstractSignature

An abstract type used to describe how the provenance data for a particular
object will be digitally signed.

To be extended by packages that provide signing functionality.
"""
abstract type AbstractSignature end

"""
    NoSignature

The default used when signing data, which does not sign data. Should be used
when no data integrity or authenticity is required or when the required
libraries are not available.
"""
struct NoSignature <: AbstractSignature end

"""
    Provenance(object, [sigtype=NoSignature()])

Captures and timestamps the provenance data associated with `object` as defined
by the `provenance` definition for the type of `object`.

To be called by provenance tracking packages that want to capture provenance
data associated with `object`. By passing in a `sigtype` the signing of the
generated provenance data can be customized.
"""
struct Provenance{S<:AbstractSignature}
    signature::S
    timestamp::Dates.DateTime
    data::Union{NamedTuple,Nothing}

    function Provenance(object, S = NoSignature)
        timestamp = Dates.now()
        data = provenance(object) # producers extend
        sig = signature(S, object, timestamp, data) # consumers extend
        return new{S}(sig, timestamp, data)
    end
end

"""
    has_provenance(provenance) -> Bool

Check whether the `provenance` object contains any usable provenance data.
"""
has_provenance(p::Provenance) = p.data isa NamedTuple

"""
    signature(::Type{AbstractSignature}, object, timestamp, data) -> String

Compute a verifiable checksum for the given `object`, `timestamp`, and `data`.

Extended by packages that bring in the required cryptographic libraries. The
extender of `signature` must define their own subtype of `AbstractSignature` to
use in their method signature.

# Examples

```julia
struct MySignature <: AbstractSignature
    # ...
end

signature(::Type{MySignature}, object, timestamp, data) = # ...
```

Along with `signature` the extender must also extend `is_signed` and `verify`
to work with their new type.
"""
function signature end

signature(::Type{NoSignature}, object, timestamp, data) = NoSignature()

"""
    is_signed(provenance::Provenance) -> Bool

Checks whether `provenance` data has been signed. Does not verify the
authenticity of the signature though.
"""
function is_signed end

is_signed(::Provenance{NoSignature}) = false

"""
    verify(object, provenance::Provenance) -> Bool

Check whether `provenance` was produced by `object`.

To be extended by packages that provide the required cryptographic methods. By
default this function will work on `Provenance{NoSignature}` data, and will
always verify successfully.
"""
function verify end

verify(@nospecialize(object), ::Provenance{NoSignature}) = true

"""
    flat(p)

Flatten out a potentially nested `Provenance` object `p` into a `Dict`.
"""
flat(p::Provenance) = flat!(Dict(), p.data)

function flat!(out, nt::NamedTuple, root = ())
    for (k, v) in zip(keys(nt), values(nt))
        flat!(out, v, (root..., k))
    end
    return out
end
flat!(out, ::Nothing, root = ()) = out
flat!(out, value, root) = (out[root] = value; out)
flat!(out, p::Provenance, root) = flat!(out, p.data, root)

end
