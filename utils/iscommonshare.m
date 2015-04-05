function tf = iscommonshare(tb)
% ISCOMMONSHARE Checks which UnID - Date pairs are common shares (share type code 10 and 11) 
%
%   ISCOMMONSHARE(TB) TB is a table with UnID and yyyymmdd Date 
if isa(tb,'dataset')
    tb = dataset2table(tb);
end

shrcd = loadresults('shrcd');
shrcd = shrcd(shrcd.Shrcd == 11 | shrcd.Shrcd == 10,{'UnID','Date'});
tf    = ismembIdDate(tb.UnID, tb.Date, shrcd.UnID, shrcd.Date);

end