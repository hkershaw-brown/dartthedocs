module assim_tools_mod
!
! <next four lines automatically updated by CVS, do not edit>
! $Source$ 
! $Revision$ 
! $Date$ 
! $Author$ 
!
! A variety of operations required by assimilation.

use types_mod
!!!use obs_mod,        only : num_obs, obs_var
use utilities_mod,  only : file_exist, open_file, check_nml_error, &
                           close_file
!                           print_version_number, close_file
use sort_mod,       only : index_sort

! Added 22 January, 2001 to duplicate observations no matter what else is
! done with random number generator. Allows clear enkf_2d comparisons.

use random_seq_mod, only : random_gaussian, random_seq_type, &
                           init_random_seq, random_uniform

logical :: first_ran_call = .true., first_inc_ran_call = .true.

type (random_seq_type) :: ran_seq, inc_ran_seq

private

public read_restart, write_restart, assim_tools_init, &
   obs_increment, obs_increment2, obs_increment3, obs_increment4, &
   update_from_obs_inc, local_update_from_obs_inc, robust_update_from_obs_inc, &
   obs_inc_index, obs_inc4_index, &
   linear_obs_increment, linear_update_from_obs_inc

!============================================================================

!---- namelist with default values

real(r8) :: cor_cutoff = 0.0_r8

namelist / assim_tools_nml / cor_cutoff

!---- module name and version number
character(len = 11), parameter :: module_name = 'assim_tools'
character(len = 12), parameter :: vers_num = '10/03/2000'

!============================================================================

contains



subroutine assim_tools_init()
!============================================================================
! subroutine assim_tools_init()
!

implicit none

integer :: unit, ierr, io

! Read namelist for run time control

if(file_exist('input.nml')) then
   unit = open_file(file = 'input.nml', action = 'read')
   ierr = 1

! TJH Coding Standard does not allow use of the "end=" construct.
!
!  do while(ierr /= 0)
!     read(unit, nml = assim_tools_nml, iostat = io, end = 11)
!     ierr = check_nml_error(io, 'assim_tools_nml')
!  enddo
!11 continue

   READBLOCK: do while(ierr /= 0)
      read(unit, nml = assim_tools_nml, iostat = io)
      if ( io < 0 ) exit READBLOCK          ! end-of-file
      ierr = check_nml_error(io, 'assim_tools_nml')
   enddo READBLOCK
 
   call close_file(unit)
endif

! TJH 14.03.2002 What do we do if the namelist does not exist?

! Write the namelist to a log file

unit = open_file(file = 'logfile.out', action = 'append')
!call print_version_number(unit, module_name, vers_num)
write(unit, nml = assim_tools_nml)
call close_file(unit)

write(*, *) 'Correlation cutoff in fast_seq_non_identity_prod is ', cor_cutoff

end subroutine assim_tools_init




subroutine read_restart(x, ens, last_step)
!============================================================================
! subroutine read_restart(x, ens, last_step)
!

implicit none

real(r8), intent(inout) :: x(:), ens(:, :)
integer,  intent(inout) :: last_step

integer :: chan

chan = open_file(file = 'restart.in', action = 'read')
read(chan, *) last_step
read(chan, *) ens
read(chan, *) x
write(*, *) 'successfully read x'
call close_file(chan)

end subroutine read_restart



subroutine write_restart(x, ens, last_step)
!========================================================================
! subroutine write_restart(x, ens, last_step)
!

implicit none

real(r8), intent(in) :: x(:), ens(:, :)
integer,  intent(in) :: last_step

integer :: chan

chan = open_file(file = 'restart.out', action = 'write')
write(chan, *) last_step
write(chan, *) ens
write(chan, *) x
call close_file(chan)

end subroutine write_restart



subroutine obs_increment(ens, ens_size, obs, obs_var, obs_inc)
!========================================================================
! subroutine obs_increment(ens, ens_size, obs, obs_var, obs_inc)
!
! EAKF version of obs increment

