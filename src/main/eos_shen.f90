module eos_shen
 !author: G.Shen, C. Horowitz, and S. Teige
 !modified: Z. Pellow
 	 
 use datafiles, only:find_phantom_datafile
 use io,      only:warning
 	 
 implicit none
 integer, parameter :: nr = 328, nt = 109, ny = 53
 real, parameter :: MevtoK=1.1604*1.e10,amu=1.660538921*1.e-24
 real, parameter :: fmtocm=1.e-13,Mevtoerg=1.60217733*1.e-6
! real, allocatable, dimension(:,:,:) :: tl,yl,dl
 real:: t1(nr,nt,ny),y1(nr,nt,ny),d1(nr,nt,ny),&
  &f1(nr,nt,ny),p1(nr,nt,ny),s1(nr,nt,ny),cn1(nr,nt,ny),&
  &cp1(nr,nt,ny),an1(nr,nt,ny),pn1(nr,nt,ny),xn1(nr,nt,ny),&
  &xp1(nr,nt,ny),xa1(nr,nt,ny),xi1(nr,nt,ny),em1(nr,nt,ny),&
  &ce1(nr,nt,ny),e1(nr,nt,ny)
 real:: t2(nr,nt,ny),y2(nr,nt,ny),d2(nr,nt,ny)
 character(len=120) :: filename

 contains
 
 
  subroutine init_eos_shen_NL3(ierr)
   implicit none
   integer, intent(out)::ierr
   logical :: file_exists
   
   ! find the table datafile
 filename = find_phantom_datafile('eos_binary_table.dat', 'eos/shen')
 print*,filename
	
! test is table exists
 open(unit=1,file=trim(filename),status='old',iostat=ierr,form='unformatted')
 print*,ierr
 if (ierr /= 0) then
    call warning('eos_shen','could not find eos_binary_table.dat to initialise eos')
    ierr = 1
    return
 endif
 
   call read_binary_table()
 
  end subroutine init_eos_shen_NL3
  
  
  subroutine eos_shen_NL3(rin_cgs,tin_cgs,yin,p,spsound)
   implicit none
   real, intent(in) ::rin_cgs,tin_cgs,yin
   real::rin,tin
   real, intent(out)::p,spsound
   real             ::fer,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm
   real             ::turning_point,rin_tmp,dp_drho,p_r1
   integer          ::cont
   
   !cgs to shen
   rin=rin_cgs/(amu/(fmtocm**3))
   tin=tin_cgs/MevtoK
   
if (rin>1.e-8) then
   	!the value is inside shen
    call cubic_readeos_simp(tin,yin,rin,p)
   else if (rin<=1.e-8) then
   	!the value is outside shen
   	rin_tmp=rin*(amu/(fmtocm**3))
   	turning_point=(Log10(tin)+2.373)/0.331+2
   	if (Log10(rin_tmp)<turning_point.and.Log10(1.000001*1.e-8*(amu/(fmtocm**3)))<turning_point) then
   	 !past the turning point which is inside shen
     call cubic_readeos_simp(tin,yin,1.000001*1.e-8,p)
     call cubic_readeos_simp(tin,yin,1.000002*1.e-8,p_r1)
     dp_drho=(p-p_r1)/((1.000001*1.e-8)-(1.000002*1.e-8))
     p=p+((rin-(1.000001*1.e-8))*dp_drho)
   	elseif (Log10(rin_tmp)<turning_point) then
   	 !past the turning point which is outside shen
   		!find the turning point
     call ideal_eos(10**(turning_point)*((fmtocm**3)/amu),tin,yin,p)
   	 call ideal_eos(10**(turning_point)*((fmtocm**3)/amu)*1.000001,tin,yin,p_r1)
   	 
   	 dp_drho=(p_r1-p)/((10**(turning_point)*1.000001)&
   	 &-(10**(turning_point)))*.9
   	 
   	 p=p-(10**(turning_point)-rin_tmp)*dp_drho
   	else
     !before the turning point which is outside shen
     call ideal_eos(rin,tin,yin,p)
   	endif
   end if
   
   call sound_speed_comb(rin,tin,yin,spsound)
   
   !shen to cgs
   p=p*Mevtoerg/((fmtocm)**3)
   spsound=spsound
   
  end subroutine eos_shen_NL3
  
  
  subroutine read_ascii_all()
   implicit none
   
   integer:: in_t=109, in_b=328
   integer::i,j,k,m
   
   open(90,file='NL3eos1.03.dat',status='unknown')
   write(*,*) 'loading NL3eos1.03.dat'
   
   m=0
   do i=1,in_t
    do j=1,53
     do k=1,in_b
      read(90,*) t1(k,i,j),&
      &	       y1(k,i,j),&				! proton fraction                  
     &		   d1(k,i,j),&				! baryon number density          [fm**-3]
     &		   f1(k,i,j),&				! free energy per baryon         [MeV]
     &		   p1(k,i,j),&				! pressure                       [MeV fm**-3]
     &		   s1(k,i,j),&				! jenergy per baryon              [MeV]
     &		   cn1(k,i,j),&				! chemical potential for neutron [MeV]
     &		   cp1(k,i,j),&				! chemical potential for proton  [MeV]
     &		   ce1(k,i,j),&				! chemical potential for electron[MeV] 
     &		   an1(k,i,j),&				! average mass number       
     &		   pn1(k,i,j),&				! average proton number
     &		   xn1(k,i,j),&				! fraction of free neutron
     &		   xp1(k,i,j),&				! fraction of free proton
     &		   xa1(k,i,j),&				! fraction of alphas
     &		   xi1(k,i,j),&				! fraction of heavy nuclei
     &		   em1(k,i,j)
     m=m+1
     d2(k,i,j) = log10(d1(k,i,j))
     if(i.ne.1) t2(k,i,j) = log10(t1(k,i,j))
     enddo
    enddo
    write(*,*) i, t1(k-1,i,j-1)
   enddo
   
   close(90)
   
   write(*,*) 'loading completed: number of points =   ', m
  
  end subroutine read_ascii_all
  
  
  subroutine write_binary_table()
   integer::i,j,k,m
  
