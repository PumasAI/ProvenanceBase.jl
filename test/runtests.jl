using ProvenanceBase
using Test

struct CustomType
    field::Int
end

function ProvenanceBase.provenance(ct::CustomType)
    return (field = ct.field, computed = ct.field + 1)
end

struct NestedTest
    ct::CustomType
    field::Int
end

ProvenanceBase.provenance(nt::NestedTest) = (
    ct = ProvenanceBase.Provenance(nt.ct),
    field = nt.field,
)

struct CustomSignature <: AbstractSignature
    str::String
end

function ProvenanceBase.signature(::Type{CustomSignature}, object, timestamp, data)
    return CustomSignature(string(object, timestamp, repr(data)))
end

function ProvenanceBase.verify(object, p::Provenance{CustomSignature})
    return string(object, p.timestamp, repr(p.data)) == p.signature.str
end

ProvenanceBase.is_signed(::Provenance{CustomSignature}) = true

@testset "ProvenanceBase.jl" begin
    for object in ([1], CustomType(1))
        p_object = Provenance(object)
        @test typeof(p_object) == Provenance{ProvenanceBase.NoSignature}
        @test !is_signed(p_object)
        @test verify(object, p_object)
    end

    @test !has_provenance(Provenance([1]))
    let p = Provenance(CustomType(1))
        @test has_provenance(p)
        @test p.data.field == 1
        @test p.data.computed == 2
        @test flat(p) == Dict{Any,Any}((:field,) => 1, (:computed,) => 2)
    end

    let  p = Provenance(NestedTest(CustomType(1), 2))
        @test flat(p) == Dict{Any,Any}(
            (:field,) => 2,
            (:ct, :computed) => 2,
            (:ct, :field) => 1,
        )
    end

    for object in ([1], CustomType(1))
        p_object = Provenance(object, CustomSignature)
        @test typeof(p_object) == Provenance{CustomSignature}
        @test is_signed(p_object)
        @test verify(object, p_object)
    end
end
