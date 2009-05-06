! Data Assimilation Research Testbed -- DART
! Copyright 2004-2007, Data Assimilation Research Section
! University Corporation for Atmospheric Research
! Licensed under the GPL -- www.gpl.org/licenses/gpl.html

program convert_L2b

! <next few lines under version control, do not edit>
! $URL$
! $Id$
! $Revision$
! $Date$

! Initial program to read the raw ocean observations and insert them
! into an observation sequence. To make things easy ... we will mandate
! an assimilatin interval of 1 day - so all observations will be
! redefined to occur at NOON on the day they were observed.

use types_mod,        only : r8, deg2rad, PI
use obs_sequence_mod, only : obs_sequence_type, write_obs_seq, &
                             static_init_obs_sequence, destroy_obs_sequence
use quikscat_JPL_mod, only : real_obs_sequence, read_qscat2b, orbit_type, &
                             create_output_filename
use    utilities_mod, only : initialize_utilities, register_module, &
                             do_output, logfileunit, nmlfileunit, &
                             error_handler, timestamp, E_ERR, E_MSG, &
                             find_namelist_in_file, check_namelist_read

implicit none

! ----------------------------------------------------------------------
! Declare local parameters
! ----------------------------------------------------------------------

character(len=256)      :: datafile, output_name, dartfile, string1
type(orbit_type)        :: orbit
type(obs_sequence_type) :: seq

integer :: io, iunit

! version controlled file description for error handling, do not edit
character(len=128), parameter :: &
   source   = "$URL$", &
   revision = "$Revision$", &
   revdate  = "$Date$"

! ----------------------------------------------------------------------
! Declare namelist parameters
! ----------------------------------------------------------------------
        
character(len=128) ::  l2b_file = ''
character(len=128) ::   datadir = '.'
character(len=128) :: outputdir = '.'

real(r8) :: lon1 =   0.0_r8,  &   !  lower longitude bound
            lon2 = 360.0_r8,  &   !  upper longitude bound 
            lat1 = -90.0_r8,  &   !  lower latitude bound
            lat2 =  90.0_r8       !  upper latitude bound

namelist /convert_L2b_nml/ l2b_file, datadir, outputdir, &
                           lon1, lon2, lat1, lat2

! ----------------------------------------------------------------------
! start of executable program code
! ----------------------------------------------------------------------

call initialize_utilities('convert_L2b')
call register_module(source,revision,revdate)

! Initialize the obs_sequence module ...

call static_init_obs_sequence()

!----------------------------------------------------------------------
! Read the namelist
!----------------------------------------------------------------------

call find_namelist_in_file('input.nml', 'convert_L2b_nml', iunit)
read(iunit, nml = convert_L2b_nml, iostat = io)
call check_namelist_read(iunit, io, 'convert_L2b_nml')

! Record the namelist values used for the run ...
write(nmlfileunit, nml=convert_L2b_nml)
write(    *      , nml=convert_L2b_nml)

call create_output_filename(l2b_file, output_name)
datafile = trim(  datadir)//'/'//trim(l2b_file)
dartfile = trim(outputdir)//'/'//trim(output_name)

call read_qscat2b(datafile, orbit)   ! read from HDF file into a structure
seq = real_obs_sequence(orbit, lon1, lon2, lat1, lat2) ! convert structure to a sequence
call write_obs_seq(seq, dartfile)
call destroy_obs_sequence(seq)       ! release the memory of the seq
call timestamp(source,revision,revdate,'end') ! close the log file

end program convert_L2b
