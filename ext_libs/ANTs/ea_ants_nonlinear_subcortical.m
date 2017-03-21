function ea_ants_nonlinear_subcortical(varargin)
% Wrapper for ANTs nonlinear registration

fixedimage=varargin{1};
movingimage=varargin{2};
outputimage=varargin{3};


[outputdir, outputname, ~] = fileparts(outputimage);
if outputdir
    outputbase = [outputdir, filesep, outputname];
else
    outputbase = ['.', filesep, outputname];
end

if ischar(fixedimage)
    fixedimage={fixedimage};
elseif ~iscell(fixedimage)
	ea_error('Please supply variable fixedimage as either char or cellstring');
end



if nargin>3
    weights=varargin{4};
    metrics=varargin{5};
%     options=varargin{6};
else
    weights=ones(length(fixedimage),1);
    metrics=repmat({'MI'},length(fixedimage),1);
end

if ischar(movingimage)
    movingimage={movingimage};
elseif ~iscell(movingimage)
    ea_error('Please supply variable fixedimage as either char or cellstring');
end

directory=fileparts(movingimage{1});
directory=[directory,filesep];



for fi=1:length(fixedimage)
    fixedimage{fi} = ea_path_helper(ea_niigz(fixedimage{fi}));
end
for fi=1:length(movingimage)
    movingimage{fi} = ea_path_helper(ea_niigz(movingimage{fi}));
end

if length(fixedimage)~=length(movingimage)
    ea_error('Please supply pairs of moving and fixed images (can be repetitive).');
end

outputimage = ea_path_helper(ea_niigz(outputimage));

basedir = [fileparts(mfilename('fullpath')), filesep];

if ispc
    HEADER = [basedir, 'PrintHeader.exe'];
    ANTS = [basedir, 'antsRegistration.exe'];
        applyTransforms = [basedir, 'antsApplyTransforms.exe'];

else
    HEADER = [basedir, 'PrintHeader.', computer('arch')];
    ANTS = [basedir, 'antsRegistration.', computer('arch')];
        applyTransforms = [basedir, 'antsApplyTransforms.', computer('arch')];

end



if ~ispc
    [~, imgsize] = system(['bash -c "', HEADER, ' ',fixedimage{1}, ' 2"']);
else
    [~, imgsize] = system([HEADER, ' ', fixedimage{1}, ' 2']);
end

imgsize = cellfun(@(x) str2double(x),ea_strsplit(imgsize,'x'));


if any(imgsize>256)
    rigidconvergence='[1000x500x250x0,1e-6,10]';
    rigidshrinkfactors='12x8x4x2';
    rigidsmoothingssigmas='4x3x2x1vox';

    affineconvergence='[1000x500x250x0,1e-6,10]';
    affineshrinkfactors='8x4x2x1';
    affinesmoothingssigmas='4x3x2x1vox';
else
    rigidconvergence='[1000x500x250x0,1e-6,10]';
    rigidshrinkfactors='8x4x2x1';
    rigidsmoothingssigmas='3x2x1x0vox';

    affineconvergence='[1000x500x250x0,1e-6,10]';
    affineshrinkfactors='8x4x2x1';
    affinesmoothingssigmas='3x2x1x0vox';
end

synconvergence='[25x12x0,1e-6,10]';
synshrinkfactors='8x4x2';
synsmoothingssigmas='2x1x0vox';



rigidstage = [' --initial-moving-transform [', fixedimage{1}, ',', movingimage{1}, ',1]' ...
              ' --transform Rigid[0.1]' ...
              ' --convergence ', rigidconvergence, ...
              ' --shrink-factors ', rigidshrinkfactors, ...
              ' --smoothing-sigmas ', rigidsmoothingssigmas, ...
              ' --masks [NULL,NULL]'];

for fi=1:length(fixedimage)
    switch metrics{fi}
        case 'MI'
            suffx=',32,Regular,0.25';
        case 'CC'
            suffx=',4,Regular,0.25';
        case 'GC'
            suffx=',15,Random,0.05';
    end
    
    try
        rigidstage=[rigidstage,...
        ' --metric ','MI','[', fixedimage{fi}, ',', movingimage{fi}, ',',num2str(weights(fi)),suffx,']'];
    catch
        keyboard
    end    
