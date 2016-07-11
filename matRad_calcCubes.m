function resultGUI = matRad_calcCubes(w,dij,cst,type,scenNum)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% matRad computation of all cubes for the resultGUI struct which is used
% as result container and for visualization in matRad's GUI
%
% call
%   resultGUI = matRad_calcCubes(w,dij,cst)
%
% input
%   w:       bixel weight vector
%   dij:     dose influence matrix
%   cst:     matRad cst struct
%   scenNum: optional: number of scenario to calculated (default 1)
%
% output
%   resultGUI: matRad result struct
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

if nargin < 4
    scenNum = 1;
end

% consider VOI priorities
cst  = matRad_setOverlapPriorities(cst);

resultGUI.w = w;

% calc dose and reshape from 1D vector to 2D array
resultGUI.physicalDose = reshape(dij.physicalDose{scenNum}*resultGUI.w,dij.dimensions);
   

%write worst case dose distribution
writeWCCube = 0;
i=1;
while(writeWCCube == 0 &&  i <= size(cst,1))
       if(strcmp(cst{i,6}(:).robustness,'WC'))
            writeWCCube = 1;
       end
    i = i+1;
end
    
if(writeWCCube == 1)
     d = matRad_backProjection(w,dij,type);
  
     [d_max,~] = max([d{:}],[],2);  
     [d_min,~] = min([d{:}],[],2);
             
    %resultGUI.maxDose = reshape(d_max,dij.dimensions);
    %resultGUI.minDose = reshape(d_min,dij.dimensions);
    
    d_wc = d_max;
    for  i = 1:size(cst,1)
        for j = 1:numel(cst{i,6})
  
            if isequal(cst{i,3},'TARGET')
                d_wc(cst{i,4}{1}) = d_min(cst{i,4}{1});
            end
        end
    end
    resultGUI.wcDose = reshape(d_wc,dij.dimensions);
end


if isfield(dij,'mAlphaDose') && isfield(dij,'mSqrtBetaDose')

    a_x = zeros(size(resultGUI.physicalDose));
    b_x = zeros(size(resultGUI.physicalDose));

    for i = 1:size(cst,1)
        % Only take OAR or target VOI.
        if isequal(cst{i,3},'OAR') || isequal(cst{i,3},'TARGET') 
            a_x(cst{i,4}{scenNum}) = cst{i,5}.alphaX;
            b_x(cst{i,4}{scenNum}) = cst{i,5}.betaX;
        end
    end
    
    resultGUI.effect = (dij.mAlphaDose{scenNum}*resultGUI.w+(dij.mSqrtBetaDose{scenNum}*resultGUI.w).^2);
    resultGUI.effect = reshape(resultGUI.effect,dij.dimensions);
    
    resultGUI.RBExDose     = zeros(size(resultGUI.effect));
    ix                     = resultGUI.effect>0;
    resultGUI.RBExDose(ix) = ((sqrt(a_x(ix).^2 + 4 .* b_x(ix) .* resultGUI.effect(ix)) - a_x(ix))./(2.*b_x(ix)));
    resultGUI.RBE          = resultGUI.RBExDose./resultGUI.physicalDose;
   
    AlphaDoseCube    = dij.mAlphaDose{scenNum} * resultGUI.w;
    resultGUI.alpha  = (reshape(AlphaDoseCube,dij.dimensions))./resultGUI.physicalDose;
    SqrtBetaDoseCube = dij.mSqrtBetaDose{scenNum} * resultGUI.w;
    resultGUI.beta   = ((reshape(SqrtBetaDoseCube,dij.dimensions))./resultGUI.physicalDose).^2;
    
end