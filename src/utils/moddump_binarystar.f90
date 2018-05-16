!--------------------------------------------------------------------------!
! The Phantom Smoothed Particle Hydrodynamics code, by Daniel Price et al. !
! Copyright (c) 2007-2018 The Authors (see AUTHORS)                        !
! See LICENCE file for usage and distribution conditions                   !
! http://users.monash.edu.au/~dprice/phantom                               !
!--------------------------------------------------------------------------!
!+
!  MODULE: moddump
!
!  DESCRIPTION:
!  Input is a relaxed star, output is two relaxed stars in binary orbit
!
!  REFERENCES: None
!
!  OWNER: Terrence Tricco
!
!  $Id$
!
!  RUNTIME PARAMETERS: None
!
!  DEPENDENCIES: centreofmass, dim, externalforces, initial_params,
!    options, part, prompting, units
!+
!--------------------------------------------------------------------------
module moddump
 implicit none

contains

subroutine modify_dump(npart,npartoftype,massoftype,xyzh,vxyzu)
 use part,           only: nptmass,xyzmh_ptmass,vxyz_ptmass,igas,set_particle_type,igas
 use units,          only: set_units,udist,unit_velocity
 use prompting,      only: prompt
 use centreofmass,   only: reset_centreofmass
 use initial_params, only: get_conserv
 integer, intent(inout) :: npart
 integer, intent(inout) :: npartoftype(:)
 real,    intent(inout) :: massoftype(:)
 real,    intent(inout) :: xyzh(:,:),vxyzu(:,:)
 integer :: i
 integer :: opt, Nstar1, Nstar2
 real :: sep,mtot,angvel,vel1,vel2
 real :: x1com(3), v1com(3), x2com(3), v2com(3)
 real :: m1,m2

 print *, 'Running moddump_binarystar:'
 print *, ''
 print *, 'This utility sets two stars in binary orbit around each other, or modifies an existing binary.'
 print *, ''
 print *, 'Options:'
 print *, '   1) Duplicate a relaxed star'
 print *, '   2) Add a star from another dumpfile'
 print *, '   3) Adjust separation of existing binary'

 opt = 1
 call prompt('Choice',opt, 1, 3)

 if (opt  /=  1 .and. opt  /=  2 .and. opt /= 3) then
    print *, 'Incorrect option selected. Doing nothing.'
    return
 endif

 sep = 10.0
 print *, ''
 call prompt('Enter radial separation between stars (in code unit)', sep, 0.)
 print *, ''

 ! duplicate star if chosen
 if (opt == 1) then
    call duplicate_star(npart, npartoftype, massoftype, xyzh, vxyzu, Nstar1, Nstar2)
 endif

 ! add a new star from another dumpfile
 if (opt == 2) then
    call add_star(npart, npartoftype, massoftype, xyzh, vxyzu, Nstar1, Nstar2)
 endif

 ! add a uniform low density background fluid
! if (opt == 3) then
!    call add_background(npart, npartoftype, massoftype, xyzh, vxyzu)
! endif



 ! find the centre of mass position and velocity for each star
 call calc_coms(npart,npartoftype,massoftype,xyzh,vxyzu,Nstar1,Nstar2,x1com,v1com,x2com,v2com,m1,m2)

 ! adjust separation of binary
 call adjust_sep(npart,npartoftype,massoftype,xyzh,vxyzu,Nstar1,Nstar2,sep,x1com,v1com,x2com,v2com)


 mtot = npart*massoftype(igas)
 angvel = sqrt(1.0 * mtot / sep**3)   ! angular velocity
 vel1   = m1 * sep / mtot * angvel
 vel2   = m2 * sep / mtot * angvel

 ! find the centre of mass position and velocity for each star
 call calc_coms(npart,npartoftype,massoftype,xyzh,vxyzu,Nstar1,Nstar2,x1com,v1com,x2com,v2com,m1,m2)

 ! set orbital velocity
 call set_velocity(npart,npartoftype,massoftype,xyzh,vxyzu,Nstar1,Nstar2,x1com,x2com,angvel,vel1,vel2)
 !call set_corotate_velocity(npart,npartoftype,massoftype,xyzh,vxyzu,angvel)




 ! reset centre of mass of the binary system
 call reset_centreofmass(npart,xyzh,vxyzu,nptmass,xyzmh_ptmass,vxyz_ptmass)

 get_conserv = 1.