implicit none

integer, intent(in) :: ens_size
real(r8), intent(in) :: ens(ens_size), obs, obs_var
real(r8), intent(out) :: obs_inc(ens_size)

real(r8) :: ens2(1, ens_size), a, obs_var_inv, cov(1, 1)
real(r8) :: mean(1), prior_mean, prior_cov_inv, new_cov, new_mean
real(r8):: prior_cov, sx, s_x2

integer :: i

! Compute mt_rinv_y (obs error normalized by variance)
obs_var_inv = 1.0 / obs_var

! Compute prior covariance and mean from sample
sx = sum(ens)
s_x2 = sum(ens * ens)
prior_mean = sx / ens_size
prior_cov = (s_x2 - sx**2 / ens_size) / (ens_size - 1)

! TEMPORARY LOOK AT INFLATING HERE; see notes from 12 Sept. 2001
!!!cov = cov * 1.01 OR prior_cov = prior_cov * 1.01

prior_cov_inv = 1.0 / prior_cov
new_cov = 1.0 / (prior_cov_inv + obs_var_inv)

new_mean = new_cov * (prior_cov_inv * prior_mean + obs / obs_var)

a = sqrt(new_cov * prior_cov_inv)

obs_inc = a * (ens - prior_mean) + new_mean - ens

end subroutine obs_increment



subroutine obs_inc_index(ens, ens_size, obs, obs_var, obs_inc, index)
!========================================================================
! subroutine obs_inc_index(ens, ens_size, obs, obs_var, obs_inc, index)
!

! EAKF version of obs increment with closest obs neighbor indexing
! See notes from 14 November, 2001

implicit none

integer, intent(in) :: ens_size
real(r8), intent(in) :: ens(ens_size), obs, obs_var
real(r8), intent(out) :: obs_inc(ens_size)
integer, intent(out) :: index(ens_size)

real(r8) :: ens2(1, ens_size), a, obs_var_inv, cov(1, 1)
real(r8) :: mean(1), prior_mean, prior_cov_inv, new_cov, new_mean
real(r8) :: prior_cov, sx, s_x2
real(r8) :: new_obs(ens_size), min_dist

integer :: i, j

! Compute mt_rinv_y (obs error normalized by variance)
obs_var_inv = 1.0 / obs_var

! Compute the regression directly
sx = sum(ens)
s_x2 = sum(ens * ens)
prior_mean = sx / ens_size
prior_cov = (s_x2 - sx**2 / ens_size) / (ens_size - 1)

prior_cov_inv = 1.0 / prior_cov
new_cov = 1.0 / (prior_cov_inv + obs_var_inv)

new_mean = new_cov * (prior_cov_inv * prior_mean + obs / obs_var)

a = sqrt(new_cov * prior_cov_inv)

new_obs = a * (ens - prior_mean) + new_mean
! For each update ensemble member, find closest original member and an increment
do i = 1, ens_size
   min_dist = dabs(new_obs(i) - ens(1))
   index(i) = 1
   do j = 2, ens_size
      if(dabs(new_obs(i) - ens(j)) < min_dist) then
         min_dist = dabs(new_obs(i) - ens(j))
         index(i) = j
      end if
   end do

! Need signed increment
   obs_inc(i) = new_obs(i) - ens(index(i))
!   write(*, *) i, index(i), real(obs_inc(i)), real(new_obs(i) - ens(i))
end do


end subroutine obs_inc_index



subroutine obs_increment4(ens, ens_size, obs, obs_var, obs_inc)
!========================================================================
! subroutine obs_increment4(ens, ens_size, obs, obs_var, obs_inc)
!

! ENKF version of obs increment

implicit none

integer, intent(in) :: ens_size
real(r8), intent(in) :: ens(ens_size), obs, obs_var
real(r8), intent(out) :: obs_inc(ens_size)

