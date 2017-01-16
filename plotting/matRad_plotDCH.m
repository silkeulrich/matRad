function h = plot_DCH(voiName,voiVolume,cst,doseVec,dij,LineStyle,pln,refFlag,varargin)

% adjust objectives and constraints internally for fractionation 
for i = 1:size(cst,1)
    for j = 1:size(cst{i,6},1)
       cst{i,6}(j).dose = cst{i,6}(j).dose/pln.numOfFractions;
    end
end

LineWidth       = 2;
LineWidthMarker = 3;

if isempty(varargin)
    color     = distinguishable_colors(length(voiName),'w');
    colorScat = color;
else
    if length(varargin) == 1
        color     = varargin{1};
        colorScat = color;
    elseif length(varargin) == 2
        color     = varargin{1};
        colorScat = repmat(varargin{2},size(color,1),1);
    end
end

plotCounter = 0;

% plot DCH
for i = 1:length(voiName)
    
    % plot DCH
    [dchPoints,Q]  = matRad_calcDCH(voiVolume(i),doseVec,dij,cst(strcmp([cst(:,2)],voiName{i}),:));
    plotCounter    = plotCounter + 1;
    h(plotCounter) = plot(dchPoints,Q,LineStyle,'Color',color(i,:),'LineWidth',LineWidth);
    hold on
    
    % plot references if available
    cstidxVOI = find(strcmp([cst(:,2)],voiName{i}));
    if refFlag
        if ~isempty(cstidxVOI)
            if ~isempty(cst{cstidxVOI,6})
                logidxDCHobj = ~cellfun('isempty',strfind({cst{cstidxVOI,6}(:).type},'DCH'));
                volume       = [cst{cstidxVOI,6}(logidxDCHobj).volume]./100;
                coverage     = [cst{cstidxVOI,6}(logidxDCHobj).coverage]./100;
                dose         = [cst{cstidxVOI,6}(logidxDCHobj).dose];
                for j = 1:length(coverage)
                    if isequal(voiVolume(i),volume(j))
                        plotCounter    = plotCounter + 1;
                        h(plotCounter) = scatter(dose(j),coverage(j)*100,100,'o','MarkerEdgeColor',colorScat(i,:),'LineWidth',LineWidthMarker);
                        %h(plotCounter) = plot(dose(j),coverage(j)*100,'o','MarkerEdgeColor',colorScat(i,:),'LineWidth',LineWidthMarker);
                        hold on
                        
                    end
                end
            end
        end
    end    
    
end

% set plot options
xlabel('dose [Gy]')
ylabel('coverage probability [%]')
%set(gca,'ygrid','on')
grid on
ylim([0 110])
axis square

end