end subroutine modify_dump


!
! Take the star from the input file and duplicate it some distance apart.
! This assumes the dump file only has one star.
!
subroutine duplicate_star(npart,npartoftype,massoftype,xyzh,vxyzu,Nstar1,Nstar2)
 use part,         only: nptmass,xyzmh_ptmass,vxyz_ptmass,igas,set_particle_type,igas,temperature
 use units,        only: set_units,udist,unit_velocity
 use prompting,    only: prompt
 use centreofmass, only: reset_centreofmass
 use dim,          only: store_temperature
 integer, intent(inout) :: npart
 integer, intent(inout) :: npartoftype(:)
 real,    intent(inout) :: massoftype(:)
 real,    intent(inout) :: xyzh(:,:),vxyzu(:,:)
 integer, intent(out)   :: Nstar1, Nstar2
 integer :: i
 real :: sep,mtot,velocity

 npart = npartoftype(igas)

 sep = 10.0

 ! duplicate relaxed star
 do i = npart+1, 2*npart
    ! place star a distance rad away
    xyzh(1,i) = xyzh(1,i-npart) + sep
    xyzh(2,i) = xyzh(2,i-npart)
    xyzh(3,i) = xyzh(3,i-npart)
    xyzh(4,i) = xyzh(4,i-npart)
    vxyzu(1,i) = vxyzu(1,i-npart)
    vxyzu(2,i) = vxyzu(2,i-npart)
    vxyzu(3,i) = vxyzu(3,i-npart)
    vxyzu(4,i) = vxyzu(4,i-npart)
    if (store_temperature) then
       temperature(i) = temperature(i-npart)
    endif
    call set_particle_type(i,igas)
 enddo

 Nstar1 = npart
 Nstar2 = npart

 npart = 2 * npart
 npartoftype(igas) = npart

end subroutine duplicate_star


!
! Place a star that is read from another dumpfile
!
subroutine add_star(npart,npartoftype,massoftype,xyzh,vxyzu,Nstar1,Nstar2)
 use part,            only: nptmass,xyzmh_ptmass,vxyz_ptmass,igas,set_particle_type,igas,temperature,alphaind
 use units,           only: set_units,udist,unit_velocity
 use prompting,       only: prompt
 use centreofmass,    only: reset_centreofmass
 use dim,             only: maxp,maxvxyzu,nalpha,maxalpha,store_temperature
 use readwrite_dumps, only: read_dump
 use io,              only: idisk1,iprint
 integer, intent(inout) :: npart
 integer, intent(inout) :: npartoftype(:)
 real,    intent(inout) :: massoftype(:)
 real,    intent(inout) :: xyzh(:,:),vxyzu(:,:)
 integer, intent(out)   :: Nstar1, Nstar2
 character(len=120) :: fn
 real, allocatable :: xyzh2(:,:)
 real, allocatable :: vxyzu2(:,:)
 real, allocatable :: temperature2(:)
 real, allocatable :: alphaind2(:,:)
 integer :: i,ierr
 real    :: time2,hfact2,sep


 print *, ''
 print *, 'Adding a new star read from another dumpfile'
 print *, ''

 fn = ''
 call prompt('Name of second dumpfile',fn)

 ! read_dump will overwrite the current particles, so store them in a temporary array
 allocate(xyzh2(4,maxp),stat=ierr)  ! positions + smoothing length
 if (ierr /= 0) stop ' error allocating memory to store positions'
 allocate(vxyzu2(maxvxyzu,maxp),stat=ierr)  ! velocity + thermal energy
 if (ierr /= 0) stop ' error allocating memory to store velocity'
 if (store_temperature) then        ! temperature
    allocate(temperature2(maxp),stat=ierr)
    if (ierr /= 0) stop ' error allocating memory to store temperature'
 endif
 if (maxalpha == maxp) then         ! artificial viscosity alpha
    allocate(alphaind2(nalpha,maxp),stat=ierr)
    if (ierr /= 0) stop ' error allocating memory to store alphaind'
 endif

 Nstar2 = npart
 xyzh2  = xyzh
 vxyzu2 = vxyzu
 if (store_temperature) then
    temperature2 = temperature
 endif
 if (maxalpha == maxp) then
    alphaind2 = alphaind
 endif 
 

 ! read second dump file
 call read_dump(trim(fn),time2,hfact2,idisk1+1,iprint,0,1,ierr)
 if (ierr /= 0) stop 'error reading second dumpfile'


 Nstar1 = npart
 sep = 10.0

 ! insert saved star (from original dump file)
 do i = npart+1, npart+Nstar2
    ! place star a distance rad away
    xyzh(1,i) = xyzh2(1,i-npart) + sep
    xyzh(2,i) = xyzh2(2,i-npart)
    xyzh(3,i) = xyzh2(3,i-npart)
    xyzh(4,i) = xyzh2(4,i-npart)
    vxyzu(1,i) = vxyzu2(1,i-npart)
    vxyzu(2,i) = vxyzu2(2,i-npart)
    vxyzu(3,i) = vxyzu2(3,i-npart)
    vxyzu(4,i) = vxyzu2(4,i-npart)
    if (store_temperature) then
       temperature(i) = temperature2(i-npart)
    endif
    if (maxalpha == maxp) then
       alphaind(1,i) = alphaind2(1,i-npart)
       alphaind(2,i) = alphaind2(2,i-npart)
    endif
    call set_particle_type(i,igas)
 enddo

 npart = npart + Nstar2
 npartoftype(igas) = npart

 print *, npart