real(r8) :: ens2(1, ens_size), a, obs_var_inv, cov(1, 1)
real(r8) :: mean(1), prior_mean, prior_cov_inv, new_cov, new_mean(ens_size)
real(r8) :: sx, s_x2, prior_cov
real(r8) :: temp_mean, temp_obs(ens_size)
integer :: ens_index(ens_size), new_index(ens_size)

integer :: i

! Compute mt_rinv_y (obs error normalized by variance)
obs_var_inv = 1.0 / obs_var

! Compute prior mean and covariance
sx = sum(ens)
s_x2 = sum(ens * ens)
prior_mean = sx / ens_size
prior_cov = (s_x2 - sx**2 / ens_size) / (ens_size - 1)

prior_cov_inv = 1.0 / prior_cov
new_cov = 1.0 / (prior_cov_inv + obs_var_inv)

! If this is first time through, need to initialize the random sequence
if(first_inc_ran_call) then
   call init_random_seq(inc_ran_seq)
   first_inc_ran_call = .false.
endif

! Generate perturbed obs
do i = 1, ens_size
    temp_obs(i) = random_gaussian(inc_ran_seq, obs, sqrt(obs_var))
end do

! Move this so that it has original obs mean
temp_mean = sum(temp_obs) / ens_size
temp_obs(:) = temp_obs(:) - temp_mean + obs

! Loop through pairs of priors and obs and compute new mean
do i = 1, ens_size
   new_mean(i) = new_cov * (prior_cov_inv * ens(i) + temp_obs(i) / obs_var)
   obs_inc(i) = new_mean(i) - ens(i)
end do

! Try sorting to make increments as small as possible
!call index_sort(ens, ens_index, ens_size)
!call index_sort(new_mean, new_index, ens_size)
!do i = 1, ens_size
!   obs_inc(ens_index(i)) = new_mean(new_index(i)) - ens(ens_index(i))
!end do

end subroutine obs_increment4



subroutine obs_inc4_index(ens, ens_size, obs, obs_var, obs_inc, index)
!========================================================================
! subroutine obs_inc4_index(ens, ens_size, obs, obs_var, obs_inc, index)

! ENKF version of obs increment
! This is the version that uses local linear updates by finding nearest
! neighbor and increment from that neighbor.

implicit none

integer, intent(in) :: ens_size
real(r8), intent(in) :: ens(ens_size), obs, obs_var
real(r8), intent(out) :: obs_inc(ens_size)
integer, intent(out) :: index(ens_size)

real(r8) :: ens2(1, ens_size), a, obs_var_inv, cov(1, 1)
real(r8) :: mean(1), prior_mean, prior_cov_inv, new_cov, new_mean(ens_size)
real(r8) :: sx, s_x2, prior_cov
real(r8) :: temp_mean, temp_obs(ens_size), min_dist
integer :: ens_index(ens_size), new_index(ens_size)

integer :: i, j

! Compute mt_rinv_y (obs error normalized by variance)
obs_var_inv = 1.0 / obs_var

! Test of computing directly
sx = sum(ens)
s_x2 = sum(ens * ens)
prior_mean = sx / ens_size
prior_cov = (s_x2 - sx**2 / ens_size) / (ens_size - 1)

prior_cov_inv = 1.0 / prior_cov
new_cov = 1.0 / (prior_cov_inv + obs_var_inv)

! If this is first time through, need to initialize the random sequence
if(first_inc_ran_call) then
   call init_random_seq(inc_ran_seq)
   first_inc_ran_call = .false.
endif

! Generate perturbed obs
do i = 1, ens_size
    temp_obs(i) = random_gaussian(inc_ran_seq, obs, sqrt(obs_var))
end do
! Move this so that it has original obs mean
temp_mean = sum(temp_obs) / ens_size
temp_obs(:) = temp_obs(:) - temp_mean + obs