end

affinestage = [' --transform Affine[0.1]'...
               ' --convergence ', affineconvergence, ...
               ' --shrink-factors ', affineshrinkfactors ...
               ' --smoothing-sigmas ', affinesmoothingssigmas, ...
               ' --masks [NULL,NULL]'];

for fi=1:length(fixedimage)
	switch metrics{fi}
        case 'MI'
            suffx=',32,Regular,0.25';
        case 'CC'
            suffx=',4,Regular,0.25';
        case 'GC'
            suffx=',15,Random,0.05';
	end
    affinestage=[affinestage,...
            ' --metric ','MI','[', fixedimage{fi}, ',', movingimage{fi}, ',',num2str(weights(fi)),suffx,']'];
end

synstage = [' --transform SyN[0.3]'...
    ' --convergence ', synconvergence, ...
    ' --shrink-factors ', synshrinkfactors ...
    ' --smoothing-sigmas ', synsmoothingssigmas, ...
    ' --masks [NULL,NULL]'];

        
for fi=1:length(fixedimage)
    switch metrics{fi}
        case 'MI'
            suffx=',32,Regular,0.25';
        case 'CC'
            suffx=',4,Regular,0.25';
        case 'GC'
            suffx=',15,Random,0.05';
    end
    synstage=[synstage,...
        ' --metric ',metrics{fi},'[', fixedimage{fi}, ',', movingimage{fi}, ',',num2str(weights(fi)),suffx,']'];
    

end


ea_libs_helper

cmd1 = [ANTS, ' --verbose 1', ...
    ' --dimensionality 3', ...
    ' --output [',ea_path_helper(outputbase),'1', ',', outputimage, ']', ...
    ' --interpolation Linear', ...
    ' --winsorize-image-intensities [0.005,0.995]', ...
    ' --use-histogram-matching 1', ...
    ' --float 1',...
    ' --write-composite-transform 1', ...
    rigidstage, affinestage, synstage];

% add masks:



synmaskconvergence='[6x0,1e-6,10]';
synmaskshrinkfactors='2x1';
synmasksmoothingssigmas='1x0vox';

masks={'secondstepmask','thirdstepmask','fourthstepmask'};
for st=1:length(masks)
    synmaskstage{st} = [' --initial-moving-transform ',outputbase,num2str(st),'Composite.h5' ...
        ' --transform SyN[0.3]', ...
        ' --convergence ', synmaskconvergence, ...
        ' --shrink-factors ', synmaskshrinkfactors,  ...
        ' --smoothing-sigmas ', synmasksmoothingssigmas, ...
        ' --masks [',ea_space([],'subcortical'),masks{st},'.nii',',NULL]'];
    for fi=1:length(fixedimage)
                suffx=',4,Regular,0.15';
           
        synmaskstage{st}=[synmaskstage{st},...
            ' --metric ','CC','[', fixedimage{fi}, ',', movingimage{fi}, ',',num2str(weights(fi)),suffx,']'];
    end
    
    maskcmd{st} = [ANTS, ' --verbose 1' ...
        ' --dimensionality 3' ...
        ' --output [',ea_path_helper(outputbase),num2str(st+1), ',', outputimage, ']' ...
        ' --interpolation Linear' ...
        ' --use-histogram-matching 1' ...
        ' --winsorize-image-intensities [0.005,0.995]', ...
        ' --float 1',...
        ' --write-composite-transform 1', ... % this will already write out a final combined transform so no need to concatenate them.
        synmaskstage{st}];
end

if ~ispc
    system(['bash -c "', cmd1, '"']);
    for st=1:length(masks)
        %keyboard
        system(['bash -c "', maskcmd{st}, '"']);
    end
else
    system(cmd1);
    for st=1:length(masks)
        
        system(maskcmd{st});
        
    end
end

% final warp:
movefile([ea_path_helper(outputbase),num2str(st+1),'.h5'],[ea_path_helper(outputbase),'.h5']);

ea_conv_antswarps(directory);
