@inbounds @fastmath function advance!(pac::T, pap) where {T<:P_common{<:FdtdElastic}}
    for ipw in pac.activepw
        # store p for the last two steps
        # pppppp!(pap[ipw],pac.attrib_mod)
        advance_kernel!(pap[ipw], pac)
    end
    return nothing
end


# these relative indices of the arrays point to same location
# [ix,iy,iz]     --> tauxx, tauyy, and tauzz grid [1:nx,1:ny,1:nz]
# [ix+1/2,iy+1/2,iz+1]      --> tauxy
# [ix+1/2,iy+1,iz+1/2]      -->  tauxz
# [ix-1/2,iy,iz]       --> vx
# [ix,iy-1/2,iz]       --> vy
# [ix,iy,iz-1/2]       --> vz

@parallel function compute_dtau!(
    tauxx,
    tauyy,
    tauzz,
    tauxy,
    tauxz,
    tauyz,
    dtauxxdx,
    dtauxydx,
    dtauxzdx,
    dtauyydy,
    dtauxydy,
    dtauyzdy,
    dtauzzdz,
    dtauyzdz,
    dtauxzdz,
    dxI,
    dyI,
    dzI,
)

    @all(dtauxxdx) = @d_zi(tauxx) * dxI # at [ix+1/2,iy+1,iz+1] with indices []
    @all(dtauxydx) = @d_za(tauxy) * dxI # at [ix+1,iy+1/2,iz+1]
    @all(dtauxzdx) = @d_za(tauxz) * dxI # at [ix+1,iy+1,iz+1/2]


    @all(dtauyydy) = @d_yi(tauyy) * dyI # at [ix+1,iy+1/2,iz+1]
    @all(dtauxydy) = @d_ya(tauxy) * dyI # at [ix+1/2,iy+1,iz+1]
    @all(dtauyzdy) = @d_ya(tauyz) * dyI # at [ix+1,iy+1,iz+1/2]


    @all(dtauzzdz) = @d_xi(tauzz) * dzI # at [ix+1,iy+1,iz+1/2]
    @all(dtauxzdz) = @d_xa(tauxz) * dzI # at [ix+1/2,iy+1,iz+1]
    @all(dtauyzdz) = @d_xa(tauyz) * dzI # at [ix+1,iy+1/2,iz+1]

    return
end

@parallel function compute_dtau!(
    tauxx,
    tauzz,
    tauxz,
    dtauxxdx,
    dtauxzdx,
    dtauzzdz,
    dtauxzdz,
    dxI,
    dzI,
)

    @all(dtauxxdx) = @d_zi(tauxx) * dxI # at [ix+1/2,iz+1] with indices []
    @all(dtauxzdx) = @d_za(tauxz) * dxI # at [ix+1,iz+1/2]

    @all(dtauzzdz) = @d_xi(tauzz) * dzI # at [ix+1,iz+1/2]
    @all(dtauxzdz) = @d_xa(tauxz) * dzI # at [ix+1/2,iz+1]

    return
end

@parallel function compute_v!(
    vx,
    vy,
    vz,
    dtauxxdx,
    dtauxydx,
    dtauxzdx,
    dtauyydy,
    dtauxydy,
    dtauyzdy,
    dtauzzdz,
    dtauyzdz,
    dtauxzdz,
    dt,
    rho,
)

    @inn(vx) =
        @inn(vx) - dt / @av_xi(rho) * (@all(dtauxxdx) + @all(dtauxydy) + @all(dtauxzdz))
    @inn(vy) =
        @inn(vy) - dt / @av_yi(rho) * (@all(dtauxydx) + @all(dtauyydy) + @all(dtauyzdz))
    @inn(vz) =
        @inn(vz) - dt / @av_zi(rho) * (@all(dtauxzdx) + @all(dtauyzdy) + @all(dtauzzdz))

    return
end
@parallel function compute_v!(vx, vz, dtauxxdx, dtauxzdx, dtauzzdz, dtauxzdz, dt, rho)

    @inn(vx) = @inn(vx) - dt / @av_xi(rho) * (@all(dtauxxdx) + @all(dtauxzdz))
    @inn(vz) = @inn(vz) - dt / @av_zi(rho) * (@all(dtauxzdx) + @all(dtauzzdz))

    return
