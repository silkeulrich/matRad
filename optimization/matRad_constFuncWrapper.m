function c = matRad_constFuncWrapper(w,dij,cst,type)

% get current dose / effect / RBExDose vector
d = matRad_backProjection(w,dij,type);

% Initializes constraints
c = [];

% compute objective function for every VOI.
for  i = 1:size(cst,1)

    % Only take OAR or target VOI.
    if ~isempty(cst{i,4}{1}) && ( isequal(cst{i,3},'OAR') || isequal(cst{i,3},'TARGET') )

        % loop over the number of constraints for the current VOI
        for j = 1:numel(cst{i,6})
            
            % only perform computations for constraints
            if ~isempty(strfind(cst{i,6}(j).type,'constraint'))
                
                % compute reference
                if (~isequal(cst{i,6}(j).type, 'max dose constraint') && ~isequal(cst{i,6}(j).type, 'min dose constraint') &&...
                    ~isequal(cst{i,6}(j).type, 'min mean dose constraint') && ~isequal(cst{i,6}(j).type, 'max mean dose constraint') &&...
                    ~isequal(cst{i,6}(j).type, 'min max mean dose constraint') && ~isequal(cst{i,6}(j).type, 'min EUD constraint') &&...
                    ~isequal(cst{i,6}(j).type, 'max EUD constraint') && ~isequal(cst{i,6}(j).type, 'min max EUD constraint')) &&...
                    isequal(type,'effect')
                     
                    d_ref = dij.ax(cst{i,4}{1}).*cst{i,6}(j).dose + dij.bx(cst{i,4}{1})*cst{i,6}(j).dose^2;
                else
                    d_ref = cst{i,6}(j).dose;
                end

                % if conventional opt: just add constraints of nominal dose
                if strcmp(cst{i,6}(j).robustness,'none')

                    d_i = d{1}(cst{i,4}{1});

                    c = [c; matRad_constFunc(d_i,cst{i,6}(j),d_ref)];

                % if prob opt or voxel-wise worst case: add constraints of all dose scenarios
                elseif strcmp(cst{i,6}(j).robustness,'probabilistic') || strcmp(cst{i,6}(j).robustness,'voxel-wise worst case')
                    
                    for k = 1:dij.numOfScenarios
                        
                        d_i = d{k}(cst{i,4}{1});
                        
                        c = [c; matRad_constFunc(d_i,cst{i,6}(j),d_ref)];
                        
                    end
                    
                % if coveraged based opt   
                elseif strcmp(cst{i,6}(j).robustness,'coverage')
                    
                    % get cst index of VOI that corresponds to VOI ring
                    cstidx = find(strcmp(cst(:,2),cst{i,2}(1:end-4)));
                    
                    if isequal(cst{i,6}(j).type, 'max DCH constraint') || ...
                       isequal(cst{i,6}(j).type, 'min DCH constraint')
                    
                        for k = 1:dij.numOfScenarios

                            % get current dose
                            d_i = d{k}(cst{cstidx,4}{1});

                            % inverse DVH calculation
                            d_pi(k) = matRad_calcInversDVH(cst{i,6}(j).volume/100,d_i);

                        end

                        c = [c; matRad_constFunc(d_i,cst{i,6}(j),d_ref,d_pi)];
                    
                    elseif isequal(cst{i,6}(j).type, 'max DCH constraint2') || ...
                           isequal(cst{i,6}(j).type, 'min DCH constraint2')
                        
                        d_i = [];
                       
                        % get dose of VOI that corresponds to VOI ring
                        for k = 1:dij.numOfScenarios
                            d_i{k} = d{k}(cst{cstidx,4}{1});
                        end

                        % calc invers DCH of VOI
                        refQ   = cst{i,6}(j).coverage/100;
                        refVol = cst{i,6}(j).volume/100;
                        d_ref2 = matRad_calcInversDCH(refVol,refQ,d_i,dij.numOfScenarios);

                        % get dose of VOI ring
                        d_i = d{1}(cst{i,4}{1});

                        % calc voxel dependent weighting
                        %matRad_calcVoxelWeighting(i,j,cst,d_i,d_ref,d_ref2)

                        c = [c; matRad_constFunc(d_i,cst{i,6}(j),d_ref,1,d_ref2)];
                   
                    end

                end % if we are in the nominal sceario or rob opt
            
            end

        end % over all defined constraints & objectives

    end % if structure not empty and oar or target

end % over all structures