! Loop through pairs of priors and obs and compute new mean
do i = 1, ens_size
   new_mean(i) = new_cov * (prior_cov_inv * ens(i) + temp_obs(i) / obs_var)
end do

! For each update ensemble member, find closest original member and an increment
do i = 1, ens_size
   min_dist = dabs(new_mean(i) - ens(1))
   index(i) = 1
   do j = 2, ens_size
      if(dabs(new_mean(i) - ens(j)) < min_dist) then
         min_dist = dabs(new_mean(i) - ens(j))
         index(i) = j
      end if
   end do

! Need signed increment
   obs_inc(i) = new_mean(i) - ens(index(i))
!   write(*, *) i, index(i), real(obs_inc(i)), real(new_mean(i) - ens(i))
end do

end subroutine obs_inc4_index



subroutine obs_increment3(ens, ens_size, obs, obs_var, obs_inc)
!========================================================================
! subroutine obs_increment3(ens, ens_size, obs, obs_var, obs_inc)
!

! Kernel version of obs increment

implicit none

integer, intent(in) :: ens_size
real(r8), intent(in) :: ens(ens_size), obs, obs_var
real(r8), intent(out) :: obs_inc(ens_size)

real(r8) :: ens2(1, ens_size), a, obs_var_inv, cov(1, 1)
real(r8) :: mean(1), prior_mean, prior_cov_inv, new_cov, prior_cov
real(r8) :: sx, s_x2
real(r8) :: weight(ens_size), new_mean(ens_size)
real(r8) :: cum_weight, total_weight, cum_frac(ens_size)
real(r8) :: unif, norm, new_member(ens_size)

integer :: i, j, kernel, ens_index(ens_size), new_index(ens_size)

! Compute mt_rinv_y (obs error normalized by variance)
obs_var_inv = 1.0 / obs_var

! Compute prior mean and covariance
sx = sum(ens)
s_x2 = sum(ens * ens)
prior_mean = sx / ens_size
prior_cov = (s_x2 - sx**2 / ens_size) / (ens_size - 1)


! For kernels, scale the prior covariance
prior_cov = prior_cov / 10.0

prior_cov_inv = 1.0 / prior_cov

! Compute new covariance once for these kernels
new_cov = 1.0 / (prior_cov_inv + obs_var_inv)

! New mean is computed ens_size times as is weight
do i = 1, ens_size
   new_mean(i) = new_cov*(prior_cov_inv * ens(i) + obs / obs_var)
   weight(i) =  2.71828 ** (-0.5 * (ens(i)**2 * prior_cov_inv + &
      obs**2 * obs_var_inv - new_mean(i)**2 / new_cov))
end do

! Compute total weight
total_weight = sum(weight)
cum_weight = 0.0
do i = 1, ens_size
   cum_weight = cum_weight + weight(i)
   cum_frac(i) = cum_weight / total_weight
end do

! If this is first time through, need to initialize the random sequence
if(first_inc_ran_call) then
   call init_random_seq(inc_ran_seq)
   first_inc_ran_call = .false.
endif

! Generate a uniform random number and a Gaussian for each new member
do i = 1, ens_size
   unif = random_uniform(inc_ran_seq)
! Figure out which kernel it's in
   do j = 1, ens_size
      if(unif < cum_frac(j)) then
         kernel = j
         goto 10
      end if
   end do
10 continue

! Next calculate a unit normal in this kernel
   norm = random_gaussian(inc_ran_seq, dble(0.0), sqrt(new_cov))
! Now generate the new ensemble member
   new_member(i) = new_mean(kernel) + norm
end do

! Try sorting to make increments as small as possible
call index_sort(ens, ens_index, ens_size)
call index_sort(new_member, new_index, ens_size)

do i = 1, ens_size
   obs_inc(ens_index(i)) = new_member(new_index(i)) - ens(ens_index(i))
end do

end subroutine obs_increment3