!   call read_ascii_all()
   open(unit=1,file='eos_binary_table.dat',status='replace',form='unformatted')
   
   m=0
   do i=1,nt
    do j=1,53
     do k=1,nr
      write(1) t1(k,i,j),&
      &	       y1(k,i,j),&				! proton fraction                  
     &		   d1(k,i,j),&				! baryon number density          [fm**-3]
     &		   f1(k,i,j),&				! free energy per baryon         [MeV]
     &		   p1(k,i,j),&				! pressure                       [MeV fm**-3]
     &		   s1(k,i,j)				! energy per baryon              [MeV]
     m=m+1
     enddo
    enddo
    print*, i, t1(k-1,i,j-1)
   enddo
   
   close(1)
  
  end subroutine write_binary_table
  
  
  subroutine read_binary_table()
   integer::i,j,k,m
  
	! find the table datafile
 filename = find_phantom_datafile('eos_binary_table.dat', 'eos/shen')
! open the table datafile
   open(unit=1,file=trim(filename),status='old',form='unformatted')
   
   m=0
   do i=1,nt
    do j=1,53
     do k=1,nr
      read(1) t1(k,i,j),&
      &	       y1(k,i,j),&				! proton fraction                  
     &		   d1(k,i,j),&				! baryon number density          [fm**-3]
     &		   f1(k,i,j),&				! free energy per baryon         [MeV]
     &		   p1(k,i,j),&				! pressure                       [MeV fm**-3]
     &		   s1(k,i,j)				! energy per baryon              [MeV]
     m=m+1
     d2(k,i,j) = log10(d1(k,i,j))
     if(i.ne.1) t2(k,i,j) = log10(t1(k,i,j))
     enddo
    enddo
    print*, i, t1(k-1,i,j-1)
   enddo
   
   close(1)
  
  end subroutine read_binary_table
  
  
  subroutine CINT(val0,val1,val2,val3,u,val)
  real, intent(out) ::val
  real, intent(in)  ::val0,val1,val2,val3,u
  
  val=1./2.*(((-val0+3.*val1-3.*val2+val3)*u+(2.*val0-5.*val1+4.*val2-val3))*u+&
  &(-val0+val2))*u+val1
  
  end subroutine CINT
  
  
  subroutine linear_interpolator_one_d(val0,val1,u,val)
  real, intent(out) ::val
  real, intent(in)  ::val0,val1,u
  
   val=(1.-u)*val0+u*val1
  
  end subroutine linear_interpolator_one_d
  
  
  subroutine cubic_interpolator(valu,val1,grho,gtem,gye,iff,jff,kff)
   implicit none
   real, intent(in)    :: val1(nr,nt,ny)
   real::r(4,4),t(4),val_tmp
   real::valu
   real::grho,gtem,gye
   integer::iff,jff,kff
   integer::i,j
   
   !density
   do j=1,4
    if(((jff.eq.1).or.(jff.eq.(53-1))).and.((j.eq.1).or.(j.eq.4))) then
     CYCLE
    endif
    do i=1,4
     if(((iff.eq.1).or.(iff.eq.(nt-1))).and.((i.eq.1).or.(i.eq.4))) then
      CYCLE
     endif
     if ((kff.eq.1).or.(kff.eq.(nr-1))) then
      call linear_interpolator_one_d(val1(kff,iff-2+i,jff-2+j),&
      &val1(kff+1,iff-2+i,jff-2+j),grho,val_tmp)
     else
      call CINT(val1(kff-1,iff-2+i,jff-2+j),val1(kff,iff-2+i,jff-2+j),&
      &val1(kff+1,iff-2+i,jff-2+j),val1(kff+2,iff-2+i,jff-2+j),grho,val_tmp)
     end if
     r(j,i)=val_tmp
    end do
   end do
   
   !temperature
   do j=1,4
    if(((jff.eq.1).or.(jff.eq.(53-1))).and.((j.eq.1).or.(j.eq.4))) then
     CYCLE
    endif
    if ((iff.eq.1).or.(iff.eq.(nt-1))) then
     call linear_interpolator_one_d(r(j,2),r(j,3),gtem,val_tmp)
    else
     call CINT(r(j,1),r(j,2),r(j,3),r(j,4),&
     &gtem,val_tmp)
    end if
    t(j)=val_tmp
   end do
   
   !proton fraction
   if((jff.eq.1).or.(jff.eq.(53-1))) then
   	call linear_interpolator_one_d(t(2),t(3),gye,valu)
   else
    call CINT(t(1),t(2),t(3),t(4),gye,valu)
   endif
   
  end subroutine cubic_interpolator
  
  
  subroutine cubic_readeos(tin,yin,rin,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm&
   &,cont)
   
   implicit none
   integer:: in_t=109, in_b=328
   real::tin,yin,rin,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm
   integer::i,j,k,iff,jff,kff,cont
   real:: grho,gtem,gye
   real tup,tlow,yup,ylow,rup,rlow
   
   !test boundries
   cont=0
   tup=74.989
   tlow=0.0
   if(tin.ge.tup) then
   	write(6,*) 'Invalid High Temperature',tin
    cont=1
    return
   elseif(tin.lt.tlow) then
    write(6,*) 'Invalid Low Temperature'
    cont=1
    return
   endif
   yup=0.56
   ylow=0.0
   if(yin.ge.yup.or.yin.lt.ylow) then
    write(6,*) 'Invalid proton fraction'
    cont=2
    return
   endif
   rup=1.496
   !rlow=10^{-8}
   rlow=0.00000001
   if(rin.ge.rup.or.rin.lt.rlow) then
    write(6,*) 'Invalid density',rin
    read(5,*)
    cont=3
    return
   endif
   
   do i=2,in_t
   	if(tin.ge.t1(1,i-1,1).and.tin.lt.t1(1,i,1)) then
	 iff = i-1
	 do j = 2,53
      if(yin.ge.y1(1,1,j-1).and.yin.lt.y1(1,1,j)) then
	   jff = j-1
	    do k = 2,in_b
         if(rin.ge.d1(k-1,1,1).and.rin.lt.d1(k,1,1)) then
	      kff = k-1
	      !30
	      grho = (log10(rin) - d2(kff,iff,jff))/(d2(kff+1,iff,jff)&
	      &	-d2(kff,iff,jff))
	      
	      If(iff.eq.1) then
	       gtem = (tin - t1(kff,iff,jff))/(t1(kff,iff+1,jff)-&
	       &	  t1(kff,iff,jff))
	      else
           gtem = (log10(tin) - t2(kff,iff,jff))/(t2(kff,iff+1,jff)-&
           &	  t2(kff,iff,jff))
          endif
          
          gye  = (yin-y1(kff,iff,jff))/(y1(kff,iff,jff+1)-y1(kff,iff,jff))
          
          !interpolating
     
          call cubic_interpolator(fer,f1,grho,gtem,gye,iff,jff,kff)
     
          call cubic_interpolator(pre,p1,grho,gtem,gye,iff,jff,kff)
     
          call cubic_interpolator(ent,s1,grho,gtem,gye,iff,jff,kff)
     
          ene = fer + tin*ent
          !call interpolator(ene,e1,grho,gtem,gye,iff,jff,kff)
     
