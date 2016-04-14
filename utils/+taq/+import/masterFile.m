function masterFile(fname, outdir, opt)

% Default case with CSVs
if nargin < 3
    opt.UseTextscan = false;
    opt.ImportFmt   = ['%s %s %s ',repmat('%u8 ',1,9),'%s %f %f %s %u8 %f %*[^\n]'];
    opt.ImportOther = {'Delimiter',',','CommentStyle',{'"','"'}};
end

tb = importTable(fname,opt);
if isempty(tb.DENOM)
    tb.DENOM = repmat(' ', size(tb,1),1);
end

recordsAdd(tb,outdir);
end

% Import master file into a table
function tb = importTable(fname,opt)

% Fixed-length .TAB files
if opt.UseTextscan
    fid   = fopen(fname);
    clean = onCleanup(@() fclose(fid));
    tmp   = textscan(fid, opt.ImportFmt,opt.ImportOther{:});

    % Conversions
    tmp{1}       = cellstr(tmp{1});
    tmp(4:12)    = cellfun(@(x) logical(x-'0'),tmp(4:12),'un',0);
    tmp{14}      = str2num(tmp{14});
    tmp([15,18]) = cellfun(@(x) uint32(str2num(x)),tmp([15,18]),'un',0);
    tmp{17}      = uint8(tmp{17}-'0');

    tb = table(tmp{:},'VariableNames', opt.VarNames);

% CSVs    
else
    tb = readtable(fname, 'Format',opt.ImportFmt, opt.ImportOther{:});

    % Eventually rename DATEF to FDATE (in some files it changes)
    tb.Properties.VariableNames = regexprep(tb.Properties.VariableNames,'(?i)datef','FDATE');

    % Conversions
    tb = convertColumn(tb, 'logical', {'ETN','ETA','ETB','ETP','ETX','ETT','ETO','ETW','ITS'});
    tb = convertColumn(tb, 'int8', 'TYPE');
    tb = convertColumn(tb, 'uint32', {'FDATE','UOT'});
    tb = convertColumn(tb, 'char', {'NAME','CUSIP','ICODE','DENOM'});
end
end

% Add master records to symbol-specific master files
function tb = recordsAdd(tb, outdir)

% Group records by symbol
[symb,~,subs] = unique(tb.SYMBOL);
tb            = cache2cell(tb,subs);

for ii = 1:numel(symb)
    fname = fullfile(outdir,sprintf('s_%s',symb{ii}));
    try

        % Add new records with new dates
        s    = load(fname,'-mat');
        iold = ismember(tb{ii}.FDATE, s.mst.FDATE);
        if all(iold)
            continue
        end
        mst = [s.mst; tb{ii}(~iold,:)];

        % Sort by CUSIP/DEN and FDATE
        [~,~,mst.Id] = unique(mst(:,{'CUSIP','DENOM'}));
        [~,isort]    = sort(uint56(Id*1e8) + uint64(mst.FDATE));
        mst          = mst(isort,:);

        % Keep unique records with earliest date
        idx    = isfeatchange(mst(:,[end,2,4:end-1]),[1,3:11,13,14,16,17]);
        mst    = mst(idx,:);
        mst.Id = [];
    catch
        mst = tb{ii};
    end
    save(fname,'mst','-mat','-v6')
end
end
