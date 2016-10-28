function ea_load_pts(handles,uipatdir,patsub)

if ~exist('patsub','var')
    patsub='patients';
end

if length(uipatdir)>1
    set(handles.patdir_choosebox,'String',['Multiple (',num2str(length(uipatdir)),')']);
    set(handles.patdir_choosebox,'TooltipString',ea_strjoin(uipatdir,', '));
else
    set(handles.patdir_choosebox,'String',uipatdir{1});
    set(handles.patdir_choosebox,'TooltipString',uipatdir{1});
end

% store patient directories in figure


setappdata(handles.leadfigure,'uipatdir',uipatdir);
try
ea_switchctmr(handles);
end

ea_getui(handles); % update ui from patient
ea_storeui(handles); % save in pt folder
ea_addrecentpatient(handles,uipatdir,['Recent ',patsub,':'],patsub);



% add VATs to seeds for connectome mapper case
if isfield(handles,'seeddefpopup')
    
    for pt=1:length(uipatdir)
    direc=[uipatdir{pt},filesep];
    stims=ea_dir2cell(dir([direc,'stimulations']));
    if ~exist('remstims','var')
        remstims=stims;
    else
        todel=[];
        for d=1:length(remstims)
            if ~ismember(remstims{d},stims)
               todel(end+1)=d; 
            end
        end
        remstims(todel)=[];
    end
    end
    remstims=ea_prependvat(remstims);
    set(handles.seeddefpopup,'String',[{'Manually choose seeds'},remstims]);
    
end

function remstims=ea_prependvat(remstims)
for rs=1:length(remstims)
    remstims{rs}=['Use VATs: ',remstims{rs}];
end