end subroutine add_star


!
! Calculate com position and velocity for the two stars
!
subroutine calc_coms(npart,npartoftype,massoftype,xyzh,vxyzu,Nstar1,Nstar2,x1com,v1com,x2com,v2com,m1,m2)
 use part,         only: nptmass,xyzmh_ptmass,vxyz_ptmass,igas,set_particle_type,igas,iamtype,iphase,maxphase,maxp
 use units,        only: set_units,udist,unit_velocity
 use prompting,    only: prompt
 use centreofmass, only: reset_centreofmass
 integer, intent(inout) :: npart
 integer, intent(inout) :: npartoftype(:)
 real,    intent(inout) :: massoftype(:)
 real,    intent(inout) :: xyzh(:,:),vxyzu(:,:)
 integer, intent(in)    :: Nstar1, Nstar2
 real,    intent(out)   :: x1com(:),v1com(:),x2com(:),v2com(:)
 real,    intent(out)   :: m1,m2
 integer :: i, itype
 real    :: xi, yi, zi, vxi, vyi, vzi
 real    :: totmass, pmassi, dm

 ! first star
 x1com = 0.
 v1com = 0.
 totmass = 0.
 do i = 1, Nstar1
    xi = xyzh(1,i)
    yi = xyzh(2,i)
    zi = xyzh(3,i)
    vxi = vxyzu(1,i)
    vyi = vxyzu(2,i)
    vzi = vxyzu(3,i)
    if (maxphase == maxp) then
       itype = iamtype(iphase(i))
       if (itype > 0) then
          pmassi = massoftype(itype)
       else
          pmassi = massoftype(igas)
       endif
    else
       pmassi = massoftype(igas)
    endif

    totmass = totmass + pmassi
    x1com(1) = x1com(1) + pmassi * xi
    x1com(2) = x1com(2) + pmassi * yi
    x1com(3) = x1com(3) + pmassi * zi
    v1com(1) = v1com(1) + pmassi * vxi
    v1com(2) = v1com(2) + pmassi * vyi
    v1com(3) = v1com(3) + pmassi * vzi
 enddo

 if (totmass > tiny(totmass)) then
    dm = 1.d0/totmass
 else
    dm = 0.d0
 endif
 x1com = dm * x1com
 v1com = dm * v1com
 m1    = totmass

 ! second star
 x2com = 0.
 v2com = 0.
 totmass = 0.
 do i = Nstar1+1, npart
    xi = xyzh(1,i)
    yi = xyzh(2,i)
    zi = xyzh(3,i)
    vxi = vxyzu(1,i)
    vyi = vxyzu(2,i)
    vzi = vxyzu(3,i)
    if (maxphase == maxp) then
       itype = iamtype(iphase(i))
       if (itype > 0) then
          pmassi = massoftype(itype)
       else
          pmassi = massoftype(igas)
       endif
    else
       pmassi = massoftype(igas)
    endif

    totmass = totmass + pmassi
    x2com(1) = x2com(1) + pmassi * xi
    x2com(2) = x2com(2) + pmassi * yi
    x2com(3) = x2com(3) + pmassi * zi
    v2com(1) = v2com(1) + pmassi * vxi
    v2com(2) = v2com(2) + pmassi * vyi
    v2com(3) = v2com(3) + pmassi * vzi
 enddo

 if (totmass > tiny(totmass)) then
    dm = 1.d0/totmass
 else
    dm = 0.d0
 endif
 x2com = dm * x2com
 v2com = dm * v2com
 m2    = totmass