!          call cubic_interpolator(cnu,cn1,grho,gtem,gye,iff,jff,kff)
     
!          call cubic_interpolator(cpu,cp1,grho,gtem,gye,iff,jff,kff)
     
!          call cubic_interpolator(ceu,ce1,grho,gtem,gye,iff,jff,kff)
     
!          cnv = cpu + ceu - cnu
     
!          call cubic_interpolator(anu,an1,grho,gtem,gye,iff,jff,kff)
     
!          call cubic_interpolator(pnu,pn1,grho,gtem,gye,iff,jff,kff)
     
!          call cubic_interpolator(xnu,xn1,grho,gtem,gye,iff,jff,kff)
     
!          call cubic_interpolator(xpu,xp1,grho,gtem,gye,iff,jff,kff)
     
!          call cubic_interpolator(xau,xa1,grho,gtem,gye,iff,jff,kff)
     
!          call cubic_interpolator(xiu,xi1,grho,gtem,gye,iff,jff,kff)
     
!          call cubic_interpolator(emm,em1,grho,gtem,gye,iff,jff,kff)
     
!          write(*,*) 'interpolation completed'
          
          return
          
	    endif
       enddo
	  endif
	 enddo
	endif
   enddo
   
  end subroutine cubic_readeos
  
  
  subroutine ideal_eos(rin,tin,yin,pre)
   real::rin,yin,tin
   real::mh,kb,pre,ene,mu
   real::rin_tmp,tin_tmp,pre_tmp
  
  
   mh=1.67*1.e-24
   kb=1.38*1.e-16
   call cubic_readeos_simp_2(tin,yin,1.0001*1.e-8,pre,ene)
   mu=(1.0001*1.e-8*(amu/(fmtocm**3)))*kb*(tin*MevtoK)/((pre*Mevtoerg/(fmtocm**3))*mh)

   rin_tmp=rin*(amu/(fmtocm**3))
   tin_tmp=tin*MevtoK
   pre_tmp=rin_tmp*kb*tin_tmp/(mu*mh)
   pre=pre_tmp/(Mevtoerg/(fmtocm**3))
  
  end subroutine ideal_eos
  
  
  subroutine find_cv(rin,tin,yin,cv,ene)
   real, intent(in) ::tin,yin,rin