end



@parallel function compute_dv!(
    vx,
    vy,
    vz,
    dvxdx,
    dvydy,
    dvzdz,
    dvxdy,
    dvxdz,
    dvydx,
    dvydz,
    dvzdx,
    dvzdy,
    dxI,
    dyI,
    dzI,
)
    @all(dvxdx) = @d_za(vx) * dxI # at [ix,iy,iz]
    @all(dvydy) = @d_ya(vy) * dyI # at      "
    @all(dvzdz) = @d_xa(vz) * dzI # at      "

    @all(dvxdy) = @d_yi(vx) * dyI # at [ix+1/2,iy+1/2,iz+1]
    @all(dvxdz) = @d_xi(vx) * dzI # at [ix+1/2,iy+1,iz+1/2]

    @all(dvydz) = @d_xi(vy) * dzI # at [ix+1,iy+1/2,iz+1/2]
    @all(dvydx) = @d_zi(vy) * dxI # at [ix+1/2,iy+1/2,iz+1]

    @all(dvzdx) = @d_zi(vz) * dxI # at [ix+1/2,iy+1,iz+1/2]
    @all(dvzdy) = @d_yi(vz) * dyI # at [ix+1,iy+1/2,iz+1/2]

    return
end


@parallel function compute_dv!(vx, vz, dvxdx, dvzdz, dvxdz, dvzdx, dxI, dzI)
    @all(dvxdx) = @d_za(vx) * dxI # at [ix,iz]
    @all(dvzdz) = @d_xa(vz) * dzI # at      "

    @all(dvxdz) = @d_xi(vx) * dzI # at [ix+1/2,iz+1/2]
    @all(dvzdx) = @d_zi(vz) * dxI # at [ix+1/2,iy+1,iz+1/2]

    return
end





@parallel function compute_tauii!(tauxx, tauyy, tauzz, dvxdx, dvydy, dvzdz, dt, M, lambda)

    @all(tauxx) =
        @all(tauxx) -
        dt * ((@all(M) * @all(dvxdx)) + (@all(lambda) * (@all(dvydy) + @all(dvzdz))))
    @all(tauyy) =
        @all(tauyy) -
        dt * ((@all(M) * @all(dvydy)) + (@all(lambda) * (@all(dvxdx) + @all(dvydy))))
    @all(tauzz) =
        @all(tauzz) -
        dt * ((@all(M) * @all(dvzdz)) + (@all(lambda) * (@all(dvydy) + @all(dvxdx))))

    return
end

@parallel function compute_tauii!(tauxx, tauzz, dvxdx, dvzdz, dt, M, lambda)
    @all(tauxx) =
        @all(tauxx) -
        dt * ((@all(M) * @all(dvxdx)) + (@all(lambda) * (@all(dvydy) + @all(dvzdz))))
    @all(tauzz) =
        @all(tauzz) -
        dt * ((@all(M) * @all(dvzdz)) + (@all(lambda) * (@all(dvydy) + @all(dvxdx))))

    return
end
@parallel function compute_tauij!(
    tauxy,
    tauxz,
    tauyz,
    dvxdy,
    dvxdz,
    dvydx,
    dvydz,
    dvzdx,
    dvzdy,
    dt,
    mu,
)
    @all(tauxz) = @all(tauxz) - dt * (@av_xzi(mu) * (@all(dvxdz) + @all(dvzdx)))
    @all(tauxy) = @all(tauxy) - dt * (@av_xyi(mu) * (@all(dvxdy) + @all(dvydx)))
    @all(tauyz) = @all(tauyz) - dt * (@av_yzi(mu) * (@all(dvydz) + @all(dvzdy)))

    return
end
@parallel function compute_tauij!(tauxz, dvxdz, dvzdx, dt, mu)
    @all(tauxz) = @all(tauxz) - dt * (@av_xzi(mu) * (@all(dvxdz) + @all(dvzdx)))
    
    return
end