end subroutine calc_coms


!
! Adjust the separation of the two stars.
! First star is placed at the origin, second star is placed sep away in x
!
subroutine adjust_sep(npart,npartoftype,massoftype,xyzh,vxyzu,Nstar1,Nstar2,sep,x1com,v1com,x2com,v2com)
 integer, intent(inout) :: npart
 integer, intent(inout) :: npartoftype(:)
 real,    intent(inout) :: massoftype(:)
 real,    intent(inout) :: xyzh(:,:),vxyzu(:,:)
 integer, intent(in)    :: Nstar1, Nstar2
 real,    intent(in)    :: x1com(:),v1com(:),x2com(:),v2com(:)
 real,    intent(in)    :: sep
 integer :: i

 print *, sep
 do i = 1, Nstar1
    xyzh(1,i) = xyzh(1,i) - x1com(1)
    xyzh(2,i) = xyzh(2,i) - x1com(2)
    xyzh(3,i) = xyzh(3,i) - x1com(3)
    vxyzu(1,i) = vxyzu(1,i) - v1com(1)
    vxyzu(2,i) = vxyzu(2,i) - v1com(2)
    vxyzu(3,i) = vxyzu(3,i) - v1com(3)
 enddo

 do i = Nstar1+1, npart
    xyzh(1,i) = xyzh(1,i) - x2com(1) + sep
    xyzh(2,i) = xyzh(2,i) - x2com(2)
    xyzh(3,i) = xyzh(3,i) - x2com(3)
    vxyzu(1,i) = vxyzu(1,i) - v2com(1)
    vxyzu(2,i) = vxyzu(2,i) - v2com(2)
    vxyzu(3,i) = vxyzu(3,i) - v2com(3)
 enddo

end subroutine adjust_sep


!
! Set corotation external force on using angular velocity
!
subroutine set_corotate_velocity(angvel)
 use options,        only:iexternalforce
 use externalforces, only: omega_corotate,iext_corotate
 real,    intent(in)    :: angvel

 print "(/,a,es18.10,/)", ' The angular velocity in the corotating frame is: ', angvel

 ! Turns on corotation
 iexternalforce = iext_corotate
 omega_corotate = angvel

end subroutine


!
! Set orbital velocity in normal space
!
subroutine set_velocity(npart,npartoftype,massoftype,xyzh,vxyzu,Nstar1,Nstar2,x1com,x2com,angvel,vel1,vel2)
 use part,         only: nptmass,xyzmh_ptmass,vxyz_ptmass,igas,set_particle_type,igas
 use units,        only: set_units,udist,unit_velocity
 use prompting,    only: prompt
 use centreofmass, only: reset_centreofmass
 integer, intent(inout) :: npart
 integer, intent(inout) :: npartoftype(:)
 real,    intent(inout) :: massoftype(:)
 real,    intent(inout) :: xyzh(:,:),vxyzu(:,:)
 integer, intent(in)    :: Nstar1, Nstar2
 real,    intent(in)    :: x1com(:), x2com(:)
 real,    intent(in)    :: angvel
 real,    intent(in)    :: vel1,vel2
 integer :: i
 real :: mtot

 print *, "Setting stars in mutual orbit with angular velocity ", angvel
 print *, "  Adding bulk velocity |v| = ", vel1, "( = ", (vel1*unit_velocity), &
                  " physical units) to first star"
 print *, "                       |v| = ", vel2, "( = ", (vel2*unit_velocity), &
                  " physical units) to second star"
 print *, ""

 ! Adjust bulk velocity of relaxed star towards second star
 vxyzu(1,:) = 0.
 vxyzu(2,:) = 0.
 vxyzu(3,:) = 0.
 do i = 1, Nstar1
    vxyzu(2,i) = vxyzu(2,i) + vel1
 enddo

 do i = Nstar1+1, npart
    vxyzu(2,i) = vxyzu(2,i) - vel2
 enddo

end subroutine set_velocity


end module moddump

