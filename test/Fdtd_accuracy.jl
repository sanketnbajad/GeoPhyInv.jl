addprocs(2)
using JuMIT
using Base.Test
using Signals
using Misfits


model = JuMIT.Gallery.Seismic(:acou_homo1);
acqgeom = JuMIT.Gallery.Geom(model.mgrid,:xwell);
tgrid = JuMIT.Gallery.M1D(:acou_homo1);
wav = Signals.Wavelets.ricker(10.0, tgrid, tpeak=0.25, );
# source wavelet for born modelling
acqsrc = JuMIT.Acquisition.Src_fixed(acqgeom.nss,1,[:P],wav,tgrid);


vp0=mean(JuMIT.Models.χ(model.χvp,model.vp0,-1))
ρ0=mean(JuMIT.Models.χ(model.χρ,model.ρ0,-1))
rec1 = JuMIT.Analytic.mod(vp0=vp0,
            model_pert=model,
		             ρ0=ρ0,
			         acqgeom=acqgeom, acqsrc=acqsrc, tgridmod=tgrid, src_flag=2)



pa=JuMIT.Fdtd.Param(npw=1,model=model,
    acqgeom=[acqgeom], acqsrc=[acqsrc],
        sflags=[2], rflags=[1],
	    tgridmod=tgrid, verbose=true );
JuMIT.Fdtd.mod!(pa);


# least-squares misfit
err = Misfits.TD!(nothing,rec1, pa.c.data[1])

# normalization
error = err[1]/dot(rec1, rec1)

# desired accuracy?
@test error<1e-2