for dimnames in [zip([:1, :2, :3], [:z, :y, :x]), zip([:1, :2], [:z, :x])]
    is = broadcast(x -> Symbol(string("i", x)), getindex.(collect(dimnames), 2))
    ist = Meta.parse(string("(", [string(s, ",") for s in is]..., ")"))
    for (idim, dim) in dimnames
        i = Symbol("i", string(dim))
        ismoff = replace(is, i => :($i + moff))
        isdoff = replace(is, i => :(doff + $i))
        for (fname, fnamenp, idoff) in zip(
            [
                Symbol("memory", string(dim), string(length(is)), "!"),
                Symbol("memory1", string(dim), string(length(is)), "!"),
            ],
            [
                Symbol("memorynp", string(dim), string(length(is)), "!"),
                Symbol("memorynp1", string(dim), string(length(is)), "!"),
            ],
            [:($i + doff), :($i + doff + 1)],
        )
            @eval @parallel_indices(
                $ist,
                function $fnamenp(memory, d, a, b, kI, moff, doff)
                    memory[$(ismoff...)] =
                        b[$idoff] * memory[$(ismoff...)] + a[$idoff] * d[$(isdoff...)]
                    d[$(isdoff...)] = d[$(isdoff...)] * kI[$idoff] + memory[$(ismoff...)]
                    return
                end
            )
            @eval function $fname(memory, d, a, b, kI)
                sm = collect(size(memory))
                setindex!(sm, npml, $idim)
                # first npml points
                @parallel map(x -> (:)(1, x), Tuple(sm)) $fnamenp(memory, d, a, b, kI, 0, 0)
                # last npml points independent of d
                @parallel map(x -> (:)(1, x), Tuple(sm)) $fnamenp(
                    memory,
                    d,
                    a,
                    b,
                    kI,
                    npml,
                    getindex(size(d), $idim) - npml,
                )
            end
        end

        # velocity-free boundary conditions    
        fname = Symbol("dirichlet", string(dim), "!")

        is1, is2, is3 = [replace(is, i => ii) for ii in [:1, :2, :3]]
        isn = replace(is, i => :n)
        isnm1 = replace(is, i => :(n - 1))
        isnp1 = replace(is, i => :(n + 1))

        irest = Meta.parse(
            string("(", [string(s, ",") for s in filter(x -> x != i, is)]..., ")"),
        )
        v = Symbol("v", string(dim))
        vs = broadcast(x -> Symbol(string("v", x)), getindex.(collect(dimnames), 2))
        vrest = filter(x -> x != v, vs)
        vrestt = Meta.parse(string("(", [string(s, ",") for s in vrest]..., ")"))

        @eval @parallel_indices($irest, function $fname($v, $(vrest...), n)
            # along other dimensions velocity grid matches tauii grid
            for vv in $vrestt
                vv[$(is1...)] = 0
                vv[$(isn...)] = 0
            end

            # relative to the tauii grid, velocity at i=2 should be zero, so making use of ghost cells 
            $v[$(is1...)] = -$v[$(is2...)]
            $v[$(isnp1...)] = -$v[$(isn...)]
            return
        end)
    end
end




