function dij = matRad_calcParticleDose(ct,stf,pln,cst,multScen)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% matRad particle dose calculation wrapper
% cst
% call
%   dij = matRad_calcParticleDose(ct,stf,pln,cst,visBool)
%
% input
%   ct:         ct cube
%   stf:        matRad steering information struct
%   pln:        matRad plan meta information struct
%   cst:        matRad cst struct
%   multScen:   matRad multiple scnerio struct
%
% output
%   dij:        matRad dij struct
%
% References
%   [1] http://iopscience.iop.org/0031-9155/41/8/005
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Copyright 2015 the matRad development team. 
% 
% This file is part of the matRad project. It is subject to the license 
% terms in the LICENSE file found in the top-level directory of this 
% distribution and at https://github.com/e0404/matRad/LICENSES.txt. No part 
% of the matRad project, including this file, may be copied, modified, 
% propagated, or distributed except according to the terms contained in the 
% LICENSE file.
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% initialize waitbar
figureWait = waitbar(0,'calculate dose influence matrix for particles...');
% prevent closure of waitbar and show busy state
set(figureWait,'pointer','watch');

% meta information for dij
dij.numOfBeams         = pln.numOfBeams;
dij.numOfVoxels        = pln.numOfVoxels;
dij.resolution         = ct.resolution;
dij.numOfRaysPerBeam   = [stf(:).numOfRays];
dij.totalNumOfRays     = sum(dij.numOfRaysPerBeam);
dij.totalNumOfBixels   = sum([stf(:).totalNumOfBixels]);
dij.dimensions         = pln.voxelDimensions;

% set up arrays for book keeping
dij.bixelNum = NaN*ones(dij.totalNumOfRays,1);
dij.rayNum   = NaN*ones(dij.totalNumOfRays,1);
dij.beamNum  = NaN*ones(dij.totalNumOfRays,1);

% Allocate space for dij.physicalDose sparse matrix
for CtScen = 1:multScen.numOfCtScen
    for ShiftScen = 1:multScen.numOfShiftScen
        for RangeShiftScen = 1:multScen.numOfRangeShiftScen  
            
            if multScen.ScenCombMask(CtScen,ShiftScen,RangeShiftScen)
                dij.physicalDose{CtScen,ShiftScen,RangeShiftScen} = spalloc(prod(ct.cubeDim),dij.totalNumOfBixels,1);
            end
            
        end
    end
end

% helper function for energy selection
round2 = @(a,b)round(a*10^b)/10^b;

% Allocate memory for dose_temp cell array
numOfBixelsContainer = ceil(dij.totalNumOfBixels/10);
doseTmpContainer = cell(numOfBixelsContainer,multScen.numOfCtScen,multScen.numOfShiftScen,multScen.numOfRangeShiftScen);
if pln.bioOptimization == true 
    alphaDoseTmpContainer = cell(numOfBixelsContainer,multScen.numOfCtScen,multScen.numOfShiftScen,multScen.numOfRangeShiftScen);
    betaDoseTmpContainer  = cell(numOfBixelsContainer,multScen.numOfCtScen,multScen.numOfShiftScen,multScen.numOfRangeShiftScen);
    for CtScen = 1:multScen.numOfCtScen
        for ShiftScen = 1:multScen.numOfShiftScen
            for RangeShiftScen = 1:multScen.numOfRangeShiftScen  
            
                if multScen.ScenCombMask(CtScen,ShiftScen,RangeShiftScen)
                    dij.mAlphaDose{CtScen,ShiftScen,RangeShiftScen}        = spalloc(prod(ct.cubeDim),dij.totalNumOfBixels,1);
                    dij.mSqrtBetaDose{CtScen,ShiftScen,RangeShiftScen}     = spalloc(prod(ct.cubeDim),dij.totalNumOfBixels,1);
                end
                
            end
        end
    end
end

% Only take voxels inside patient.
V = [cst{:,4}];
V = unique(vertcat(V{:}));

% Convert CT subscripts to linear indices.
[yCoordsV_vox, xCoordsV_vox, zCoordsV_vox] = ind2sub(ct.cubeDim,V);

% load machine file
fileName = [pln.radiationMode '_' pln.machine];
try
   load(fileName);
catch
   error(['Could not find the following machine file: ' fileName ]); 
end