subroutine obs_increment2(ens, ens_size, obs, obs_var_in, obs_inc)
!========================================================================
! subroutine obs_increment2(ens, ens_size, obs, obs_var_in, obs_inc)
!

! This is a research version of obs increment using generalized 
! distributions. Should not be used in present from.

implicit none

integer, intent(in) :: ens_size
real(r8), intent(in) :: ens(ens_size), obs, obs_var_in
real(r8), intent(out) :: obs_inc(ens_size)

real(r8) :: ens2(1, ens_size), a, obs_var_inv, cov(1, 1)
real(r8) :: mean(1), prior_mean, prior_cov_inv, new_cov, new_mean
real(r8) :: prior_cov, sx, s_x2

integer, parameter :: num = 10000
integer :: i, index, cur_index, j , ind_sort(ens_size)
real(r8) :: tot_dense, loc(ens_size), target
real(r8) :: obs_dense(num), state_dense(num), dense(num)
real(r8) :: cum_dense(0:num) 
real(r8) :: kernel_var, max, min, range, x(num)
real(r8) :: min_ens, min_obs, max_ens, max_obs


real(r8) :: obs_var


!!! TEST, GET RID OF THIS
obs_var = 1e10


! Compute mt_rinv_y (obs error normalized by variance)
obs_var_inv = 1.0 / obs_var

! Need to compute the prior covariance and mean; copy to 2d for now but
! get rid of this step at some point; just fits interface
!ens2(1, :) = ens
!call sample_cov(ens2, 1, ens_size, cov, xmean = mean)
!prior_mean = mean(1)
!prior_cov = cov(1, 1)


! Test of computing directly
sx = sum(ens)
s_x2 = sum(ens * ens)
prior_mean = sx / ens_size
prior_cov = (s_x2 - sx**2 / ens_size) / (ens_size - 1)


prior_cov_inv = 1.0 / prior_cov

! Need to fix a better kernel width later!!!!!
kernel_var = prior_cov / 5.0

! WARNING: NEED TO SORT AND GO

! Dumbest possible way, just partition and search
! For now, do 1 sd past max and min
max = maxval(ens) + sqrt(prior_cov)
min = minval(ens) - sqrt(prior_cov)

!!!max_ens = maxval(ens) + sqrt(prior_cov)
!!!max_obs = obs + 2.0 * sqrt(obs_var)
!!!if(max_ens > max_obs) then
!!!   max = max_ens
!!!else
!!!   max = max_obs
!!!endif

!!!min_ens = minval(ens) - sqrt(prior_cov)
!!!min_obs = obs - 2.0 * sqrt(obs_var)
!!!if(min_ens < min_obs) then
!!!   min = min_ens
!!!else
!!!   min = min_obs
!!!endif

range = max - min

!write(*, *) 'min, max, range ', real(min), real(max), real(range)
!write(*, *) 'obs . var ', obs, obs_var

cum_dense(0) = 0

do i = 1, num
   x(i) = min + (i - 1.0) * range / (num - 1.0)
   obs_dense(i) = exp((x(i) - obs)**2 / (-2. * obs_var))
   state_dense(i) = 0.0
   do j = 1, ens_size
      state_dense(i) = state_dense(i) + exp((x(i) - ens(j))**2 / (-2. * kernel_var))
   end do
   dense(i) = obs_dense(i) * state_dense(i)
   cum_dense(i) = cum_dense(i - 1) + dense(i)
!   write(*, 11) i, real(x(i)), real(obs_dense(i)), real(state_dense(i)), real(dense(i)), cum_dense(i)
11 format(1x, i3, 1x, 5(e10.4, 1x))
end do
tot_dense = cum_dense(num)

! Figure out where the new ensemble members should be located
! Problem, outside of boxes? Error for now
target = (tot_dense / (ens_size + 1))
if(target < cum_dense(1)) then
   write(*, *) 'ERROR:first target outside of box in increment_obs'
