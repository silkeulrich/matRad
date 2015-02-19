function matRad_calcDVH(d,cst,lineStyleIndicator)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% matRad_calcDVH(d,cst,lineStyleIndicator)
% to calculate a dvh. use lineStyleIndicator to overlay multiple dvhs
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Copyright 2015, Mark Bangert, on behalf of the matRad development team
%
% m.bangert@dkfz.de
%
% This file is part of matRad.
%
% matrad is free software: you can redistribute it and/or modify it under 
% the terms of the GNU General Public License as published by the Free 
% Software Foundation, either version 3 of the License, or (at your option)
% any later version.
%
% matRad is distributed in the hope that it will be useful, but WITHOUT ANY
% WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License in the
% file license.txt along with matRad. If not, see
% <http://www.gnu.org/licenses/>.
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% create new figure and set default line style indicator if not explictly
% specified
if nargin < 3
    figure
    hold on
    lineStyleIndicator = 1;
else
    hold on
end

numOfVois = size(cst,1);

%% calculate and print the dvh
colorMx    = jet;
colorMx    = colorMx(1:floor(64/numOfVois):64,:);

lineStyles = {'-',':','--','-.'};

n         = 100;
dvhPoints = linspace(0,100,n);
dvh       = NaN * ones(1,n);

for i = 1:numOfVois

    indices     = cst{i,8};
    numOfVoxels = numel(indices);
    doseInVoi   = d(indices);

    fprintf('%3d %20s - Mean dose = %5.2f Gy +/- %5.2f Gy (Max dose = %5.2f Gy, Min dose = %5.2f Gy)\n', ...
        cst{i,1},cst{i,2},mean(doseInVoi),std(doseInVoi),max(doseInVoi),min(doseInVoi))

    for j = 1:n
        dvh(j) = sum(doseInVoi > dvhPoints(j));
    end
    
    dvh = dvh ./ numOfVoxels * 100;

    plot(dvhPoints,dvh,'LineWidth',4,'Color',colorMx(i,:), ...
        'LineStyle',lineStyles{lineStyleIndicator},'DisplayName',cst{i,2});

end

% legend
legendHandle = legend('show');
%set(legendHandle,'Position',[.65 .4 .147 .282],'LineWidth',2,'EdgeColor',0*[1 1 1]); % intra2

fontSizeValue = 14;

axis([0 100 0 110])
plot([0 100],[0 0],'k','LineWidth',2)
set(gca,'YTick',0:20:120)
set(gca,'XTick',0:10:120)
set(gca,'XTickLabel',{0,[],20,[],40,[],60,[],80,[],100})
grid on
box(gca,'on');
set(gca,'LineWidth',1.5,'FontSize',fontSizeValue);
set(gcf,'Color','w');
ylabel('Volume [%]','FontSize',fontSizeValue)
xlabel('Dose [Gy]','FontSize',fontSizeValue)

return;

%% calculate conformity index
% find target volumes and sort them according to their prescribed dose
targetVol = [];
targetDose = [];
for i = 1:size(cst,1)
    if strcmp(cst{i,3},'TARGET')
        targetVol  = [targetVol i];
        targetDose = [targetDose cst{i,4}];
    end
end
[targetDose,ranking] = sort(targetDose);
targetVol            = targetVol(ranking);

for i = 1:numel(targetVol)
    
    targetVolIndices        = voi(:) == cst{targetVol(i),1};
    for j = i+1:numel(targetVol)
        targetVolIndices    = targetVolIndices | voi(:) == cst{targetVol(j),1};
    end
    
    treatedVolIndices       = d(:) >= .95*targetDose(i);
    treatedTargetVolIndices = targetVolIndices & treatedVolIndices;
    
    % van't Riet conformity number according to http://www.sciencedirect.com/science/article/pii/S0360301605027197
    CN = sum(treatedTargetVolIndices)^2/sum(targetVolIndices)/sum(treatedVolIndices);

    fprintf('%3d %20s - van''t Riet''s CN = %5.2f\n',cst{targetVol(i),1},cst{targetVol(i),2},CN);

end