function advance_kernel!(pap, pac::T) where {T<:P_common{FdtdElastic,3}}
    w1t = pap.w1[:t]
    mw = pap.memory_pml
    pml = pac.pml

    @parallel compute_dtau!(
        w1t[:tauxx],
        w1t[:tauyy],
        w1t[:tauzz],
        w1t[:tauxy],
        w1t[:tauxz],
        w1t[:tauyz],
        w1t[:dtauxxdx],
        w1t[:dtauxydx],
        w1t[:dtauxzdx],
        w1t[:dtauyydy],
        w1t[:dtauxydy],
        w1t[:dtauyzdy],
        w1t[:dtauzzdz],
        w1t[:dtauyzdz],
        w1t[:dtauxzdz],
        pac.fc[:dxI],
        pac.fc[:dyI],
        pac.fc[:dzI],
    )

    memoryx3!(
        mw[:dtauxxdx],
        w1t[:dtauxxdx],
        pml[:x][:a_half],
        pml[:x][:b_half],
        pml[:x][:k_halfI],
    )
    memory1x3!(mw[:dtauxydx], w1t[:dtauxydx], pml[:x][:a], pml[:x][:b], pml[:x][:kI])
    memory1x3!(mw[:dtauxzdx], w1t[:dtauxzdx], pml[:x][:a], pml[:x][:b], pml[:x][:kI])

    memoryy3!(
        mw[:dtauyydy],
        w1t[:dtauyydy],
        pml[:y][:a_half],
        pml[:y][:b_half],
        pml[:y][:k_halfI],
    )
    memory1y3!(mw[:dtauxydy], w1t[:dtauxydy], pml[:y][:a], pml[:y][:b], pml[:y][:kI])
    memory1y3!(mw[:dtauyzdy], w1t[:dtauyzdy], pml[:y][:a], pml[:y][:b], pml[:y][:kI])

    memoryz3!(
        mw[:dtauzzdz],
        w1t[:dtauzzdz],
        pml[:z][:a_half],
        pml[:z][:b_half],
        pml[:z][:k_halfI],
    )
    memory1z3!(mw[:dtauyzdz], w1t[:dtauyzdz], pml[:z][:a], pml[:z][:b], pml[:z][:kI])
    memory1z3!(mw[:dtauxzdz], w1t[:dtauxzdz], pml[:z][:a], pml[:z][:b], pml[:z][:kI])

    @parallel compute_v!(
        w1t[:vx],
        w1t[:vy],
        w1t[:vz],
        w1t[:dtauxxdx],
        w1t[:dtauxydx],
        w1t[:dtauxzdx],
        w1t[:dtauyydy],
        w1t[:dtauxydy],
        w1t[:dtauyzdy],
        w1t[:dtauzzdz],
        w1t[:dtauyzdz],
        w1t[:dtauxzdz],
        pac.fc[:dt],
        pac.mod[:rho],
    )

    @parallel (1:pac.ic[:nz], 1:pac.ic[:ny]) dirichletx!(
        w1t[:vx],
        w1t[:vz],
        w1t[:vy],
        pac.ic[:nx],
    )
    @parallel (1:pac.ic[:nz], 1:pac.ic[:nx]) dirichlety!(
        w1t[:vy],
        w1t[:vz],
        w1t[:vx],
        pac.ic[:ny],
    )
    @parallel (1:pac.ic[:ny], 1:pac.ic[:nx]) dirichletz!(
        w1t[:vz],
        w1t[:vy],
        w1t[:vx],
        pac.ic[:nz],
    )
    @parallel compute_dv!(
        w1t[:vx],
        w1t[:vy],
        w1t[:vz],
        w1t[:dvxdx],
        w1t[:dvydy],
        w1t[:dvzdz],
        w1t[:dvxdy],
        w1t[:dvxdz],
        w1t[:dvydx],
        w1t[:dvydz],
        w1t[:dvzdx],
        w1t[:dvzdy],
        pac.fc[:dxI],
        pac.fc[:dyI],
        pac.fc[:dzI],
    )
    memoryx3!(mw[:dvxdx], w1t[:dvxdx], pml[:x][:a], pml[:x][:b], pml[:x][:kI])
    memoryy3!(mw[:dvydy], w1t[:dvydy], pml[:y][:a], pml[:y][:b], pml[:y][:kI])
    memoryz3!(mw[:dvzdz], w1t[:dvzdz], pml[:z][:a], pml[:z][:b], pml[:z][:kI])

    memoryy3!(
        mw[:dvxdy],
        w1t[:dvxdy],
        pml[:y][:a_half],
        pml[:y][:b_half],
        pml[:y][:k_halfI],
    )
    memoryz3!(
        mw[:dvxdz],
        w1t[:dvxdz],
        pml[:z][:a_half],
        pml[:z][:b_half],
        pml[:z][:k_halfI],
    )
    memoryx3!(
        mw[:dvydx],
        w1t[:dvydx],
        pml[:x][:a_half],
        pml[:x][:b_half],
        pml[:x][:k_halfI],
    )

    memoryz3!(
        mw[:dvydz],
        w1t[:dvydz],
        pml[:z][:a_half],
        pml[:z][:b_half],
        pml[:z][:k_halfI],
    )
    memoryx3!(
        mw[:dvzdx],
        w1t[:dvzdx],
        pml[:x][:a_half],
        pml[:x][:b_half],
        pml[:x][:k_halfI],
    )
    memoryy3!(
        mw[:dvzdy],
        w1t[:dvzdy],
        pml[:y][:a_half],
        pml[:y][:b_half],
        pml[:y][:k_halfI],
    )

    @parallel compute_tauii!(
        w1t[:tauxx],
        w1t[:tauyy],
        w1t[:tauzz],
        w1t[:dvxdx],
        w1t[:dvydy],
        w1t[:dvzdz],
        pac.fc[:dt],
        pac.mod[:M],
        pac.mod[:lambda],
    )
    @parallel compute_tauij!(
        w1t[:tauxy],
        w1t[:tauxz],
        w1t[:tauyz],
        w1t[:dvxdy],
        w1t[:dvxdz],
        w1t[:dvydx],
        w1t[:dvydz],
        w1t[:dvzdx],
        w1t[:dvzdy],
        pac.fc[:dt],
        pac.mod[:mu],
    )