end if
target = ens_size * (tot_dense / (ens_size + 1))
if(target > cum_dense(num)) then
   write(*, *) 'ERROR: last target outside of box in increment_obs'
endif

index = 1
do i = 2, num
! At what cumulative density should next point go
   cur_index = index
   do j = cur_index, ens_size
      target = index * (tot_dense / (ens_size + 1))
! Search to see if some should go between next indices
      if(target > cum_dense(i)) goto 10
! Otherwise, in this bin, linearly interpolate
      loc(index) = x(i - 1) + (target - cum_dense(i - 1)) / &
         (cum_dense(i) - cum_dense(i - 1)) * (x(i) - x(i - 1))
!      write(*, *) 'loc ', index, target, loc(index)
! Increment index for position being sought, if all found exit outer loop
      index = index + 1
      if(index > ens_size) goto 20
   end do
10 continue
end do

20 continue

! Sort the ensemble
call index_sort(ens, ind_sort, ens_size)
do i = 1, ens_size
!   write(*, *) i, ens(ind_sort(i)), loc(i)
end do

do i = 1, ens_size
   obs_inc(ind_sort(i)) = loc(i) - ens(ind_sort(i))
end do

do i = 1, ens_size
!   write(*, *) i, ens(i), obs_inc(i)
end do

if(1 == 1) stop

end subroutine obs_increment2



subroutine update_from_obs_inc(obs, obs_inc, state, ens_size, &
               state_inc, cov_factor)
!========================================================================
! subroutine update_from_obs_inc(obs, obs_inc, state, ens_size, &
!                state_inc, cov_factor)
!

! Does linear regression of a state variable onto an observation and
! computes state variable increments from observation increments

implicit none

integer, intent(in) :: ens_size
real(r8), intent(in) :: obs(ens_size), obs_inc(ens_size)
real(r8), intent(in) :: state(ens_size), cov_factor
real(r8), intent(out) :: state_inc(ens_size)

real(r8) :: sum_x, sum_y, sum_xy, sum_x2, reg_coef

! For efficiency, just compute regression coefficient here

sum_x  = sum(obs)
sum_y  = sum(state)
sum_xy = sum(obs * state)
sum_x2 = sum(obs * obs)

reg_coef = (ens_size * sum_xy - sum_x * sum_y) / (ens_size * sum_x2 - sum_x**2)

state_inc = cov_factor * reg_coef * obs_inc

end subroutine update_from_obs_inc



subroutine robust_update_from_obs_inc(obs, obs_inc, state, ens_size, &
                                      state_inc, cov_factor, index_in)
!========================================================================
! subroutine robust_update_from_obs_inc(obs, obs_inc, state, ens_size, &
!                                       state_inc, cov_factor, index_in)
!

! Does a robust linear regression of a state variable onto an observation
! variable. Not rigorously tested at this point.

implicit none

integer, intent(in) :: ens_size
integer, intent(in), optional :: index_in(ens_size)
real(r8), intent(in) :: obs(ens_size), obs_inc(ens_size)
real(r8), intent(in) :: state(ens_size), cov_factor
real(r8), intent(out) :: state_inc(ens_size)

real(r8) :: ens(2, ens_size), cov(2, 2), reg
real(r8) :: y_lo, y_hi, x_lo, x_hi
integer :: index(ens_size), i
integer :: lo_start, lo_end, hi_start, hi_end, lo_size, hi_size

! Need to sort the observations to be able to find local structure
! For efficiency, would like to sort this only once in main program
if(present(index_in)) then
   index = index_in
else
   call index_sort(obs, index, ens_size)
endif

! Create combined matrix for covariance
do i = 1, ens_size
   ens(1, i) = state(index(i))
   ens(2, i) = obs(index(i))
end do

! Get mean values of lower and upper half of data sorted by index
!lo_start = 1
lo_start = ens_size / 8
lo_end = ens_size / 2
!lo_end = 3 * ens_size / 8
lo_size = lo_end - lo_start + 1
hi_start = ens_size / 2 + 1
!hi_start = 5 * ens_size / 8
!hi_end = ens_size
hi_end = 7 * ens_size / 8
hi_size = hi_end - hi_start + 1

