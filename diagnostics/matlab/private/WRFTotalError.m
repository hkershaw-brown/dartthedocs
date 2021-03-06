function WRFTotalError( pinfo )
%% -------------------------------------------------------------------
% Plot the total area-weighted error for each variable.
%---------------------------------------------------------------------

%% DART software - Copyright UCAR. This open source software is provided
% by UCAR, "as is", without charge, subject to all terms of use at
% http://www.image.ucar.edu/DAReS/DART/DART_download
%
% DART $Id$

%----------------------------------------------------------------------
%
%----------------------------------------------------------------------

for ivar=1:pinfo.num_state_vars,

   varname = pinfo.vars{ivar};

   rmse = zeros(pinfo.time_series_length,1);
   sprd = zeros(pinfo.time_series_length,1);

   for itime=1:pinfo.time_series_length,

      fprintf('Processing %s timestep %d of %d ...\n', ...
                varname, itime, pinfo.time_series_length)

      truth  = get_hyperslab('fname',pinfo.truth_file, 'varname',varname, ...
                   'copyindex',truth_index, 'timeindex',pinfo.truth_time(1)+itime-1);
      ens    = get_hyperslab('fname',pinfo.diagn_file, 'varname',varname, ...
                   'copyindex',ens_mean_index, 'timeindex',pinfo.diagn_time(1)+itime-1);
      spread = get_hyperslab('fname',pinfo.diagn_file, 'varname',varname, ...
                   'copyindex',ens_spread_index, 'timeindex',pinfo.diagn_time(1)+itime-1);

      %% Calculate the mean squared error for each level. By construction,
      %  the WRF grid is close enough to equal area for each grid cell.
      %  The simple mean of each level is OK.

      msqe = mean( (truth(:) - ens(:)) .^2 ); % mean squared error
      msqs = mean(       spread(:)     .^2 ); % mean squared spread

      %% Take the square root of the mean of all levels
      rmse(itime) = sqrt(msqe);
      sprd(itime) = sqrt(msqs);

   end % loop over time

   %-------------------------------------------------------------------
   % Each variable in its own figure window
   %-------------------------------------------------------------------
   figure(ivar); clf;
      varunits = ncreadatt(pinfo.truth_file, pinfo.vars{ivar}, 'units');

      plot(pinfo.time,rmse,'-', pinfo.time,sprd,'--')

      s{1} = sprintf('time-mean Ensemble Mean error  = %f', mean(rmse));
      s{2} = sprintf('time-mean Ensemble Spread = %f',      mean(sprd));

      h = legend(s); legend(h,'boxoff')
      grid on;
      xdates(pinfo.time)
      ylabel(sprintf('global-area-weighted rmse (%s)',varunits))
      s1 = sprintf('%s %s Ensemble Mean', pinfo.model,pinfo.vars{ivar});
      title({s1,pinfo.diagn_file},'interpreter','none','fontweight','bold')

end % loop around variables

clear truth ens spread err XY_spread


function xdates(dates)
if (length(get(gca,'XTick')) > 6)
   datetick('x','mm.dd.HH','keeplimits'); % 'mm/dd'
   monstr = datestr(dates(1),31);
   xlabelstring = sprintf('month/day/HH - %s start',monstr);
else
   datetick('x',31,'keeplimits'); %'yyyy-mm-dd HH:MM:SS'
   monstr = datestr(dates(1),31);
   xlabelstring = sprintf('%s start',monstr);
end
xlabel(xlabelstring)


% <next few lines under version control, do not edit>
% $URL$
% $Revision$
% $Date$