!   real, intent(out)::cv
   real::fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm
   real::tin_t1,ent_t1,par_st
   integer::cont
   real::cv
   
   tin_t1=tin*1.001
   
   call cubic_readeos(tin_t1,yin,rin,fer,pre,ent_t1,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu&
    &,xau,xiu,emm,cont)
   call cubic_readeos(tin,yin,rin,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm&
    &,cont)

   call partial(ent,ent_t1,tin,tin_t1,par_st)
   cv=par_st*tin
  
  end subroutine
  
  
  subroutine temp_step(tin,yin,rin,par_rt,par_tt)
  !get_dTdt
  !drhodt,dTdt
   real::tin,yin,rin,par_rt
   real::tin_t1,pre_t1,pre
   real::cv
   real::par_tt,par_pt
   real::fer,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,&
   &xpu,xau,xiu,emm,spsound
   integer::cont
   
   tin_t1=tin*1.0001
   
   if (rin>1.e-8) then
    call cubic_readeos(tin_t1,yin,rin,fer,pre_t1,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,&
    &xpu,xau,xiu,emm,cont)
    call cubic_readeos(tin,yin,rin,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,&
    &xpu,xau,xiu,emm,cont)
   
    call find_cv(rin,tin,yin,cv,ene)
   
    call partial(pre,pre_t1,tin,tin_t1,par_pt)
