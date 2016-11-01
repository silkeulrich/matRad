function c = matRad_constFunc(d_i,constraint,d_ref,d_ref2,voxelWeighting)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% matRad IPOPT callback: constraint function for inverse planning supporting max dose
% constraint, min dose constraint, max dose constraint, min mean, 
% min max mean constraint, min EUD constraint, max EUDconstraint, 
% min max EUD constraint, max DVH constraint, min DVH constraint 
% 
% call
%   c = matRad_constFunc(d_i,constraint,d_ref)
%
% input
%    d_i:            dose vector in VOI
%    constraint:     matRad constraint struct
%    d_ref:          reference dose /effect value to evaluate constraint
%    d_ref2:         2nd reference dose /effect value to evaluate
%                    constraint (optional)
%    voxelWeigthing: voxel weighting (optional)
%
% output
%   c: value of constraints
%
% Reference
%
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


numOfVoxels = numel(d_i);

if isequal(constraint.type, 'max dose constraint')

    epsilon = 1e-3;
    d_i_max = max(d_i);

    c = d_i_max + epsilon * log( sum(exp((d_i - d_i_max)/epsilon)) );

elseif isequal(constraint.type, 'min dose constraint')

    epsilon = 1e-3;
    d_i_min = min(d_i);

    c = d_i_min - epsilon * log( sum(exp((d_i_min - d_i)/epsilon)) );

elseif isequal(constraint.type, 'min mean dose constraint') || ...
       isequal(constraint.type, 'max mean dose constraint') || ...
       isequal(constraint.type, 'min max mean dose constraint')

    c = mean(d_i);

elseif isequal(constraint.type, 'min EUD constraint') || ...
       isequal(constraint.type, 'max EUD constraint') || ...
       isequal(constraint.type, 'min max EUD constraint')

    exponent = constraint.EUD;

    c = mean(d_i.^exponent)^(1/exponent);

elseif isequal(constraint.type, 'max DVH constraint') || ... 
       isequal(constraint.type, 'min DVH constraint')

    c = sum(d_i >= d_ref)/numOfVoxels ;

    % alternative constraint calculation 3/4 %
    % % get reference Volume
    % refVol = cst{j,6}(k).volume/100;
    % 
    % % calc deviation
    % deviation = d_i - d_ref;
    % 
    % % calc d_ref2: V(d_ref2) = refVol
    % d_ref2 = matRad_calcInversDVH(refVol,d_i);
    % 
    % % apply lower and upper dose limits
    % if isequal(cst{j,6}(k).type, 'max DVH constraint')
    %    deviation(d_i < d_ref | d_i > d_ref2) = 0;
    % elseif isequal(cst{j,6}(k).type, 'min DVH constraint')
    %    deviation(d_i > d_ref | d_i < d_ref2) = 0;
    % end
    % 
    % %c = sum(deviation);                              % linear deviation
    % %c = deviation'*deviation;                        % square devioation
    % c = (1/size(cst{j,4},1))*(deviation'*deviation); % square deviation with normalization
    % %c = (deviation).^2'*(deviation).^2;               % squared square devioation
    % alternative constraint calculation 3/4 %
    
elseif isequal(constraint.type, 'max DCH Area constraint') || ...
       isequal(constraint.type, 'min DCH Area constraint')
   
    % calc deviation
    deviation = d_i - d_ref;

    % apply lower and upper dose limits
    if isequal(constraint.type, 'max DCH Area constraint')
         deviation(d_i < d_ref | d_i > d_ref2) = 0;
    elseif isequal(constraint.type, 'min DCH Area constraint')
         deviation(d_i > d_ref | d_i < d_ref2) = 0;
    end

    % apply weighting
    deviation = deviation.*voxelWeighting;  

    % calculate constraint function
    %c = (1/numOfVoxels)*(deviation'*deviation);   
    c = (1/1)*(deviation'*deviation);   
    
elseif isequal(constraint.type, 'max DCH Theta constraint') || ...
       isequal(constraint.type, 'min DCH Theta constraint')

    c = sum(d_i >= d_ref)/numOfVoxels;           
    
end 


end