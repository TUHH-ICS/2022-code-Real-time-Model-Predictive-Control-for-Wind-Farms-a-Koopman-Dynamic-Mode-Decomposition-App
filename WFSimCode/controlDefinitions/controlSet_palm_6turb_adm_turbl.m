function turbInputSet = controlSet_palm_6turb_adm_turbl(Wp)

if ~nargin % enable running this as a script
    Wp.turbine.Crx = nan(6,1);
end
    turbInputSet = struct();
    
    addpath([fileparts(which(mfilename)) '/LES_database']); % Add LES database
    loadedDB = load('DB_palm_6turb_adm_turbl.mat');
    
    turbInputSet.t = [loadedDB.turbInput.t];
    turbInputSet.phi = [loadedDB.turbInput.phi];
    turbInputSet.CT_prime = [loadedDB.turbInput.CT_prime];
    turbInputSet.interpMethod = 'lin'; % Linear interpolation over time
    
    if length(Wp.turbine.Crx) ~= size(turbInputSet.phi,1)
        error('Number of turbines in layout does not match your controlSet.');
    end
end