!   call partial(ent,ent_t1,tin,tin_t1,par_rt)
	
   else
    call eos_shen_NL3(rin,tin,yin,pre,spsound)
    call eos_shen_NL3(rin,tin_t1,yin,pre_t1,spsound)
    call partial(pre,pre_t1,tin,tin_t1,par_pt)
    
    call cubic_readeos(tin,yin,1.000001*1.e-8,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,&
    &xpu,xau,xiu,emm,cont)
    
    call find_cv(1.000001*1.e-8,tin,yin,cv,ene)
   end if
   
   par_tt=tin/cv*(par_pt)*(1./(rin**2))*(par_rt)
  
  end subroutine
  
  
  subroutine sound_speed_clas(rin,tin,yin,spsound)
  real::rin,tin,yin,pre,spsound,rin_r1,pre_r1,par_pr
  real::rin_tmp,rin_r1_tmp,pre_tmp,pre_r1_tmp
  
  rin_r1=rin*1.0001
  
  call cubic_readeos_simp(tin,yin,rin,pre)
  call cubic_readeos_simp(tin,yin,rin_r1,pre_r1)
  
  rin_tmp=rin*(amu/(fmtocm**3))
  rin_r1_tmp=rin_r1*(amu/(fmtocm**3))
  pre_tmp=pre*Mevtoerg/(fmtocm**3)
  pre_r1_tmp=pre_r1*Mevtoerg/(fmtocm**3)
  
  call partial(pre_tmp,pre_r1_tmp,rin_tmp,rin_r1_tmp,par_pr)
  
  spsound=sqrt(ABS(par_pr))
  
  end subroutine
  
  
  subroutine sound_speed_rel(rin,tin,yin,spsound)
  real::rin,tin,yin,spsound,pre,ene,rin_r1,pre_r1,ene_r1,e,e_r1,par_pe
  real::rin_tmp,rin_r1_tmp,pre_tmp,pre_r1_tmp,ene_tmp,ene_r1_tmp
  real::fer,ent,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm
  integer::cont
  real::light_speed
  
  rin_r1=rin*1.0001
  
  call cubic_readeos(tin,yin,rin,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm&
   &,cont)
  call cubic_readeos(tin,yin,rin_r1,fer,pre_r1,ent,ene_r1,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm&
   &,cont)
   
  rin_tmp=rin*(amu/(fmtocm**3))
  rin_r1_tmp=rin_r1*(amu/(fmtocm**3))
  pre_tmp=pre*Mevtoerg/(fmtocm**3)
  pre_r1_tmp=pre_r1*Mevtoerg/(fmtocm**3)
  ene_tmp=ene*(Mevtoerg)/(amu)
  ene_r1_tmp=ene_r1*(Mevtoerg)/(amu)
  
  light_speed=3.e10
  
  e=rin_tmp*(light_speed**2+ene_tmp)
  e_r1=rin_r1_tmp*(light_speed**2+ene_r1_tmp)
  
  call partial(pre_tmp,pre_r1_tmp,e,e_r1,par_pe)
  
  spsound=sqrt(ABS(light_speed**2*par_pe))
  
  end subroutine
  
  
  subroutine sound_speed_comb(rin,tin,yin,spsound)
  real::rin,tin,yin,spsound
  real::turning_point,rin_tmp
  
  rin_tmp=rin*(amu/(fmtocm**3))
  turning_point=(Log10(tin)+2.373)/0.331
  
  if (rin>1.e-1) then
   call sound_speed_rel(rin,tin,yin,spsound)
  else if (Log10(rin_tmp)>turning_point) then
   call sound_speed_clas(rin,tin,yin,spsound)
  else
   call sound_speed_clas(10**(turning_point)*((fmtocm**3)/amu),tin,yin,spsound)
  end if
  
  end subroutine
  
  
  subroutine partial(y,nxt_y,x,nxt_x,result)
   real, intent(in) ::y,nxt_y,x,nxt_x
   real, intent(out)::result
   
   result=(y-nxt_y)/(x-nxt_x)
   
  end subroutine partial
  
  
  subroutine cubic_readeos_simp(tin,yin,rin,pre)
   
   implicit none
   real::tin,yin,rin,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm
   integer::cont
   
   call cubic_readeos(tin,yin,rin,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm&
    &,cont)
   
  end subroutine cubic_readeos_simp
  
  
  subroutine cubic_readeos_simp_2(tin,yin,rin,pre,ene)
   
   implicit none
   real::tin,yin,rin,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm
   integer::cont
   
   call cubic_readeos(tin,yin,rin,fer,pre,ent,ene,cnu,cpu,ceu,cnv,anu,pnu,xnu,xpu,xau,xiu,emm&
    &,cont)
   
  end subroutine cubic_readeos_simp_2
  
  
  subroutine eos_shen_get_dTdu(rin_cgs,temp_cgs,yin,dTdui)
    implicit none
    real::rin_cgs,temp_cgs,yin
    real::dTdui
    real::cv,rin,temp_t1_cgs,ene,pre,pre_t1,pre_tmp,pre_t1_tmp,dlnPdlnT,temp,temp_t1
  
    rin=rin_cgs/(amu/(fmtocm**3))
    temp_t1_cgs=temp_cgs*1.0001
    temp=temp_cgs/MevtoK
    temp_t1=temp_t1_cgs/MevtoK
    call cubic_readeos_simp_2(temp,yin,rin,pre,ene)
    call cubic_readeos_simp(temp_t1,yin,rin,pre_t1)
    pre_tmp=pre*(Mevtoerg/(fmtocm**3))
    pre_t1_tmp=pre_t1*(Mevtoerg/(fmtocm**3))
    call partial(LOG(pre_tmp),LOG(pre_t1_tmp),LOG(temp_cgs),LOG(temp_t1_cgs),dlnPdlnT)
    
    call find_cv(rin,temp,yin,cv,ene)
     
     dTdui=1./cv*ABS(dlnPdlnT)
  end subroutine eos_shen_get_dTdu

end module eos_shen