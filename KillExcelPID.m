function KillExcelPID

% 每使用一次xlsread xlswrite函数，matlab都会在后台打开一个excel的进程
% 多次使用xlsread xlswrite后需要把后台的excel进程kill掉，否则可能会导致matlab调用xlsread xlswrite出错！
[~, computer] = system('hostname');
[~, user] = system('whoami');
[~, alltask] = system(['tasklist /S ', computer, ' /U ', user]);
excelPID = regexp(alltask, 'EXCEL.EXE\s*(\d+)\s', 'tokens');
for i = 1 : length(excelPID)
      killPID = cell2mat(excelPID{i});      system(['taskkill /f /pid ', killPID]);
end