! Method 1: use means of data halves sorted by obs
!y_lo = sum(ens(2, lo_start:lo_end)) / lo_size
!y_hi = sum(ens(2, hi_start:hi_end)) / hi_size
x_lo = sum(ens(1, lo_start:lo_end)) / lo_size
x_hi = sum(ens(1, hi_start:hi_end)) / hi_size



! Method 2: median values of data halves???;  unstable when used for x
y_lo = ens(2, ens_size / 4)
y_hi = ens(2, 3 * ens_size / 4)
!x_lo = ens(1, ens_size / 4)
!x_hi = ens(1, 3 * ens_size / 4)

reg = (x_hi - x_lo) / (y_hi - y_lo)

state_inc = cov_factor * reg * obs_inc

end subroutine robust_update_from_obs_inc



subroutine local_update_from_obs_inc(obs, obs_inc, state, ens_size, &
                     state_inc, cov_factor, half_num_neighbors, index_in)
!========================================================================
! subroutine local_update_from_obs_inc(obs, obs_inc, state, ens_size, &
!                      state_inc, cov_factor, half_num_neighbors, index_in)
!

! First stab at doing local linear regression on a set of num_neighbors
! points around a particular obs.

implicit none

integer, intent(in) :: ens_size, half_num_neighbors
integer, intent(in), optional :: index_in(ens_size)
real(r8), intent(in) :: obs(ens_size), obs_inc(ens_size)
real(r8), intent(in) :: state(ens_size), cov_factor
real(r8), intent(out) :: state_inc(ens_size)

real(r8) :: ens(2, ens_size), cov(2, 2), y2(ens_size), xy(ens_size)
real(r8) :: sx, sy, s_y2, sxy, reg
integer :: index(ens_size), i, lower, upper, num_neighbors

! Make sure num_neighbors isn't too big to make sense
num_neighbors = 2 * half_num_neighbors
if(num_neighbors > ens_size - 1) then
   write(*, *) 'num_neighbors too big in local_update_from_obs_inc'
   stop
endif

! Need to sort the observations to be able to find local structure
! For efficiency, would like to sort this only once in main program
if(present(index_in)) then
   index = index_in
else
   call index_sort(obs, index, ens_size)
endif


! Temporary look at sorting on data, not obs
! Seems to work much better for original L96 cases
call index_sort(state, index, ens_size)




! Load up the ensemble array to have state and obs sorted by obs
do i = 1, ens_size
   ens(1, i) = state(index(i))
   ens(2, i) = obs(index(i))
!   write(*, *) 'state obs ', i, real(ens(1, i)), real(ens(2, i))
end do

! Do initial preparation for repeated regressions
xy = ens(1, :) * ens(2, :)
y2 = ens(2, :) ** 2

! Loop through to use nearest num_neighbors points for regression
do i = 1, ens_size
   if(i == 1 .or. (i > half_num_neighbors .and. &
      i <= ens_size - half_num_neighbors)) then
      lower = i - half_num_neighbors
      if(lower < 1) lower = 1
      if(lower > ens_size - num_neighbors) lower = ens_size - num_neighbors
      upper = lower + num_neighbors
!      write(*, *) 'upper lower ', i,lower, upper

      sx = sum(ens(1, lower:upper))
      sy = sum(ens(2, lower:upper))
      s_y2 = sum(y2(lower:upper))
      sxy = sum(xy(lower:upper))
      reg = (sxy - sx * sy / (num_neighbors + 1)) / &
             (s_y2 - sy**2 / (num_neighbors + 1))
!      write(*, *) 'reg ', i, real(reg)
   endif
   state_inc(index(i)) = (cov_factor * reg) * obs_inc(index(i))

end do