end


function advance_kernel!(pap, pac::T) where {T<:P_common{FdtdElastic,2}}
    w1t = pap.w1[:t]
    mw = pap.memory_pml
    pml = pac.pml

    @parallel compute_dtau!(
        w1t[:tauxx],
        w1t[:tauzz],
        w1t[:tauxz],
        w1t[:dtauxxdx],
        w1t[:dtauxzdx],
        w1t[:dtauzzdz],
        w1t[:dtauxzdz],
        pac.fc[:dxI],
        pac.fc[:dzI],
    )

    memoryx2!(
        mw[:dtauxxdx],
        w1t[:dtauxxdx],
        pml[:x][:a_half],
        pml[:x][:b_half],
        pml[:x][:k_halfI],
    )
    memory1x2!(mw[:dtauxzdx], w1t[:dtauxzdx], pml[:x][:a], pml[:x][:b], pml[:x][:kI])

    memoryz2!(
        mw[:dtauzzdz],
        w1t[:dtauzzdz],
        pml[:z][:a_half],
        pml[:z][:b_half],
        pml[:z][:k_halfI],
    )
    memory1z2!(mw[:dtauxzdz], w1t[:dtauxzdz], pml[:z][:a], pml[:z][:b], pml[:z][:kI])

    @parallel compute_v!(
        w1t[:vx],
        w1t[:vz],
        w1t[:dtauxxdx],
        w1t[:dtauxzdx],
        w1t[:dtauzzdz],
        w1t[:dtauxzdz],
        pac.fc[:dt],
        pac.mod[:rho],
    )

    @parallel (1:pac.ic[:nz]) dirichletx!(w1t[:vx], w1t[:vz], pac.ic[:nx])
    @parallel (1:pac.ic[:nx]) dirichletz!(w1t[:vz], w1t[:vx], pac.ic[:nz])
    @parallel compute_dv!(
        w1t[:vx],
        w1t[:vz],
        w1t[:dvxdx],
        w1t[:dvzdz],
        w1t[:dvxdz],
        w1t[:dvzdx],
        pac.fc[:dxI],
        pac.fc[:dzI],
    )
    memoryx2!(mw[:dvxdx], w1t[:dvxdx], pml[:x][:a], pml[:x][:b], pml[:x][:kI])
    memoryz2!(mw[:dvzdz], w1t[:dvzdz], pml[:z][:a], pml[:z][:b], pml[:z][:kI])

    memoryz2!(
        mw[:dvxdz],
        w1t[:dvxdz],
        pml[:z][:a_half],
        pml[:z][:b_half],
        pml[:z][:k_halfI],
    )

    memoryx2!(
        mw[:dvzdx],
        w1t[:dvzdx],
        pml[:x][:a_half],
        pml[:x][:b_half],
        pml[:x][:k_halfI],
    )

    @parallel compute_tauii!(
        w1t[:tauxx],
        w1t[:tauzz],
        w1t[:dvxdx],
        w1t[:dvzdz],
        pac.fc[:dt],
        pac.mod[:M],
        pac.mod[:lambda],
    )
    @parallel compute_tauij!(
        w1t[:tauxz],
        w1t[:dvxdz],
        w1t[:dvzdx],
        pac.fc[:dt],
        pac.mod[:mu],
    )


end