% generates tissue class matrix for biological optimization
if strcmp(pln.bioOptimization,'effect') || strcmp(pln.bioOptimization,'RBExD') ... 
        && strcmp(pln.radiationMode,'carbon')
    fprintf('matRad: loading biological base data... ');
    mTissueClass = zeros(size(V,1),1);
    for i = 1:size(cst,1)
        % find indices of structures related to V
        [~, row] = ismember(vertcat(cst{i,4}{:}),V,'rows');  
        if ~isempty(cst{i,5}) && isfield(cst{i,5},'TissueClass')
            mTissueClass(row) = cst{i,5}.TissueClass;
        else
            mTissueClass(row) = 1;
            fprintf(['matRad: tissue type of ' cst{i,2} ' was set to 1 \n']);
        end
        
        % check consitency of biological baseData and cst settings
        baseDataAlphaBetaRatios = reshape([machine.data(:).alphaBetaRatio],numel(machine.data(1).alphaBetaRatio),size(machine.data,2));
        if norm(baseDataAlphaBetaRatios(cst{i,5}.TissueClass,:) - cst{i,5}.alphaX/cst{i,5}.betaX)>0
            error('biological base data and cst inconsistent\n');
        end
        
    end
    fprintf('done.\n');
end

fprintf('matRad: Particle dose calculation...\n');
counter = 0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i = 1:dij.numOfBeams; % loop over all beams
    
    fprintf(['Beam ' num2str(i) ' of ' num2str(dij.numOfBeams) ': \n']);

    bixelsPerBeam = 0;
    
    % convert voxel indices to real coordinates using iso center of beam i
    for ShiftScen = 1:multScen.numOfShiftScen
        xCoordsV = xCoordsV_vox(:)*ct.resolution.x - (stf(i).isoCenter(1) + multScen.shifts(1,ShiftScen));
        yCoordsV = yCoordsV_vox(:)*ct.resolution.y - (stf(i).isoCenter(2) + multScen.shifts(2,ShiftScen));
        zCoordsV = zCoordsV_vox(:)*ct.resolution.z - (stf(i).isoCenter(3) + multScen.shifts(3,ShiftScen));
        coordsV{ShiftScen}  = [xCoordsV yCoordsV zCoordsV];
    end

    % Set gantry and couch rotation matrices according to IEC 61217
    % Use transpose matrices because we are working with row vectros
    
    % rotation around Z axis (gantry)
    inv_rotMx_XY_T = [ cosd(-pln.gantryAngles(i)) sind(-pln.gantryAngles(i)) 0;
                      -sind(-pln.gantryAngles(i)) cosd(-pln.gantryAngles(i)) 0;
                                                0                          0 1];
    
    % rotation around Y axis (couch)
    inv_rotMx_XZ_T = [cosd(-pln.couchAngles(i)) 0 -sind(-pln.couchAngles(i));
                                              0 1                         0;
                      sind(-pln.couchAngles(i)) 0  cosd(-pln.couchAngles(i))];
                  
    % Rotate coordinates (1st couch around Y axis, 2nd gantry movement)
    for ShiftScen = 1:multScen.numOfShiftScen
        rot_coordsV{ShiftScen} = coordsV{ShiftScen}*inv_rotMx_XZ_T*inv_rotMx_XY_T;

        rot_coordsV{ShiftScen}(:,1) = rot_coordsV{ShiftScen}(:,1)-stf(i).sourcePoint_bev(1);
        rot_coordsV{ShiftScen}(:,2) = rot_coordsV{ShiftScen}(:,2)-stf(i).sourcePoint_bev(2);
        rot_coordsV{ShiftScen}(:,3) = rot_coordsV{ShiftScen}(:,3)-stf(i).sourcePoint_bev(3);
    end
    
    % Calcualte radiological depth cube
    lateralCutoffRayTracing = 50;
    fprintf('matRad: calculate radiological depth cube...');
    [radDepthCube,geoDistCube] = matRad_rayTracing(stf(i),ct,V,lateralCutoffRayTracing,multScen);
    fprintf('done.\n');
    
    % construct binary mask where ray tracing results are available
    for ShiftScen = 1:multScen.numOfShiftScen
        radDepthMask{ShiftScen} = ~isnan(radDepthCube{1,ShiftScen});
    end
    %radDepthIx = ~isnan(radDepthCube);
    %radDepthIx = true(ct.cubeDim);                         % f�r ctScen �berfl�ssig
    %for k = 1:ct.numOfCtScen                               % f�r ctScen �berfl�ssig
    %    radDepthIx = radDepthIx .* isnan(radDepthCube{k}); % f�r ctScen �berfl�ssig
    %end                                                    % f�r ctScen �berfl�ssig
    %radDepthIx = ~radDepthIx;                              % f�r ctScen �berfl�ssig
    
    % Determine lateral cutoff
    fprintf('matRad: calculate lateral cutoff...');
    cutOffLevel = .99;
    visBoolLateralCutOff = 0;
    machine = matRad_calcLateralParticleCutOff(machine,cutOffLevel,stf(i),visBoolLateralCutOff);
    fprintf('done.\n');    
    
    for j = 1:stf(i).numOfRays % loop over all rays
        
        if ~isempty(stf(i).ray(j).energy)
        
            % find index of maximum used energy (round to keV for numerical
            % reasons
            energyIx = max(round2(stf(i).ray(j).energy,4)) == round2([machine.data.energy],4);
            
            maxLateralCutoffDoseCalc = max(machine.data(energyIx).LatCutOff.CutOff);
            
            % Ray tracing for beam i and ray j
            for ShiftScen = 1:multScen.numOfShiftScen
                [ix{ShiftScen},radialDist_sq{ShiftScen},~,~] = matRad_calcGeoDists(rot_coordsV{ShiftScen}, ...
                                                                                   stf(i).sourcePoint_bev, ...
                                                                                   stf(i).ray(j).targetPoint_bev, ...
                                                                                   geoDistCube{ShiftScen}(V), ...
                                                                                   machine.meta.SAD, ...
                                                                                   radDepthMask{ShiftScen}(V), ...
                                                                                   maxLateralCutoffDoseCalc); 
            
                % just use tissue classes of voxels found by ray tracer
                if strcmp(pln.bioOptimization,'effect') || strcmp(pln.bioOptimization,'RBExD') ... 
                     && strcmp(pln.radiationMode,'carbon')
                        mTissueClass_j{ShiftScen} = mTissueClass(ix{ShiftScen},:);
                end
            end
              
            for k = 1:stf(i).numOfBixelsPerRay(j) % loop over all bixels per ray
                
                counter = counter + 1;
                bixelsPerBeam = bixelsPerBeam + 1;
                
                matRad_progress(bixelsPerBeam,stf(i).totalNumOfBixels);
                % update waitbar only 100 times if it is not closed
                if mod(counter,round(dij.totalNumOfBixels/100)) == 0 && ishandle(figureWait)
                    waitbar(counter/dij.totalNumOfBixels,figureWait);
                end
                
                % remember beam and  bixel number
                dij.beamNum(counter)  = i;
                dij.rayNum(counter)   = j;
                dij.bixelNum(counter) = k;

                % find energy index in base data
                energyIx = find(round2(stf(i).ray(j).energy(k),4) == round2([machine.data.energy],4));
                
                for CtScen = 1:multScen.numOfCtScen
                    for ShiftScen = 1:multScen.numOfShiftScen
                        for RangeShiftScen = 1:multScen.numOfRangeShiftScen  
            
                            if multScen.ScenCombMask(CtScen,ShiftScen,RangeShiftScen)
                                
                                % manipulate radDepthCube for range scenarios
                                radDepths = radDepthCube{CtScen,ShiftScen}(V(ix{ShiftScen})) +...                                         % original cube
                                            radDepthCube{CtScen,ShiftScen}(V(ix{ShiftScen}))*multScen.relRangeShifts(RangeShiftScen) +... % rel range shift
                                            multScen.absRangeShifts(RangeShiftScen);                                                      % absolute range shift
                                radDepths(radDepths < 0) = 0;       

                                % find depth depended lateral cut off
                                if cutOffLevel >= 1
                                    currIx = radDepths <= machine.data(energyIx).depths(end) + machine.data(energyIx).offset;
                                elseif cutOffLevel < 1 && cutOffLevel > 0
                                    % perform rough 2D clipping
                                    currIx = radDepths <= machine.data(energyIx).depths(end) + machine.data(energyIx).offset & ...
                                         radialDist_sq{ShiftScen} <= max(machine.data(energyIx).LatCutOff.CutOff.^2);

                                    % peform fine 2D clipping  
                                    if length(machine.data(energyIx).LatCutOff.CutOff) > 1
                                        currIx(currIx) = interp1(machine.data(energyIx).LatCutOff.depths + machine.data(energyIx).offset,...
                                            machine.data(energyIx).LatCutOff.CutOff.^2, radDepths(currIx)) >= radialDist_sq{ShiftScen}(currIx);
                                    end
                                else
                                    error('cutoff must be a value between 0 and 1')
                                end

                                % calculate particle dose for bixel k on ray j of beam i
                                bixelDose = matRad_calcParticleDoseBixel(...
                                    radDepths(currIx), ...
                                    radialDist_sq{ShiftScen}(currIx), ...
                                    stf(i).ray(j).SSD{CtScen,ShiftScen}, ...
                                    stf(i).ray(j).focusIx(k), ...
                                    machine.data(energyIx)); 

                                % Save dose for every bixel in cell array
                                doseTmpContainer{mod(counter-1,numOfBixelsContainer)+1,CtScen,ShiftScen,RangeShiftScen} = sparse(V(ix{ShiftScen}(currIx)),1,bixelDose,prod(ct.cubeDim),1); 

                                if strcmp(pln.bioOptimization,'effect') || strcmp(pln.bioOptimization,'RBExD') ... 
                                    && strcmp(pln.radiationMode,'carbon')
                                    % calculate alpha and beta values for bixel k on ray j of                  
                                    [bixelAlpha, bixelBeta] = matRad_calcLQParameter(...
                                        radDepths(currIx),...
                                        mTissueClass_j{ShiftScen}(currIx,:),...
                                        machine.data(energyIx));

                                    alphaDoseTmpContainer{mod(counter-1,numOfBixelsContainer)+1,CtScen,ShiftScen,RangeShiftScen} = sparse(V(ix{ShiftScen}(currIx)),1,bixelAlpha.*bixelDose,prod(ct.cubeDim),1);
                                    betaDoseTmpContainer{mod(counter-1,numOfBixelsContainer)+1,CtScen,ShiftScen,RangeShiftScen} = sparse(V(ix{ShiftScen}(currIx)),1,sqrt(bixelBeta).*bixelDose,prod(ct.cubeDim),1);
                                end
                            end
                            
                        end
                    end
                end
                
                % save computation time and memory by sequentially filling the
                % sparse matrix dose.dij from the cell array
                if mod(counter,numOfBixelsContainer) == 0 || counter == dij.totalNumOfBixels
                    for CtScen = 1:multScen.numOfCtScen
                        for ShiftScen = 1:multScen.numOfShiftScen
                            for RangeShiftScen = 1:multScen.numOfRangeShiftScen
                                
                                if multScen.ScenCombMask(CtScen,ShiftScen,RangeShiftScen)
                                    dij.physicalDose{CtScen,ShiftScen,RangeShiftScen}(:,(ceil(counter/numOfBixelsContainer)-1)*numOfBixelsContainer+1:counter) = [doseTmpContainer{1:mod(counter-1,numOfBixelsContainer)+1,CtScen,ShiftScen,RangeShiftScen}];
                                end
                                
                            end
                        end
                    end
                    
                    if strcmp(pln.bioOptimization,'effect') || strcmp(pln.bioOptimization,'RBExD') ... 
                            && strcmp(pln.radiationMode,'carbon')
                        for CtScen = 1:multScen.numOfCtScen
                            for ShiftScen = 1:multScen.numOfShiftScen
                                for RangeShiftScen = 1:multScen.numOfRangeShiftScen
                                    
                                    if multScen.ScenCombMask(CtScen,ShiftScen,RangeShiftScen)
                                        dij.mAlphaDose{CtScen,ShiftScen,RangeShiftScen}(:,(ceil(counter/numOfBixelsContainer)-1)*numOfBixelsContainer+1:counter) = [alphaDoseTmpContainer{1:mod(counter-1,numOfBixelsContainer)+1,CtScen,ShiftScen,RangeShiftScen}];
                                        dij.mSqrtBetaDose{CtScen,ShiftScen,RangeShiftScen}(:,(ceil(counter/numOfBixelsContainer)-1)*numOfBixelsContainer+1:counter) = [betaDoseTmpContainer{1:mod(counter-1,numOfBixelsContainer)+1,CtScen,ShiftScen,RangeShiftScen}];
                                    end
                                    
                                end
                            end
                        end
                    end
                end

            end
            
        end
        
    end
end

try
  % wait 0.1s for closing all waitbars
  allWaitBarFigures = findall(0,'type','figure','tag','TMWWaitbar'); 
  delete(allWaitBarFigures);
  pause(0.1); 
catch
end