end subroutine local_update_from_obs_inc


!========================================================================

subroutine linear_obs_increment(ens, ens_size, obs, obs_var, var_inc, mean_inc, sd_ratio)

! EAKF version of obs increment, obs_update_inflate inflates the variance after
! computation of the mean. (See notes from 17-19 Sept. 2002)
! Uses additional linear corrections from notes in early Dec. 2002 plus modified
! mean versus variance delta's from that analysis.

implicit none

integer, intent(in) :: ens_size
double precision, intent(in) :: ens(ens_size), obs, obs_var
double precision, intent(out) :: var_inc(ens_size), mean_inc, sd_ratio

double precision :: a, prior_mean, prior_var, new_mean, new_var, sx, s_x2

! Compute prior variance and mean from sample
sx = sum(ens)
s_x2 = sum(ens * ens)
prior_mean = sx / ens_size
prior_var = (s_x2 - sx**2 / ens_size) / (ens_size - 1)

!!!write(*, *) 'in obs_inc prior, obs_var ', real(prior_var), real(obs_var)

! Compute updated variance and mean
new_var = 1.0 / (1.0 / prior_var + 1.0 / obs_var)
new_mean = new_var * (prior_mean / prior_var + obs / obs_var)

a = sqrt(new_var / prior_var)

!!!write(*, *) 'a in obs_increment is ', a

! Compute the increments for each ensemble member
var_inc = a * (ens - prior_mean) + prior_mean - ens
mean_inc = new_mean - prior_mean

! Return a as sd_ratio
sd_ratio = a

end subroutine linear_obs_increment

!========================================================================


!========================================================================

subroutine linear_update_from_obs_inc(obs, var_inc, mean_inc, state, &
   ens_size, state_inc, cov_factor, sd_ratio)

! Does linear regression of a state variable onto an observation and
! computes state variable increments from observation increments

implicit none

integer, intent(in) :: ens_size
double precision, intent(in) :: obs(ens_size), var_inc(ens_size), mean_inc
double precision, intent(in) :: state(ens_size), cov_factor, sd_ratio
double precision, intent(out) :: state_inc(ens_size)

double precision :: sum_x, sum_y, sum_xy, sum_x2, reg_coef
double precision :: sum_y2, correl, linear_factor

double precision :: new_reg, ybar, yvar, xbar, xyvar



! For efficiency, just compute regression coefficient here
sum_x = sum(obs)
sum_y = sum(state)
sum_xy = sum(obs * state)
sum_x2 = sum(obs * obs)


!------------------------------------------------
! Temporary computation of correlation
!sum_y2 = sum(state * state)

!correl = (ens_size * sum_xy - sum_x * sum_y) / &
!   sqrt((ens_size * sum_x2 - sum_x**2) * (ens_size * sum_y2 - sum_y**2))
!write(*, *) 'correl/factor in update_from is ', real(correl)
!----------------------------------------------------

reg_coef = (ens_size * sum_xy - sum_x * sum_y) / (ens_size * sum_x2 - sum_x**2)

!!!write(*, *) 'update_from_obs_inc reg_coef is ', reg_coef

! Use the full ratio expression from 3 Dec. '02 Notes
if(cov_factor > 0.99999) then
   linear_factor = cov_factor
else
   linear_factor = (sqrt(cov_factor * sd_ratio**2 - cov_factor + 1.0) - 1.0) / &
      (sd_ratio - 1.0)
endif

!!!write(*, *) 'sd ratio ', sd_ratio
!!!write(*, *) 'cov_factor, linear_factor ', cov_factor, linear_factor
!!!write(*, *) 'ratio ', cov_factor / linear_factor

state_inc = linear_factor * reg_coef * var_inc + cov_factor * reg_coef * mean_inc


end subroutine linear_update_from_obs_inc

!========================================================================



!========================================================================
! end module assim_tools_mod
!========================================================================

end module assim_tools_mod
